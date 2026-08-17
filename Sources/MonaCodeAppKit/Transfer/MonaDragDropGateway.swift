// MonaDragDropGateway.swift
//
// P04-T009 — Implement drag, drop, and macOS Services transfer.
//
// `MonaDragDropGateway` is the SINGLE native gateway that handles drag and
// drop across the editor boundary — the Swift counterpart of Monaco's drag-and-
// drop service (monaco-editor 0.56.0). This is the one place where AppKit
// drag-session fields (drag types, operation masks, drop geometry, transfer
// payloads) become Core values.
//
// Responsibilities (per the G6-R contract):
//
//   1. Drag types — validate that the dragging pasteboard carries at least one
//      accepted UTI type (plain-text, rich-text, file URLs). `accepts(dragTypes:)`
//      answers whether a drag should be entertained; `acceptedPasteboardTypes`
//      is the concrete `NSPasteboard.PasteboardType` list the editor registers.
//   2. Operation masks — mask a requested `NSDragOperation`-style mask down to
//      the accepted operations (copy / move / link) via `validate(operation:)`.
//   3. Drop geometry — resolve the drop position through the geometry barrier
//      (P03-T007 `MonaQueryGeometryBarrier`) against the model's current version
//      via `resolveDropGeometry(point:model:geometryBarrier:)`. The returned
//      `MonaDropGeometry` carries the resolved position AND the version id the
//      geometry was resolved against, so a later commit can reject stale
//      geometry (the model changed since the drag started).
//   4. Direct drop-edit providers — transform the dropped content before
//      insertion. Each registered `MonaDropEditProvider` runs in registration
//      order, feeding each provider the output of the previous one. Supports
//      cancellation (via `MonaCancellationToken`) and validity tickets (via
//      `MonaAsyncValidityTicket` + `MonaPublicationGate`). Mirrors the
//      paste-edit pipeline semantics (P04-T008) but for drops.
//   5. Transfer payloads — `readTransferPayload(from:operation:geometry:)` reads
//      the dropped content from the dragging pasteboard through the SAME
//      `MonaPasteboardGateway` used by copy/paste, validates the drag types +
//      operation, and returns a `MonaDragTransferPayload` carrying the content,
//      masked operation, and drop geometry.
//
// Disposal: `dispose()` clears the provider list exactly once (idempotent —
// further calls are no-ops, and a disposed gateway runs no providers).
//
// `MonaCodeAppKit` may `import AppKit`, `import Foundation`, and `import MonaCode`.

import AppKit
import Foundation
import MonaCode

// MARK: - MonaDragOperation

/// A drag operation mask, mirroring the three `NSDragOperation` flags Monaco
/// uses. An OptionSet so a drag can carry multiple accepted operations
/// (e.g. `[.copy, .move]`).
public struct MonaDragOperation: OptionSet, Equatable, Hashable, Sendable {

    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Copy operation (NSDragOperationCopy).
    public static let copy = MonaDragOperation(rawValue: 1 << 0)

    /// Move operation (NSDragOperationMove).
    public static let move = MonaDragOperation(rawValue: 1 << 1)

    /// Link operation (NSDragOperationLink).
    public static let link = MonaDragOperation(rawValue: 1 << 2)

    /// Maps an `NSDragOperation` to the corresponding `MonaDragOperation` mask,
    /// preserving only the copy / move / link flags Monaco recognizes.
    public static func from(_ nsOperation: NSDragOperation) -> MonaDragOperation {
        var mask: MonaDragOperation = []
        if nsOperation.contains(.copy) { mask.insert(.copy) }
        if nsOperation.contains(.move) { mask.insert(.move) }
        if nsOperation.contains(.link) { mask.insert(.link) }
        return mask
    }

    /// Maps this mask back to an `NSDragOperation` for the AppKit drag surface.
    public func toNSDragOperation() -> NSDragOperation {
        var ns: NSDragOperation = []
        if contains(.copy) { ns.insert(.copy) }
        if contains(.move) { ns.insert(.move) }
        if contains(.link) { ns.insert(.link) }
        return ns
    }
}

// MARK: - MonaDragType

/// The accepted drag UTI types — which pasteboard flavors the editor will
/// accept on a drag. An OptionSet so the editor can accept multiple flavors.
public struct MonaDragType: OptionSet, Equatable, Hashable, Sendable {

    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Plain-text flavor (`public.utf8-plain-text`, surfaced as `.string`).
    public static let plainText = MonaDragType(rawValue: 1 << 0)

