// MonaAsyncValidityTicketTests.swift
//
// P01-T010 — Gate asynchronous publication with validity tickets.
//
// Verifies that `MonaAsyncValidityTicket` is an immutable snapshot of
// (model identity hash, versionId, alternativeVersionId, ownerGeneration,
// cancellationGeneration) captured at the start of an async operation, and
// that `MonaPublicationGate` validates the complete ticket immediately before
// publication: a valid ticket allows publication, while a stale ticket (version
// changed, model replaced, or cancelled) drops the result SILENTLY — no
// events, no cache writes, no decorations, no selection mutations.
//
// Test contract (P01-T010): immutable ticket; validate-before-publish;
// drop-stale-silently.

import XCTest
import MonaCode

final class MonaAsyncValidityTicketTests: XCTestCase {

    // MARK: - 1. MonaAsyncValidityTicket is an immutable snapshot of the five
    //          captured fields

    /// A ticket stores its five fields verbatim and does not mutate after init.
    /// Two tickets with equal fields are equal (value semantics).
    func testTicketIsImmutableWithValueSemantics() {
        let ticket = MonaAsyncValidityTicket(
            modelIdentityHash: "model-A",
            versionId: 7,
            alternativeVersionId: 5,
            ownerGeneration: 3,
            cancellationGeneration: 2
        )

        XCTAssertEqual(ticket.modelIdentityHash, "model-A")
        XCTAssertEqual(ticket.versionId, 7)
        XCTAssertEqual(ticket.alternativeVersionId, 5)
        XCTAssertEqual(ticket.ownerGeneration, 3)
        XCTAssertEqual(ticket.cancellationGeneration, 2)

        // Value semantics: equal fields ⇒ equal tickets.
        let twin = MonaAsyncValidityTicket(
            modelIdentityHash: "model-A",
            versionId: 7,
            alternativeVersionId: 5,
            ownerGeneration: 3,
            cancellationGeneration: 2
        )
        XCTAssertEqual(ticket, twin)

        // A differing field ⇒ not equal.
        let differentVersion = MonaAsyncValidityTicket(
            modelIdentityHash: "model-A",
            versionId: 8,
            alternativeVersionId: 5,
            ownerGeneration: 3,
            cancellationGeneration: 2
        )
        XCTAssertNotEqual(ticket, differentVersion)

        let differentOwner = MonaAsyncValidityTicket(
            modelIdentityHash: "model-A",
            versionId: 7,
            alternativeVersionId: 5,
            ownerGeneration: 4,
            cancellationGeneration: 2
        )
        XCTAssertNotEqual(ticket, differentOwner)

        let differentCancellation = MonaAsyncValidityTicket(
            modelIdentityHash: "model-A",
            versionId: 7,
            alternativeVersionId: 5,
            ownerGeneration: 3,
            cancellationGeneration: 3
        )
        XCTAssertNotEqual(ticket, differentCancellation)

        let differentIdentity = MonaAsyncValidityTicket(
            modelIdentityHash: "model-B",
            versionId: 7,
            alternativeVersionId: 5,
            ownerGeneration: 3,
            cancellationGeneration: 2
        )
        XCTAssertNotEqual(ticket, differentIdentity)
    }

    // MARK: - 2. captureTicket() snapshots the gate's current state

    /// `captureTicket()` reads the live model version / alternative version /
    /// identity and the gate's owner / cancellation generations into an
    /// immutable ticket.
    func testCaptureTicketSnapshotsCurrentState() {
        let model = MonaCodeModel(text: "abc", uri: MonaURI(scheme: "inmemory", path: "/m"))
        let gate = MonaPublicationGate(model: model)

        let v0 = model.getVersionId()
        let av0 = model.getAlternativeVersionId()

        let ticket = gate.captureTicket()

        XCTAssertEqual(ticket.versionId, v0, "ticket must capture the live version id")
        XCTAssertEqual(ticket.alternativeVersionId, av0, "ticket must capture the live alternative version id")
        XCTAssertEqual(ticket.modelIdentityHash, gate.currentModelIdentityHash,
                       "ticket must capture the gate's current model identity hash")
        XCTAssertEqual(ticket.ownerGeneration, gate.ownerGeneration,
                       "ticket must capture the gate's owner generation")
        XCTAssertEqual(ticket.cancellationGeneration, gate.cancellationGeneration,
                       "ticket must capture the gate's cancellation generation")
    }

    // MARK: - 3. validate(_:) returns true for a fresh ticket

