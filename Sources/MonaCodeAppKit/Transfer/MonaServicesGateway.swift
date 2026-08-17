// MonaServicesGateway.swift
//
// P04-T009 — Implement drag, drop, and macOS Services transfer.
//
// `MonaServicesGateway` maps macOS Services (the NSPasteboard read/write
// selection surface) to the SAME transfer pipeline as copy/paste
// (P04-T008 `MonaPasteboardGateway` + `MonaPasteEditPipeline`). macOS Services
// lets other applications read the editor's selection and write text into the
// editor through the pasteboard; this gateway routes those operations through
// the single pasteboard gateway and the paste-edit pipeline so Services,
// copy/paste, and drag/drop share one read/write + provider path — the Swift
// counterpart of Monaco's `services` service (monaco-editor 0.56.0).
//
// Responsibilities (per the G6-R contract):
//
//   1. `readSelection() -> MonaClipboardContent?` — reads the current Services
//      selection from the pasteboard through `MonaPasteboardGateway.read()`.
//      Returns nil when the pasteboard carries none of the flavors.
//   2. `writeSelection(_ content:)` — writes `content` to the Services
//      pasteboard through `MonaPasteboardGateway.write(_:)`.
//   3. `runSelectionEditProviders(...)` — runs the paste-edit pipeline's
//      registered providers in deterministic order over a Services insertion,
//      delegating to `MonaPasteEditPipeline.run(_:...)`. This guarantees
//      Services uses the SAME provider-ordered transformations as copy/paste:
//      a provider registered once applies to clipboard paste, drop, AND
//      Services insertions.
//
// The gateway is a thin adapter: it holds a `MonaPasteboardGateway` (the
// read/write authority) and a `MonaPasteEditPipeline` (the provider authority),
// and forwards. No Services-specific pasteboard representation exists — Services
// reuses the plain-text / rich-text / editor-metadata representations owned by
// the pasteboard gateway.
//
// `MonaCodeAppKit` may `import AppKit`, `import Foundation`, and `import MonaCode`.

import AppKit
import Foundation
import MonaCode

/// Maps macOS Services (NSPasteboard read/write selection) to the same transfer
/// pipeline as copy/paste (P04-T008).
///
/// Construct with `init(pasteboardGateway:pipeline:)`. Read the current
/// Services selection with `readSelection()`. Write a selection with
/// `writeSelection(_:)`. Run the paste-edit providers over a Services insertion
/// with `runSelectionEditProviders(_:cancellationToken:gate:ticket:)`.
public final class MonaServicesGateway {

    /// The pasteboard gateway used to read and write the Services selection.
    /// Shared with copy/paste so Services and clipboard use one read/write path.
    public let pasteboardGateway: MonaPasteboardGateway

    /// The paste-edit pipeline used to run provider-ordered transformations on
    /// Services insertions. Shared with copy/paste so a provider registered once
    /// applies to clipboard paste, drop, AND Services.
    public let pipeline: MonaPasteEditPipeline

    /// Creates a Services gateway over the given pasteboard gateway and
    /// paste-edit pipeline.
    ///
    /// - Parameters:
    ///   - pasteboardGateway: The pasteboard gateway reading/writing the
    ///     Services selection pasteboard. Typically the same instance used by
    ///     the copy/paste gateway.
    ///   - pipeline: The paste-edit pipeline running provider-ordered
    ///     transformations. Typically the same instance used by copy/paste.
    public init(
        pasteboardGateway: MonaPasteboardGateway,
        pipeline: MonaPasteEditPipeline
    ) {
        self.pasteboardGateway = pasteboardGateway
        self.pipeline = pipeline
    }

    // MARK: - Read selection

    /// Reads the current Services selection from the pasteboard.
    ///
    /// Delegates to `MonaPasteboardGateway.read()` so Services reads the EXACT
    /// same plain-text / rich-text / editor-metadata representations as
    /// copy/paste. Returns `nil` when the pasteboard carries none of the flavors.
    public func readSelection() -> MonaClipboardContent? {
        return pasteboardGateway.read()
    }

    // MARK: - Write selection

    /// Writes `content` to the Services selection pasteboard.
    ///
    /// Delegates to `MonaPasteboardGateway.write(_:)` so Services writes the
    /// exact same plain-text / rich-text / editor-metadata representations as
    /// copy/paste.
    public func writeSelection(_ content: MonaClipboardContent) {
        pasteboardGateway.write(content)
    }

    // MARK: - Provider-ordered transformations

    /// Runs the paste-edit pipeline's registered providers over `content` in
    /// registration order, for a Services insertion.
    ///
    /// Delegates to `MonaPasteEditPipeline.run(_:cancellationToken:gate:ticket:)`
    /// so Services uses the SAME provider-ordered transformations as copy/paste.
    /// A provider registered once on the shared pipeline applies to clipboard
    /// paste, drop, AND Services insertions.
    ///
    /// - If `cancellationToken.isCancellationRequested`, drops immediately (nil).
    /// - If `gate` + `ticket` are supplied and the ticket is stale, drops (nil).
    /// - Each provider receives the previous provider's output (or `content`
    ///   for the first). A provider returning nil drops the insertion (nil).
    /// - With no providers, the content is returned unchanged.
    public func runSelectionEditProviders(
        _ content: MonaClipboardContent,
        cancellationToken: MonaCancellationToken = .none,
        gate: MonaPublicationGate? = nil,
        ticket: MonaAsyncValidityTicket? = nil
    ) -> MonaClipboardContent? {
        return pipeline.run(
            content,
            cancellationToken: cancellationToken,
            gate: gate,
            ticket: ticket
        )
    }
}
