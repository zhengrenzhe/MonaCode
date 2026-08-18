// MonaDialogServiceTests.swift
//
// P07-T004 — Project four dialog sites into host-authorized native dialogs.
//
// Verifies the S1-R dialog closure (services-s1r-session-feedback-closure.html):
// monaco-editor@0.56.0 has exactly four RETAINED dialog call sites, and the
// MonaCode port projects each onto a host-authorized native macOS sheet/alert.
// The four retained sites (the cut sites are NOT mapped):
//
//   1. unusualLine    — Remove / Ignore      (2-button confirm sheet)
//   2. workspaceUndo  — Undo in N Files / Dismiss (2-button confirm sheet)
//   3. undoConfirm    — Yes / No             (2-button confirm sheet)
//   4. commandError   — OK                   (1-button message sheet)
//
// Load-bearing invariants (each proven below in `testFourSiteOutcomeMatrix`):
//
//   - Exactly four retained dialog call sites are mapped to native sheet or
//     alert requests (the cut sites — e.g. saveConflict — are absent).
//   - A dialog requires an attached, authorized host window (the NSWindow
//     sourced from P04-T014's `MonaCodeEditorView`).
//   - The three outcomes `.accepted`, `.canceled`, `.unavailable` are all
//     typed and reachable.
//   - When presentation is unavailable (no attached authorized host window),
//     the result is `.unavailable` — NEVER `.accepted`. The host-authorization
//     gate precedes presentation, so a hostile presenter that would accept is
//     bypassed entirely; acceptance is never fabricated.
//
// Test contract (P07-T004): 1 case (testFourSiteOutcomeMatrix).
// MonaCodeAppKitTests imports XCTest + AppKit + MonaCodeAppKit.

import XCTest
import AppKit
import MonaCodeAppKit
@testable import MonaCodeAppKit

@MainActor
final class MonaDialogServiceTests: XCTestCase {

    // MARK: - The single test contract case