    /// A ticket captured against the current state validates as fresh.
    func testValidateReturnsTrueForFreshTicket() {
        let model = MonaCodeModel(text: "hello", uri: MonaURI(scheme: "inmemory", path: "/m"))
        let gate = MonaPublicationGate(model: model)

        let ticket = gate.captureTicket()
        XCTAssertTrue(gate.validate(ticket), "a fresh ticket must validate")
    }

    // MARK: - 4. publish(_:_:) invokes the closure and returns the result for
    //          a valid ticket

    /// A valid ticket allows publication: the publish closure is invoked and
    /// its result is returned.
    func testPublishInvokesClosureForValidTicket() {
        let model = MonaCodeModel(text: "hello", uri: MonaURI(scheme: "inmemory", path: "/m"))
        let gate = MonaPublicationGate(model: model)

        var closureCalled = false
        let result: String? = gate.publish(gate.captureTicket()) {
            closureCalled = true
            return "published"
        }

        XCTAssertTrue(closureCalled, "a valid ticket must invoke the publish closure")
        XCTAssertEqual(result, "published", "a valid ticket must return the closure's result")
    }

    // MARK: - 5. Stale: version changed ⇒ dropped silently

    /// If the model's version id has changed since the ticket was captured (the
    /// model was mutated directly, bypassing the gate), publication is dropped
    /// SILENTLY: the closure is never invoked, the result is nil, and no events
    /// / cache / decorations / selections are produced.
    func testStaleVersionChangedDropsSilently() {
        let model = MonaCodeModel(text: "abc", uri: MonaURI(scheme: "inmemory", path: "/m"))
        let gate = MonaPublicationGate(model: model)

        var eventsFired = 0
        let disposable = model.onDidChangeContent { _ in eventsFired += 1 }
        defer { disposable.dispose() }

        let ticket = gate.captureTicket()
        let versionBefore = model.getVersionId()

        // Mutate the model out of band, bumping the version → ticket is stale.
        model.setValue("abcdef")
        let versionAfterBump = model.getVersionId()
        XCTAssertNotEqual(versionAfterBump, versionBefore, "setValue must bump the version")

        var closureCalled = false
        var cacheWrites = 0
        var decorationAdds = 0
        var selectionMutations = 0

        let result: String? = gate.publish(ticket) {
            closureCalled = true
            cacheWrites += 1
            decorationAdds += 1
            selectionMutations += 1
            return "published"
        }

        // Silent drop.
        XCTAssertNil(result, "a stale (version-changed) ticket must drop the result, returning nil")
        XCTAssertFalse(closureCalled, "a stale ticket must NOT invoke the publish closure")
        XCTAssertEqual(cacheWrites, 0, "no cache writes on a dropped publication")
        XCTAssertEqual(decorationAdds, 0, "no decoration additions on a dropped publication")
        XCTAssertEqual(selectionMutations, 0, "no selection mutations on a dropped publication")
        // Only the setValue event fired; the dropped publish added none.
        XCTAssertEqual(eventsFired, 1, "the dropped publish must fire no events")
        XCTAssertEqual(model.getVersionId(), versionAfterBump,
                       "the dropped publish must not change the version")
    }

    // MARK: - 6. Stale: model replaced ⇒ dropped silently

    /// If the gate's model has been replaced since the ticket was captured (the
    /// owner generation bumped), publication is dropped silently.
    func testStaleModelReplacedDropsSilently() {
        let modelA = MonaCodeModel(text: "abc", uri: MonaURI(scheme: "inmemory", path: "/a"))
        let gate = MonaPublicationGate(model: modelA)

        let ticket = gate.captureTicket()
        let ownerBefore = gate.ownerGeneration
        XCTAssertEqual(ticket.ownerGeneration, ownerBefore)

        // Replace the model out of band → owner generation bumps → ticket stale.
        let modelB = MonaCodeModel(text: "xyz", uri: MonaURI(scheme: "inmemory", path: "/b"))
        gate.replaceModel(modelB)
        XCTAssertEqual(gate.ownerGeneration, ownerBefore + 1, "replaceModel must bump the owner generation")
        XCTAssertNotEqual(gate.currentModelIdentityHash, ticket.modelIdentityHash,
                          "the new model must have a different identity hash")

        var closureCalled = false
        let result: String? = gate.publish(ticket) {
            closureCalled = true
            return "published"
        }

        XCTAssertNil(result, "a stale (model-replaced) ticket must drop the result")
        XCTAssertFalse(closureCalled, "a stale (model-replaced) ticket must NOT invoke the publish closure")
    }

    // MARK: - 7. Stale: cancelled ⇒ dropped silently

