// MonaDialogService.swift
//
// P07-T004 — Project four dialog sites into host-authorized native dialogs.
//
// `MonaDialogService` projects the four RETAINED monaco-editor@0.56.0 dialog
// call sites (the S1-R closure — services-s1r-session-feedback-closure.html)
// onto host-authorized native macOS sheet/alert requests. The four retained
// sites (the cut sites — e.g. saveConflict — are NOT mapped):
//
//   1. unusualLine    — Remove / Ignore      (2-button confirm sheet)
//   2. workspaceUndo   — Undo in N Files / Dismiss (2-button confirm sheet)
//   3. undoConfirm    — Yes / No             (2-button confirm sheet)
//   4. commandError   — OK                   (1-button message sheet)
//
// Each maps to a native `NSAlert` presented as a sheet on the attached,
// authorized host window (the `NSWindow` sourced from P04-T014's
// `MonaCodeEditorView` — the editor view is the host window source).
//
// Load-bearing contract invariants:
//
//   - Exactly four retained dialog call sites are mapped to native sheet or
//     alert requests (the cut sites are absent).
//   - A dialog requires an attached, authorized host window. The host is
//     attached explicitly via `attachAuthorizedHost(_:)` and detached via
//     `detachHost()`.
//   - The three outcomes `.accepted`, `.canceled`, `.unavailable` are typed
//     and exposed.
//   - When presentation is unavailable (no attached authorized host window),
//     `present(site:)` returns `.unavailable` — NEVER `.accepted`. The
//     host-authorization gate precedes presentation, so a presenter that would
//     fabricate acceptance is bypassed entirely; acceptance is never faked.
//
// `actorIsolation` is `none` (per the G6-R interface contract): the service is
// not actor-isolated. AppKit requires UI work on the main thread; the caller
// honors the AppKit threading contract. `@unchecked Sendable` mirrors the
// contract's `sendable: true` while the mutable host state is caller-guarded.

import AppKit
import Foundation
import MonaCode

// MARK: - MonaDialogSite

/// The four RETAINED monaco-editor@0.56.0 dialog call sites (the S1-R closure).
/// Each projects onto a native `NSAlert` sheet presented on the attached,
/// authorized host window. The cut sites (e.g. `saveConflict` — a save
/// affordance fixed-standalone MonaCode does not present) are NOT mapped and
/// therefore have no case here.
public enum MonaDialogSite: String, Sendable, CaseIterable {

    /// The unusual-line-terminators confirm — **Remove / Ignore**
    /// (A2-R retained double branch: removing or ignoring unusual line
    /// separators; resolution revalidates editor/model/version/generation).
    case unusualLine

    /// The workspace-undo confirm — **Undo in N Files / Dismiss**
    /// (source fact: confirm and cancel both ultimately enter All in
    /// fixed-standalone; "This File" is unreachable, so only the two-button
    /// sheet is retained).
    case workspaceUndo

    /// The undo re-entry confirm — **Yes / No**
    /// (Yes re-enters undo; No leaves the model unchanged — the editor/source
    /// recheck is retained).
    case undoConfirm

    /// The command-error message — **OK**
    /// (localized command label + error detail; dismiss has no side effect).
    case commandError

    /// The native alert button label for the *accept* (primary) action.
    public var acceptLabel: String {
        switch self {
        case .unusualLine:    return "Remove"
        case .workspaceUndo:  return "Undo in N Files"
        case .undoConfirm:    return "Yes"
        case .commandError:   return "OK"
        }
    }

    /// The native alert button label for the *cancel* (secondary) action.
    /// `commandError` is a 1-button message sheet — it has no cancel label.
    public var cancelLabel: String {
        switch self {
        case .unusualLine:    return "Ignore"
        case .workspaceUndo:  return "Dismiss"
        case .undoConfirm:    return "No"
        case .commandError:   return ""  // message sheet — no cancel button
        }
    }

    /// The native alert title text for this site.
    public var title: String {
        switch self {
        case .unusualLine:    return "Unusual Line Terminators"
        case .workspaceUndo:  return "Undo in Multiple Files"
        case .undoConfirm:    return "Undo"
        case .commandError:   return "Command Error"
        }
    }

    /// The native alert informative-detail text for this site.
    public var detail: String {
        switch self {
        case .unusualLine:
            return "The file contains unusual line separators. Remove them or keep editing?"
        case .workspaceUndo:
            return "Undo will apply across multiple files. Continue or dismiss?"
        case .undoConfirm:
            return "Continue with undo?"
        case .commandError:
            return "The command could not complete. Dismiss has no side effect."
        }
    }
}

// MARK: - MonaDialogKind

/// The native dialog kind a retained site projects onto. Every retained site
/// projects onto an `NSAlert` presented as a sheet on the host window; the kind
/// only distinguishes the button configuration.
public enum MonaDialogKind: Sendable {

    /// A 2-button confirm `NSAlert` sheet (accept / cancel). Used by
    /// `unusualLine`, `workspaceUndo`, and `undoConfirm`.
    case confirmSheet

    /// A 1-button message `NSAlert` sheet (OK — dismiss has no side effect).
    /// Used by `commandError`.
    case messageSheet
}

// MARK: - MonaDialogOutcome

/// The three typed outcomes a native dialog presentation can produce.
public enum MonaDialogOutcome: String, Sendable {

    /// The user confirmed the primary (accept) action.
    case accepted

    /// The user canceled the dialog (secondary action or dismissed).
    case canceled