    /// The four-site outcome matrix: exactly four retained sites map to native
    /// sheet/alert requests; an attached authorized host window is required;
    /// `.accepted` / `.canceled` / `.unavailable` are all reachable; and
    /// acceptance is NEVER fabricated when presentation is unavailable.
    func testFourSiteOutcomeMatrix() {

        // ----------------------------------------------------------------
        // 1. Exactly four retained dialog call sites — the S1-R four.
        // ----------------------------------------------------------------

        let sites = MonaDialogService.retainedSites
        XCTAssertEqual(sites.count, 4,
                       "S1-R retains exactly four dialog call sites")
        let expectedSites: Set<MonaDialogSite> = [
            .unusualLine, .workspaceUndo, .undoConfirm, .commandError
        ]
        XCTAssertEqual(Set(sites), expectedSites,
                       "the four retained sites are unusual-line, workspace-undo, undo-confirm, command-error")

        // The cut sites (e.g. saveConflict — a save affordance fixed-standalone
        // MonaCode does not present) are NOT mapped: the retained set is exactly
        // these four, so no fifth site is reachable. `retainedSites` is the
        // complete reachable dialog surface — any site outside the four would be
        // a DIALOG_SITE_MISMATCH and is absent by construction.
        let reachableIDs = Set(sites.map { $0.rawValue })
        XCTAssertEqual(reachableIDs.count, 4,
                       "no duplicate dialog site identities — exactly four reachable")

        // ----------------------------------------------------------------
        // 2. Each retained site maps to a native sheet or alert request.
        //    All four project onto NSAlert sheets (confirm or message).
        // ----------------------------------------------------------------

        for site in sites {
            let kind = MonaDialogService.kind(for: site)
            XCTAssertTrue(kind == .confirmSheet || kind == .messageSheet,
                          "\(site.rawValue) must map to a native sheet or alert request")
        }
        // The three confirms are 2-button sheets; command-error is a 1-button
        // message sheet (OK — dismiss has no side effect).
        XCTAssertEqual(MonaDialogService.kind(for: .unusualLine),   .confirmSheet)
        XCTAssertEqual(MonaDialogService.kind(for: .workspaceUndo), .confirmSheet)
        XCTAssertEqual(MonaDialogService.kind(for: .undoConfirm),   .confirmSheet)
        XCTAssertEqual(MonaDialogService.kind(for: .commandError),  .messageSheet)

        // ----------------------------------------------------------------
        // 3. Requires an attached authorized host window. With NO host
        //    attached, `present` returns `.unavailable` — and crucially
        //    NOT `.accepted`. The host-authorization gate precedes
        //    presentation, so a hostile presenter that would fabricate
        //    acceptance is never even consulted.
        // ----------------------------------------------------------------

        // A hostile presenter that ALWAYS returns `.accepted`. The contract
        // requires that this presenter is bypassed when no authorized host
        // window is attached — acceptance must never be fabricated.
        let hostilePresenter: (MonaDialogSite, MonaDialogKind, NSWindow) -> MonaDialogOutcome =
            { _, _, _ in .accepted }

        let unattached = MonaDialogService(presenter: hostilePresenter)
        XCTAssertFalse(unattached.isHostAttached,
                       "service with no host attached must report not attached")
        // Every site is `.unavailable` when no host is attached.
        for site in sites {
            XCTAssertEqual(unattached.present(site: site), .unavailable,
                           "\(site.rawValue) must be unavailable with no host window")
            XCTAssertNotEqual(unattached.present(site: site), .accepted,
                              "NEVER fabricate acceptance when presentation is unavailable")
        }

        // ----------------------------------------------------------------
        // 4. The host window is sourced from P04-T014's MonaCodeEditorView
        //    (the editor view is the host window source). Attach an editor
        //    view to a window; the view's `.window` is the host NSWindow.
        // ----------------------------------------------------------------

        let hostWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let editorView = MonaCodeEditorView(frame: NSRect(x: 0, y: 0, width: 480, height: 320))
        hostWindow.contentView = editorView
        XCTAssertTrue(editorView.window === hostWindow,
                      "P04-T014 MonaCodeEditorView provides the attached host window")

        // ----------------------------------------------------------------
        // 5. `.accepted` and `.canceled` are reachable with an attached
        //    authorized host. `.unavailable` reappears after detach. The
        //    outcome is driven by the site + the authorized host, not by
        //    fabricating acceptance.
        // ----------------------------------------------------------------

        let acceptAll: (MonaDialogSite, MonaDialogKind, NSWindow) -> MonaDialogOutcome =
            { _, _, _ in .accepted }
        let cancelAll: (MonaDialogSite, MonaDialogKind, NSWindow) -> MonaDialogOutcome =
            { _, _, _ in .canceled }

        let acceptedSvc = MonaDialogService(presenter: acceptAll)
        acceptedSvc.attachAuthorizedHost(hostWindow)
        XCTAssertTrue(acceptedSvc.isHostAttached,
                      "service reports attached after attachAuthorizedHost")
        XCTAssertEqual(acceptedSvc.present(site: .unusualLine),   .accepted)
        XCTAssertEqual(acceptedSvc.present(site: .commandError), .accepted)

        let canceledSvc = MonaDialogService(presenter: cancelAll)
        canceledSvc.attachAuthorizedHost(hostWindow)
        XCTAssertEqual(canceledSvc.present(site: .workspaceUndo), .canceled)
        XCTAssertEqual(canceledSvc.present(site: .undoConfirm),   .canceled)

        // After detach, presentation is unavailable again — and once more
        // acceptance is NOT fabricated even though the presenter would cancel
        // (the gate returns `.unavailable` before consulting the presenter).
        canceledSvc.detachHost()
        XCTAssertFalse(canceledSvc.isHostAttached)
        XCTAssertEqual(canceledSvc.present(site: .undoConfirm), .unavailable,
                       "detached host → unavailable")
        XCTAssertNotEqual(canceledSvc.present(site: .undoConfirm), .accepted,
                          "NEVER fabricate acceptance after detach")

        // ----------------------------------------------------------------
        // 6. No-fabricate-acceptance verification (security/UX gate): across
        //    every condition where presentation is unavailable, the result is
        //    `.unavailable`, never `.accepted`.
        // ----------------------------------------------------------------

        let neverFabricateNoHost    = (unattached.present(site: .commandError)  != .accepted)
        let neverFabricateAfterDetach = (canceledSvc.present(site: .commandError) != .accepted)
        let neverFabricated = neverFabricateNoHost && neverFabricateAfterDetach
        XCTAssertTrue(neverFabricated,
                      "acceptance is never fabricated when presentation is unavailable")

        // ----------------------------------------------------------------
        // Green marker — exactly four sites, outcomes exact.
        // ----------------------------------------------------------------

        let count = sites.count
        let outcomesExact =
            (unattached.present(site: .unusualLine)    == .unavailable) &&  // no host
            (acceptedSvc.present(site: .unusualLine)    == .accepted)   &&  // attached + accept
            (canceledSvc.present(site: .workspaceUndo)  == .unavailable) &&  // detached
            neverFabricated
        XCTAssertTrue(outcomesExact, "accepted/canceled/unavailable outcomes exact")
        print("DIALOG_SITES count=\(count) outcomes=\(outcomesExact ? "exact" : "mismatch")")
    }
}