    /// Rich-text flavor (`public.rtf`, surfaced as `.rtf`).
    public static let richText = MonaDragType(rawValue: 1 << 1)

    /// File-URL flavor (`public.file-url`, surfaced as `.fileURL`).
    public static let fileURLs = MonaDragType(rawValue: 1 << 2)

    /// All supported flavors.
    public static let all: MonaDragType = [.plainText, .richText, .fileURLs]
}

// MARK: - MonaDropGeometry

/// The drop geometry: the resolved model position for a drop, captured against
/// a specific model version so a later commit can reject stale geometry.
///
/// Build via `MonaDragDropGateway.resolveDropGeometry(point:model:geometryBarrier:)`,
/// which resolves the position through the geometry barrier (P03-T007) and
/// stamps the model's current version id. A geometry is stale when the model
/// version diverges from `resolvedVersionId` (the model changed since the drag
/// started); reject stale geometry with
/// `MonaDragDropGateway.isDropGeometryStale(_:model:)`.
public struct MonaDropGeometry: Equatable {

    /// The resolved model position (1-based line/column) for the drop.
    public let position: MonaPosition

    /// The model version id the geometry was resolved against. A commit-time
    /// divergence (the model's `getVersionId()` differs) means the geometry is
    /// stale and the drop must be rejected.
    public let resolvedVersionId: Int

    /// The geometry barrier generation the position was resolved against, or
    /// `nil` if the barrier had no complete generation (only present when the
    /// geometry was built without a barrier).
    public let resolvedGeneration: Int?

    /// Creates a drop geometry value.
    public init(position: MonaPosition, resolvedVersionId: Int, resolvedGeneration: Int? = nil) {
        self.position = position
        self.resolvedVersionId = resolvedVersionId
        self.resolvedGeneration = resolvedGeneration
    }

    /// Returns whether this geometry is stale relative to `currentVersionId`:
    /// stale when the version diverges.
    public func isStale(relativeTo currentVersionId: Int) -> Bool {
        return currentVersionId != resolvedVersionId
    }
}

// MARK: - MonaDropEditProvider

/// A drop-edit provider: transforms the dropped content before insertion.
///
/// Each provider receives the content produced by the previous provider (or the
/// raw dropped content for the first provider), plus the drop geometry, the
/// cancellation token, and the validity ticket in force. Return nil to cancel
/// the drop (drop the content); return a transformed value to pass it to the
/// next provider.
///
/// Mirrors `MonaPasteEditProvider` (P04-T008) but for drops — the provider also
/// receives the resolved drop `geometry` so a provider can adapt the content to
/// the drop target (e.g. adjust indentation to the drop column).
public protocol MonaDropEditProvider: AnyObject {

    /// Stable identifier for this provider (diagnostics / ordering).
    var identifier: String { get }

    /// Transforms `content` before insertion. Return nil to cancel the drop.
    func edit(
        _ content: MonaClipboardContent,
        geometry: MonaDropGeometry,
        cancellationToken: MonaCancellationToken,
        ticket: MonaAsyncValidityTicket
    ) -> MonaClipboardContent?
}

// MARK: - MonaDragTransferPayload

/// The transfer payload carried by a drag session: the dropped clipboard
/// content, the accepted (masked) operation, and the drop geometry.
public struct MonaDragTransferPayload {

    /// The dropped clipboard content (plain-text / rich-text / metadata),
    /// read through the same `MonaPasteboardGateway` as copy/paste.
    public let content: MonaClipboardContent

    /// The accepted operation mask (the requested operation intersected with
    /// the gateway's accepted operations).
    public let operation: MonaDragOperation

    /// The drop geometry the content should land at.
    public let geometry: MonaDropGeometry

    /// Creates a transfer payload value.
    public init(content: MonaClipboardContent, operation: MonaDragOperation, geometry: MonaDropGeometry) {
        self.content = content
        self.operation = operation
        self.geometry = geometry
    }
}

// MARK: - MonaDragDropGateway