    /// Presentation was unavailable — there is no attached, authorized host
    /// window, so the native sheet could not be presented. This is NEVER a
    /// fabricated acceptance: an unavailable dialog is unavailable, not
    /// accepted.
    case unavailable
}

// MARK: - MonaDialogService

/// Projects the four retained monaco-editor@0.56.0 dialog call sites onto
/// host-authorized native macOS sheet/alert requests.
///
/// Attach an authorized host window (the `NSWindow` from P04-T014's
/// `MonaCodeEditorView`) via `attachAuthorizedHost(_:)`; present a site via
/// `present(site:)`. When no authorized host is attached, `present` returns
/// `.unavailable` — it never fabricates `.accepted`.
public final class MonaDialogService: @unchecked Sendable {

    /// The presentation hook. Defaulted to the real native `NSAlert` sheet
    /// presentation on the host window. Tests inject a deterministic stub so
    /// outcomes are verifiable without driving a real modal loop. The hook is
    /// only consulted AFTER the host-authorization gate has passed — an
    /// unavailable presentation never reaches it.
    private let presenter: (MonaDialogSite, MonaDialogKind, NSWindow) -> MonaDialogOutcome

    /// The attached authorized host window (sourced from
    /// `MonaCodeEditorView.window`). `nil` when no host is attached.
    private var hostWindow: NSWindow?

    /// Whether the attached host is explicitly authorized to present dialogs.
    /// Authorization is granted only by `attachAuthorizedHost(_:)` and revoked
    /// by `detachHost()`.
    private var hostAuthorized: Bool = false

    /// Creates the service.
    ///
    /// - Parameter presenter: The presentation hook to use. Defaults to the
    ///   real native `NSAlert` sheet presentation (`nativePresent`). Tests
    ///   inject a deterministic stub.
    public init(
        presenter: ((MonaDialogSite, MonaDialogKind, NSWindow) -> MonaDialogOutcome)? = nil
    ) {
        self.presenter = presenter ?? MonaDialogService.nativePresent
    }

    // MARK: - Host window (authorization gate)

    /// Attaches the authorized host window. The window is sourced from
    /// P04-T014's `MonaCodeEditorView` (the editor view is the host window
    /// source): `service.attachAuthorizedHost(editorView.window)`. Until a host
    /// is attached, `present(site:)` returns `.unavailable`.
    public func attachAuthorizedHost(_ window: NSWindow) {
        hostWindow = window
        hostAuthorized = true
    }

    /// Detaches the host window and revokes authorization. After this,
    /// `present(site:)` returns `.unavailable` — acceptance is never fabricated.
    public func detachHost() {
        hostWindow = nil
        hostAuthorized = false
    }

    /// `true` while an authorized host window is attached.
    public var isHostAttached: Bool {
        return hostWindow != nil && hostAuthorized
    }

    // MARK: - Site → native kind

    /// The native dialog kind a retained site projects onto. All four retained
    /// sites project onto `NSAlert` sheets; the three confirms are
    /// `.confirmSheet` (2-button) and `commandError` is `.messageSheet`
    /// (1-button).
    public static func kind(for site: MonaDialogSite) -> MonaDialogKind {
        switch site {
        case .unusualLine, .workspaceUndo, .undoConfirm:
            return .confirmSheet
        case .commandError:
            return .messageSheet
        }
    }

    // MARK: - Retained sites

    /// The exactly four retained dialog call sites (the complete reachable
    /// dialog surface). The cut sites are NOT mapped. Order matches the S1-R
    /// closure enumeration.
    public static let retainedSites: [MonaDialogSite] = MonaDialogSite.allCases

    // MARK: - Present

    /// Presents the native sheet/alert for `site` on the attached, authorized
    /// host window.
    ///
    /// - Returns: `.accepted` if the user confirmed the primary action;
    ///   `.canceled` if the user canceled; `.unavailable` if no authorized host
    ///   window is attached (in which case acceptance is NEVER fabricated — the
    ///   host-authorization gate precedes presentation and the presenter is not
    ///   consulted).
    public func present(site: MonaDialogSite) -> MonaDialogOutcome {
        // Host-authorization gate. This gate PRECEDES presentation: with no
        // authorized host window, the result is `.unavailable` — never
        // `.accepted`. A presenter that would fabricate acceptance is never
        // reached when the host is unavailable.
        guard let window = hostWindow, hostAuthorized else {
            return .unavailable
        }
        let kind = MonaDialogService.kind(for: site)
        return presenter(site, kind, window)
    }

    // MARK: - Native presenter (default)

    /// The default native presenter: an `NSAlert` configured for the site and
    /// run as a modal sheet on the attached host window. The first button
    /// (index `.alertFirstButtonReturn`) is `.accepted`; any other response is
    /// `.canceled`. AppKit requires this run on the main thread.
    private static func nativePresent(
        site: MonaDialogSite,
        kind: MonaDialogKind,
        window: NSWindow
    ) -> MonaDialogOutcome {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = site.title
        alert.informativeText = site.detail
        switch kind {
        case .confirmSheet:
            // 2-button confirm: accept (primary) then cancel (secondary).
            alert.addButton(withTitle: site.acceptLabel)
            alert.addButton(withTitle: site.cancelLabel)
        case .messageSheet:
            // 1-button message: OK — dismiss has no side effect.
            alert.addButton(withTitle: site.acceptLabel)
        }
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            return .accepted
        }
        return .canceled
    }
}