    /// If cancellation has been requested since the ticket was captured (the
    /// cancellation generation bumped), publication is dropped silently.
    func testStaleCancelledDropsSilently() {
        let model = MonaCodeModel(text: "abc", uri: MonaURI(scheme: "inmemory", path: "/m"))
        let gate = MonaPublicationGate(model: model)

        let ticket = gate.captureTicket()
        let cancellationBefore = gate.cancellationGeneration
        XCTAssertEqual(ticket.cancellationGeneration, cancellationBefore)

        // Request cancellation → cancellation generation bumps → ticket stale.
        gate.cancel()
        XCTAssertEqual(gate.cancellationGeneration, cancellationBefore + 1,
                       "cancel must bump the cancellation generation")

        var closureCalled = false
        let result: String? = gate.publish(ticket) {
            closureCalled = true
            return "published"
        }

        XCTAssertNil(result, "a stale (cancelled) ticket must drop the result")
        XCTAssertFalse(closureCalled, "a stale (cancelled) ticket must NOT invoke the publish closure")
    }

    // MARK: - 8. Re-arm: a fresh ticket captured AFTER cancellation is valid
    //          again

    /// Bumping the cancellation generation only invalidates tickets captured
    /// before the bump. A ticket captured after the bump validates against the
    /// new generation and publishes.
    func testFreshTicketAfterCancellationIsValidAgain() {
        let model = MonaCodeModel(text: "abc", uri: MonaURI(scheme: "inmemory", path: "/m"))
        let gate = MonaPublicationGate(model: model)

        let staleTicket = gate.captureTicket()
        gate.cancel()  // invalidates staleTicket

        XCTAssertNil(gate.publish(staleTicket) { "stale-published" },
                     "the pre-cancel ticket must be dropped")

        // A new ticket captured after cancellation validates and publishes.
        let freshTicket = gate.captureTicket()
        XCTAssertEqual(freshTicket.cancellationGeneration, gate.cancellationGeneration,
                       "the fresh ticket must capture the current cancellation generation")

        var closureCalled = false
        let result: String? = gate.publish(freshTicket) {
            closureCalled = true
            return "fresh-published"
        }

        XCTAssertTrue(closureCalled, "the fresh post-cancel ticket must invoke the publish closure")
        XCTAssertEqual(result, "fresh-published",
                       "the fresh post-cancel ticket must return the closure's result")
    }

    // MARK: - 9. validate(_:) returns false for each staleness dimension

    /// Explicitly assert that each of the three staleness dimensions (version,
    /// owner generation, cancellation generation) — plus a differing model
    /// identity — independently invalidates the ticket.
    func testValidateReturnsFalseForEachStalenessDimension() {
        let model = MonaCodeModel(text: "abc", uri: MonaURI(scheme: "inmemory", path: "/m"))
        let gate = MonaPublicationGate(model: model)

        // Version changed.
        let vTicket = gate.captureTicket()
        model.setValue("abcdef")
        XCTAssertFalse(gate.validate(vTicket), "version divergence must invalidate")

        // Re-establish a fresh baseline for the next dimension.
        let freshModel = MonaCodeModel(text: "abc", uri: MonaURI(scheme: "inmemory", path: "/m"))
        let gate2 = MonaPublicationGate(model: freshModel)

        // Model replaced (owner generation bumped).
        let oTicket = gate2.captureTicket()
        gate2.replaceModel(MonaCodeModel(text: "xyz", uri: MonaURI(scheme: "inmemory", path: "/r")))
        XCTAssertFalse(gate2.validate(oTicket), "owner generation divergence must invalidate")

        // Cancellation requested.
        let gate3 = MonaPublicationGate(model: MonaCodeModel(text: "abc", uri: MonaURI(scheme: "inmemory", path: "/m")))
        let cTicket = gate3.captureTicket()
        gate3.cancel()
        XCTAssertFalse(gate3.validate(cTicket), "cancellation generation divergence must invalidate")

        // Differing model identity (hand-constructed ticket with a foreign hash).
        let gate4 = MonaPublicationGate(model: MonaCodeModel(text: "abc", uri: MonaURI(scheme: "inmemory", path: "/m")))
        let foreignTicket = MonaAsyncValidityTicket(
            modelIdentityHash: "a-foreign-identity-hash",
            versionId: gate4.captureTicket().versionId,
            alternativeVersionId: gate4.captureTicket().alternativeVersionId,
            ownerGeneration: gate4.ownerGeneration,
            cancellationGeneration: gate4.cancellationGeneration
        )
        XCTAssertFalse(gate4.validate(foreignTicket),
                       "a differing model identity hash must invalidate")
    }
}