/// The single native gateway that handles drag and drop.
///
/// Construct with `init(acceptedDragTypes:acceptedOperations:)` (defaults to all
/// drag types and copy+move). Validate a drag with `accepts(dragTypes:)` and
/// `validate(operation:)`. Resolve the drop position with
/// `resolveDropGeometry(point:model:geometryBarrier:)`. Run drop-edit providers
/// with `runDropEditProviders(_:geometry:...)`. Read the dropped content with
/// `readTransferPayload(from:operation:geometry:)`. Reject stale geometry with
/// `isDropGeometryStale(_:model:)`. Dispose the provider list with `dispose()`
/// (idempotent).
public final class MonaDragDropGateway {

    /// The accepted drag UTI types (drag types).
    public var acceptedDragTypes: MonaDragType

    /// The accepted operation mask.
    public var acceptedOperations: MonaDragOperation

    /// The registered drop-edit providers, in registration order.
    private var dropEditProviders: [MonaDropEditProvider] = []

    /// Whether the provider list has been disposed. Once true, `dispose()` is a
    /// no-op and `runDropEditProviders` runs no providers.
    private var disposed = false

    /// Creates a gateway with the given accepted drag types and operations.
    ///
    /// - Parameters:
    ///   - acceptedDragTypes: The UTI types accepted on a drag (defaults to all).
    ///   - acceptedOperations: The operations accepted on a drop (defaults to
    ///     copy + move).
    public init(
        acceptedDragTypes: MonaDragType = .all,
        acceptedOperations: MonaDragOperation = [.copy, .move]
    ) {
        self.acceptedDragTypes = acceptedDragTypes
        self.acceptedOperations = acceptedOperations
    }

    // MARK: - Drag type validation

    /// The concrete `NSPasteboard.PasteboardType` list the editor registers as
    /// draggable, derived from `acceptedDragTypes`.
    public var acceptedPasteboardTypes: [NSPasteboard.PasteboardType] {
        var types: [NSPasteboard.PasteboardType] = []
        if acceptedDragTypes.contains(.plainText) {
            types.append(.string)
        }
        if acceptedDragTypes.contains(.richText) {
            types.append(.rtf)
        }
        if acceptedDragTypes.contains(.fileURLs) {
            types.append(.fileURL)
        }
        return types
    }

    /// Returns `true` when `dragTypes` carries at least one accepted type.
    ///
    /// A drag is entertained only when the dragging pasteboard advertises at
    /// least one of the gateway's accepted `NSPasteboard.PasteboardType`s.
    public func accepts(dragTypes: [NSPasteboard.PasteboardType]) -> Bool {
        let accepted = Set(acceptedPasteboardTypes)
        return dragTypes.contains { accepted.contains($0) }
    }

    // MARK: - Operation mask validation

    /// Validates `operation` by masking it down to the accepted operations.
    /// Returns the intersection of `operation` and `acceptedOperations` (an
    /// empty mask means the drop should be rejected).
    public func validate(operation: MonaDragOperation) -> MonaDragOperation {
        return operation.intersection(acceptedOperations)
    }

    // MARK: - Drop geometry

    /// Resolves the drop geometry at `point` (viewport space) through the
    /// geometry barrier against `model`'s current version.
    ///
    /// - Returns: The drop geometry carrying the resolved position + version
    ///   stamp, or `nil` when the barrier cannot resolve the position (no
    ///   complete generation, out of bounds, bounded-completion failure). No
    ///   partial geometry is synthesized.
    public func resolveDropGeometry(
        point: CGPoint,
        model: MonaCodeModel,
        geometryBarrier: MonaQueryGeometryBarrier
    ) -> MonaDropGeometry? {
        let result = geometryBarrier.hitTest(point: point)
        guard case .available(let position) = result else {
            return nil
        }
        return MonaDropGeometry(
            position: position,
            resolvedVersionId: model.getVersionId(),
            resolvedGeneration: geometryBarrier.currentGeneration
        )
    }

    /// Rejects stale drop geometry: returns `true` when `geometry` was resolved
    /// against a different model version than `model`'s current version (the
    /// model changed since the drag started).
    ///
    /// A drop whose geometry is stale must NOT commit — the resolved position no
    /// longer corresponds to the model the user is looking at.
    public func isDropGeometryStale(
        _ geometry: MonaDropGeometry,
        model: MonaCodeModel
    ) -> Bool {
        return geometry.isStale(relativeTo: model.getVersionId())
    }

