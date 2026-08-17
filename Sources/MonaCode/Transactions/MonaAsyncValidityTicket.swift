// MonaAsyncValidityTicket.swift
//
// P01-T010 — Gate asynchronous publication with validity tickets.
//
// `MonaAsyncValidityTicket` is an immutable snapshot of the truth an async
// operation captured at the moment it started — the Swift counterpart of the
// "alive version" capture Monaco takes before kicking off a deferred
// computation (tokenization, search, linked edits, etc.) and re-checks before
// publishing its result (monaco-editor 0.56.0). The ticket freezes five values
// that, taken together, identify "the model as this operation saw it":
//
//   - `modelIdentityHash`     — a hash of the model instance's identity. Two
//                                different model instances produce different
//                                hashes, so a replaced model invalidates the
//                                ticket even if the new instance reuses the
//                                same URI-derived id.
//   - `versionId`              — the model's version id at capture time. A
//                                version bump (direct mutation, an edit
//                                transaction, or a flush) means the operation's
//                                captured offsets may have moved.
//   - `alternativeVersionId`  — the pre-edit alternative version, captured so
//                                undo-tracking callers can detect that the
//                                model's undo frontier has advanced.
//   - `ownerGeneration`        — the generation counter on the publication
//                                gate's owner. Bumped when the gate's model is
//                                replaced wholesale, invalidating every
//                                outstanding ticket in one bump.
//   - `cancellationGeneration` — the generation counter on the operation's
//                                cancellation. Bumped when cancellation is
//                                requested, so a ticket captured before the
//                                bump is dropped even if a later operation
//                                re-arms cancellation for itself.
//
// The ticket is a pure value: it holds no reference back to the gate or model,
// performs no I/O, and never mutates. It is validated by `MonaPublicationGate`
// immediately before the operation publishes its result.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// An immutable snapshot of the model / version / owner / cancellation truth
/// captured at the start of an async operation, validated before its result is
/// published.
///
/// Capture one with `MonaPublicationGate.captureTicket()` at the start of the
/// operation, and validate it with `MonaPublicationGate.validate(_:)` (or gate
/// publication through `MonaPublicationGate.publish(_:_:)`) immediately before
/// publishing. A ticket whose captured values no longer match the live state is
/// stale and must be dropped silently.
public struct MonaAsyncValidityTicket: Equatable {

    /// A hash of the model instance's identity at capture time. Two different
    /// model instances produce different hashes, so a replaced model
    /// invalidates the ticket.
    public let modelIdentityHash: String

    /// The model's version id at capture time. A version bump since capture
    /// means the operation's captured offsets may have moved.
    public let versionId: Int

    /// The model's alternative version id at capture time (the pre-edit
    /// version, used for undo-frontier detection).
    public let alternativeVersionId: Int

    /// The publication gate's owner generation at capture time. Bumped when the
    /// gate's model is replaced wholesale; every outstanding ticket captured
    /// before the bump is invalidated.
    public let ownerGeneration: Int

    /// The operation's cancellation generation at capture time. Bumped when
    /// cancellation is requested; a ticket captured before the bump is dropped.
    public let cancellationGeneration: Int

    /// Creates an immutable ticket snapshot of the five captured values.
    public init(
        modelIdentityHash: String,
        versionId: Int,
        alternativeVersionId: Int,
        ownerGeneration: Int,
        cancellationGeneration: Int
    ) {
        self.modelIdentityHash = modelIdentityHash
        self.versionId = versionId
        self.alternativeVersionId = alternativeVersionId
        self.ownerGeneration = ownerGeneration
        self.cancellationGeneration = cancellationGeneration
    }
}
