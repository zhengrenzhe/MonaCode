// MonaPublicationGate.swift
//
// P01-T010 — Gate asynchronous publication with validity tickets.
//
// `MonaPublicationGate` is the chokepoint an async operation passes through
// immediately before publishing its result — the Swift counterpart of the
// "alive version" re-check Monaco performs before a deferred computation may
// write back into the model (monaco-editor 0.56.0). The gate validates a
// `MonaAsyncValidityTicket` captured at the start of the operation; if the
// ticket is still fresh, publication proceeds, otherwise the result is dropped
// SILENTLY:
//
//   - no events are fired,
//   - no cache writes occur,
//   - no decorations are added,
//   - no selection mutations are applied.
//
// "Silently" is load-bearing: a stale result is not an error, not a log line,
// not a partial publication — the publish closure is simply never invoked, so
// none of its side effects happen. The caller learns of the drop from the
// `nil` return of `publish(_:_:)`.
//
// The gate owns two generation counters that, together with the model's live
// version / alternative version / identity, make up the complete ticket:
//
//   - `ownerGeneration`        — bumped by `replaceModel(_:)` when the gate's
//                                model is replaced wholesale. Every outstanding
//                                ticket captured before the bump is invalidated
//                                in one shot.
//   - `cancellationGeneration` — bumped by `cancel()` when cancellation is
//                                requested. A ticket captured before the bump
//                                is dropped; a ticket captured after the bump
//                                validates against the new generation (re-arm).
//
// The gate wraps an existing `MonaCodeModel`; text truth continues to live in
// the Piece Tree. The gate owns the ASYNC PUBLICATION truth: the ticket captured
// at `captureTicket()` is the authority, and any divergence is reported as a
// dropped (silent) publication.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// Validates a `MonaAsyncValidityTicket` immediately before an async operation
/// publishes its result, dropping stale results silently.
///
/// Create with `init(model:)`. Capture a ticket with `captureTicket()` at the
/// start of the async operation, and gate publication through
/// `publish(_:_:)` (or `validate(_:)`) immediately before publishing. Bump the
/// owner generation with `replaceModel(_:)` when the model is replaced, and the
/// cancellation generation with `cancel()` when cancellation is requested.
public final class MonaPublicationGate {

    // MARK: - Owned truth

    /// The model this gate validates tickets against. Swapped (and the owner
    /// generation bumped) by `replaceModel(_:)`.
    private var model: MonaCodeModel

    /// The owner generation. Bumped each time the gate's model is replaced
    /// wholesale, invalidating every outstanding ticket captured before the
    /// bump. Starts at 0.
    public private(set) var ownerGeneration: Int = 0

    /// The cancellation generation. Bumped each time `cancel()` is requested,
    /// invalidating every outstanding ticket captured before the bump. Starts
    /// at 0. A ticket captured after a bump validates against the new
    /// generation (re-arm).
    public private(set) var cancellationGeneration: Int = 0

    // MARK: - Initialization

    /// Creates a gate that validates tickets against `model`.
    public init(model: MonaCodeModel) {
        self.model = model
    }

    // MARK: - Model identity

    /// A hash of the gate's current model instance identity. Two different
    /// model instances produce different hashes. Read by `captureTicket()`
    /// and compared by `validate(_:)`.
    public var currentModelIdentityHash: String {
        return MonaPublicationGate.identityHash(for: model)
    }

    /// Computes a stable-per-process hash of a model instance's identity.
    /// `ObjectIdentifier` distinguishes two different instances even when they
    /// share a URI-derived id, so a replaced model invalidates the ticket.
    internal static func identityHash(for model: MonaCodeModel) -> String {
        return String(ObjectIdentifier(model).hashValue)
    }

    // MARK: - Capture

    /// Captures an immutable `MonaAsyncValidityTicket` snapshot of the gate's
    /// current state: the model's live identity hash, version id, and
    /// alternative version id, plus the gate's owner and cancellation
    /// generations.
    ///
    /// Call this at the start of an async operation; validate the returned
    /// ticket immediately before publishing the operation's result.
    public func captureTicket() -> MonaAsyncValidityTicket {
        return MonaAsyncValidityTicket(
            modelIdentityHash: currentModelIdentityHash,
            versionId: model.getVersionId(),
            alternativeVersionId: model.getAlternativeVersionId(),
            ownerGeneration: ownerGeneration,
            cancellationGeneration: cancellationGeneration
        )
    }

    // MARK: - Validate

    /// Returns `true` when `ticket` is still fresh against the gate's current
    /// state — the model identity hash, version id, alternative version id,
    /// owner generation, and cancellation generation all still match. Returns
    /// `false` (stale) if any of them has diverged.
    ///
    /// The complete ticket is validated: a single diverging field is enough to
    /// drop the result.
    public func validate(_ ticket: MonaAsyncValidityTicket) -> Bool {
        // Model replaced wholesale (owner generation bumped) — fastest check.
        if ticket.ownerGeneration != ownerGeneration {
            return false
        }
        // Model identity: a different instance invalidates even if the owner
        // generation has not been bumped through the public API.
        if ticket.modelIdentityHash != currentModelIdentityHash {
            return false
        }
        // Cancellation requested since capture.
        if ticket.cancellationGeneration != cancellationGeneration {
            return false
        }
        // Version truth: the model was mutated directly, bypassing the gate.
        if ticket.versionId != model.getVersionId() {
            return false
        }
        // Alternative version truth: the undo frontier advanced.
        if ticket.alternativeVersionId != model.getAlternativeVersionId() {
            return false
        }
        return true
    }

    // MARK: - Publish

    /// Validates `ticket` and, if it is still fresh, invokes `publish` and
    /// returns its result. If the ticket is stale, the result is dropped
    /// SILENTLY: `publish` is never invoked (so no events, no cache writes, no
    /// decorations, no selection mutations occur) and `nil` is returned.
    ///
    /// Use the return value to branch on the outcome: a non-nil value means the
    /// publication ran; `nil` means it was dropped.
    @discardableResult
    public func publish<T>(_ ticket: MonaAsyncValidityTicket, _ publish: () -> T) -> T? {
        guard validate(ticket) else {
            // Drop silently: the publish closure is never invoked, so none of
            // its side effects (events, cache writes, decorations, selection
            // mutations) occur.
            return nil
        }
        return publish()
    }

    // MARK: - Owner / cancellation mutations

    /// Replaces the gate's model, bumping the owner generation and invalidating
    /// every outstanding ticket captured before the bump.
    public func replaceModel(_ newModel: MonaCodeModel) {
        self.model = newModel
        ownerGeneration += 1
    }

    /// Requests cancellation, bumping the cancellation generation and
    /// invalidating every outstanding ticket captured before the bump. A ticket
    /// captured after the bump validates against the new generation (re-arm).
    public func cancel() {
        cancellationGeneration += 1
    }
}