    // MARK: - Drop-edit providers

    /// Appends `provider` to the end of the drop-edit provider chain.
    public func register(_ provider: MonaDropEditProvider) {
        dropEditProviders.append(provider)
    }

    /// Runs the drop-edit provider chain over `content` in registration order.
    ///
    /// - If the gateway has been disposed, returns `nil` (no provider runs).
    /// - If `cancellationToken.isCancellationRequested`, drops immediately (nil).
    /// - If `gate` + `ticket` are supplied and the ticket is stale, drops (nil).
    /// - Each provider receives the previous provider's output (or `content`
    ///   for the first), plus the `geometry`. A provider returning nil drops
    ///   the drop (nil); subsequent providers do not run.
    /// - With no providers (and not disposed), the content is returned unchanged.
    public func runDropEditProviders(
        _ content: MonaClipboardContent,
        geometry: MonaDropGeometry,
        cancellationToken: MonaCancellationToken = .none,
        gate: MonaPublicationGate? = nil,
        ticket: MonaAsyncValidityTicket? = nil
    ) -> MonaClipboardContent? {
        // A disposed gateway runs no providers and drops the content.
        guard !disposed else {
            return nil
        }
        // Cancellation truth: drop before running any provider.
        if cancellationToken.isCancellationRequested {
            return nil
        }
        // Validity truth: a stale ticket drops the drop silently.
        if let gate = gate, let ticket = ticket, !gate.validate(ticket) {
            return nil
        }

        var current = content
        for provider in dropEditProviders {
            // Re-check cancellation before each provider so a provider that
            // observed cancellation mid-pipeline stops the remaining chain.
            if cancellationToken.isCancellationRequested {
                return nil
            }
            guard let next = provider.edit(
                current,
                geometry: geometry,
                cancellationToken: cancellationToken,
                ticket: ticket ?? freshTicket()
            ) else {
                return nil
            }
            current = next
        }
        return current
    }

    /// A default fresh ticket for providers when the caller did not supply one.
    /// Providers may ignore it; it carries no cancellation/version truth when
    /// the caller did not arm a gate.
    private func freshTicket() -> MonaAsyncValidityTicket {
        return MonaAsyncValidityTicket(
            modelIdentityHash: "",
            versionId: 0,
            alternativeVersionId: 0,
            ownerGeneration: 0,
            cancellationGeneration: 0
        )
    }

    // MARK: - Transfer payload

    /// Reads the transfer payload from a dragging `pasteboard`.
    ///
    /// Validates that the pasteboard carries at least one accepted drag type
    /// and that the requested `operation` intersects the accepted operations,
    /// then reads the clipboard content through the SAME pasteboard gateway used
    /// by copy/paste (P04-T008). Returns the payload carrying the content, the
    /// masked operation, and `geometry`, or `nil` when the drag types / operation
    /// are rejected or the pasteboard carries no content.
    public func readTransferPayload(
        from pasteboard: NSPasteboard,
        operation: MonaDragOperation,
        geometry: MonaDropGeometry
    ) -> MonaDragTransferPayload? {
        // 1. Validate drag types: the pasteboard must carry at least one
        //    accepted flavor.
        let pbTypes = pasteboard.types ?? []
        guard accepts(dragTypes: pbTypes) else {
            return nil
        }
        // 2. Validate the operation mask: mask to accepted operations.
        let masked = validate(operation: operation)
        guard !masked.isEmpty else {
            return nil
        }
        // 3. Read the clipboard content through the same pasteboard pipeline as
        //    copy/paste so drag/drop and copy/paste share one read path.
        let reader = MonaPasteboardGateway(pasteboard: pasteboard)
        guard let content = reader.read() else {
            return nil
        }
        return MonaDragTransferPayload(content: content, operation: masked, geometry: geometry)
    }

    // MARK: - Disposal

    /// Disposes the drop-edit provider list. After this call no provider runs.
    ///
    /// Idempotent: calling `dispose()` more than once is a no-op. The provider
    /// list is cleared exactly once; a disposed gateway returns `nil` from
    /// `runDropEditProviders` without running any provider.
    public func dispose() {
        guard !disposed else {
            return
        }
        disposed = true
        dropEditProviders.removeAll()
    }

    /// Whether the gateway has been disposed.
    public var isDisposed: Bool {
        return disposed
    }
}
