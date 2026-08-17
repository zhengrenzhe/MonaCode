// MonaAXMutationGatewayTests.swift
//
// P04-T013 — Route accessibility setters through ModelInputBarrier.
//
// Verifies the accessibility mutation gateway (`MonaAXMutationGateway`): the
// chokepoint that translates VoiceOver / AXUIElement setter calls (set-value,
// set-selection, increment, decrement, press, custom) into Core model input
// plans and routes them through `MonaModelInputBarrier` (P04-T005) — the same
// all-or-none transaction path keyboard / IME / multi-cursor input uses — so
// every AX-driven mutation goes through one chokepoint.
//
// Test contract (P04-T013):
//   1. Each action type translates to the right Core input plan.
//   2. Each of the five pre-commit validations (focus, editability, model
//      version, range, owner generation) rejects before the barrier commits.
//   3. Accessibility notifications fire ONLY on a successful commit, and are
//      suppressed on pre-commit rejection, barrier rollback, and barrier drop.

import XCTest
import AppKit
import CoreGraphics
import CoreText
import MonaCode
import MonaCodeAppKit
@testable import MonaCodeAppKit

final class MonaAXMutationGatewayTests: XCTestCase {

    // MARK: - Shared helpers

    /// Menlo is the default macOS monospace face and is always present.
    private let menlo = MonaFontDescriptor(familyName: "Menlo", size: 12)

    /// All the strong references a test needs to keep alive while the gateway
    /// holds them weakly.
    private struct GatewayFixture {
        let gateway: MonaAXMutationGateway
        let model: MonaCodeModel
        let inputBarrier: MonaModelInputBarrier
        let focusCoordinator: MonaAXFocusCoordinator
        let announcementBridge: MonaAXAnnouncementBridge
        let geometry: MonaQueryGeometryBarrier?
    }

    /// Creates a model from a `String`.
    private func makeModel(_ text: String) -> MonaCodeModel {
        return MonaCodeModel(text: text, uri: MonaURI(scheme: "inmemory", path: "/ax-gateway"))
    }

    /// Builds a complete-generation geometry barrier (P03-T007) over `model`,
    /// with one generation already published.
    private func makeGeometryBarrier(model: MonaCodeModel, lineHeight: Int = 20) -> MonaQueryGeometryBarrier {
        let viewGraph = MonaViewGraph(model: model, lineHeight: lineHeight)
        let scrollModel = MonaScrollModel(
            contentWidth: 400,
            contentHeight: Double(3 * lineHeight),
            viewportWidth: 400,
            viewportHeight: Double(lineHeight)
        )
        let resolver = MonaFontFallbackResolver(primary: menlo, fallback: [])
        let shaper = MonaTextShaper(primaryFont: menlo, fallback: resolver, direction: .ltr, scale: 1)
        let builder = MonaLineLayoutBuilder(shaper: shaper)
        let provider: (Int) -> [UInt16] = { Array(model.getLineContent($0).utf16) }
        let barrier = MonaQueryGeometryBarrier(
            viewGraph: viewGraph,
            scrollModel: scrollModel,
            builder: builder,
            lineHeight: lineHeight,
            codeUnitsForModelLine: provider
        )
        _ = barrier.publishGeneration(visibleViewLines: 1...3)
        return barrier
    }

    /// Builds a gateway wired to a model, input barrier, focus coordinator,
    /// announcement bridge, and (optionally) a geometry barrier with one
    /// published generation.
    private func makeGateway(
        text: String = "abc\ndef\nghi",
        focus: MonaAXFocusMode = .editor,
        isEditable: @escaping () -> Bool = { true },
        withGeometry: Bool = false
    ) -> GatewayFixture {
        let model = makeModel(text)
        let inputBarrier = MonaModelInputBarrier(model: model)
        let focusCoordinator = MonaAXFocusCoordinator(initial: focus)
        let announcementBridge = MonaAXAnnouncementBridge(profile: .default)
        var geometry: MonaQueryGeometryBarrier? = nil
        if withGeometry {
            geometry = makeGeometryBarrier(model: model)
        }
        let gateway = MonaAXMutationGateway(
            model: model,
            barrier: inputBarrier,
            geometryBarrier: geometry,
            focusCoordinator: focusCoordinator,
            announcementBridge: announcementBridge,
            isEditable: isEditable
        )
        return GatewayFixture(
            gateway: gateway,
            model: model,
            inputBarrier: inputBarrier,
            focusCoordinator: focusCoordinator,
            announcementBridge: announcementBridge,
            geometry: geometry
        )
    }

    // MARK: - Operation 1: Each action type translates to the right plan

    /// set-value translates to a full-text-replace plan: the edit's range is the
    /// full model range and its text is the new value.
    func testSetValueTranslatesToFullTextReplacePlan() {
        let f = makeGateway(text: "abc\ndef")
        let model = f.model
        let plan = f.gateway.translate(.setValue(text: "xyz"), model: model)
        XCTAssertEqual(plan?.primary.range, model.getFullModelRange())
        XCTAssertEqual(plan?.primary.text, "xyz")
        XCTAssertEqual(plan?.primary.kind, .text)
    }

    /// set-selection translates to a selection-only plan: a folded (zero-length)
    /// empty edit at the selection start — no text change.
    func testSetSelectionTranslatesToSelectionOnlyPlan() {
        let f = makeGateway(text: "abc\ndef")
        let model = f.model
        let selRange = MonaRange(startLine: 1, startColumn: 2, endLine: 1, endColumn: 4)
        let plan = f.gateway.translate(.setSelection(range: selRange), model: model)
        XCTAssertEqual(plan?.primary.text, "", "set-selection must carry no text change")
        let start = selRange.startPosition
        XCTAssertEqual(plan?.primary.range, MonaRange(startPosition: start, endPosition: start),
                       "set-selection edit must be folded at the selection start")
    }

    /// increment translates to a numeric-adjust plan: the edit replaces the
    /// numeric text at the range with current + delta.
    func testIncrementTranslatesToNumericAdjustPlan() {
        let f = makeGateway(text: "count: 42 done")
        let model = f.model
        // "42" occupies columns 8..9 (range end-exclusive at column 10).
        let range = MonaRange(startLine: 1, startColumn: 8, endLine: 1, endColumn: 10)
        let plan = f.gateway.translate(.increment(delta: 1, range: range), model: model)
        XCTAssertEqual(plan?.primary.range, range)
        XCTAssertEqual(plan?.primary.text, "43")
    }

    /// decrement translates to a numeric-adjust plan: the edit replaces the
    /// numeric text at the range with current - delta.
    func testDecrementTranslatesToNumericAdjustPlan() {
        let f = makeGateway(text: "count: 42 done")
        let model = f.model
        let range = MonaRange(startLine: 1, startColumn: 8, endLine: 1, endColumn: 10)
        let plan = f.gateway.translate(.decrement(delta: 1, range: range), model: model)
        XCTAssertEqual(plan?.primary.range, range)
        XCTAssertEqual(plan?.primary.text, "41")
    }

    /// press translates to a folded no-op plan at the given position — the
    /// command handler is dispatched post-commit, not encoded in the plan.
    func testPressTranslatesToFoldedNoOpPlan() {
        let f = makeGateway(text: "abc")
        let model = f.model
        let pos = MonaPosition(line: 1, column: 2)
        let plan = f.gateway.translate(.press(command: "openFind", at: pos), model: model)
        XCTAssertEqual(plan?.primary.text, "")
        XCTAssertEqual(plan?.primary.range, MonaRange(startPosition: pos, endPosition: pos))
    }

    /// custom translates to a folded no-op plan at the given position — the
    /// registered handler is dispatched post-commit, not encoded in the plan.
    func testCustomTranslatesToFoldedNoOpPlan() {
        let f = makeGateway(text: "abc")
        let model = f.model
        let pos = MonaPosition(line: 1, column: 1)
        let plan = f.gateway.translate(.custom(identifier: "quickAction", at: pos), model: model)
        XCTAssertEqual(plan?.primary.text, "")
        XCTAssertEqual(plan?.primary.range, MonaRange(startPosition: pos, endPosition: pos))
    }

    /// increment on a range whose text is not an integer cannot be translated
    /// into a plan (`translate` returns nil) — the gateway rejects with
    /// `.untranslatable` at perform time.
    func testIncrementOnNonNumericTextIsUntranslatable() {
        let f = makeGateway(text: "abc")
        let model = f.model
        let range = MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 4)
        let plan = f.gateway.translate(.increment(delta: 1, range: range), model: model)
        XCTAssertNil(plan, "increment on non-numeric text must not translate to a plan")
    }

    /// set-value performs end-to-end: the model text is replaced and the
    /// outcome is `.applied`.
    func testSetValuePerformReplacesFullText() {
        let f = makeGateway(text: "abc\ndef")
        let request = MonaAXMutationRequest(
            action: .setValue(text: "xyz"),
            issuedModelVersion: f.model.getVersionId()
        )
        XCTAssertEqual(f.gateway.perform(request), .applied)
        XCTAssertEqual(f.model.getValue(), "xyz")
    }

    /// set-selection performs end-to-end: no text change, outcome `.applied`.
    func testSetSelectionPerformLeavesTextUnchanged() {
        let f = makeGateway(text: "abc\ndef")
        let request = MonaAXMutationRequest(
            action: .setSelection(range: MonaRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 3)),
            issuedModelVersion: f.model.getVersionId()
        )
        XCTAssertEqual(f.gateway.perform(request), .applied)
        XCTAssertEqual(f.model.getValue(), "abc\ndef", "set-selection must not change text")
    }

    /// increment performs end-to-end: the numeric value at the range is
    /// adjusted by +delta.
    func testIncrementPerformAdjustsNumericValue() {
        let f = makeGateway(text: "count: 42 done")
        let range = MonaRange(startLine: 1, startColumn: 8, endLine: 1, endColumn: 10)
        let request = MonaAXMutationRequest(
            action: .increment(delta: 1, range: range),
            issuedModelVersion: f.model.getVersionId()
        )
        XCTAssertEqual(f.gateway.perform(request), .applied)
        XCTAssertEqual(f.model.getValue(), "count: 43 done")
    }

    /// decrement performs end-to-end: the numeric value at the range is
    /// adjusted by -delta.
    func testDecrementPerformAdjustsNumericValue() {
        let f = makeGateway(text: "count: 42 done")
        let range = MonaRange(startLine: 1, startColumn: 8, endLine: 1, endColumn: 10)
        let request = MonaAXMutationRequest(
            action: .decrement(delta: 1, range: range),
            issuedModelVersion: f.model.getVersionId()
        )
        XCTAssertEqual(f.gateway.perform(request), .applied)
        XCTAssertEqual(f.model.getValue(), "count: 41 done")
    }

    /// press invokes the registered command handler post-commit.
    func testPressInvokesRegisteredCommandOnSuccess() {
        let f = makeGateway(text: "abc")
        var invoked = false
        f.gateway.registerPressHandler("openFind") { invoked = true }
        let request = MonaAXMutationRequest(
            action: .press(command: "openFind", at: MonaPosition(line: 1, column: 1)),
            issuedModelVersion: f.model.getVersionId()
        )
        XCTAssertEqual(f.gateway.perform(request), .applied)
        XCTAssertTrue(invoked, "press must dispatch the registered command on success")
    }

    /// custom dispatches to the registered handler post-commit.
    func testCustomDispatchesToRegisteredHandlerOnSuccess() {
        let f = makeGateway(text: "abc")
        var invoked = false
        f.gateway.registerCustomHandler("quickAction") { invoked = true }
        let request = MonaAXMutationRequest(
            action: .custom(identifier: "quickAction", at: MonaPosition(line: 1, column: 1)),
            issuedModelVersion: f.model.getVersionId()
        )
        XCTAssertEqual(f.gateway.perform(request), .applied)
        XCTAssertTrue(invoked, "custom must dispatch to the registered handler on success")
    }

    // MARK: - Operation 2: Five pre-commit validations reject (no partial state)

    /// Focus check: a non-editing-capable focus mode (`.widget`) rejects before
    /// commit. No notification is published.
    func testRejectsWhenFocusNotEditingCapable() {
        let f = makeGateway(text: "abc", focus: .widget)
        let request = MonaAXMutationRequest(
            action: .setValue(text: "xyz"),
            issuedModelVersion: f.model.getVersionId()
        )
        XCTAssertEqual(f.gateway.perform(request), .rejected(reason: .focusNotEditingCapable))
        XCTAssertEqual(f.announcementBridge.pendingCount, 0)
        XCTAssertEqual(f.model.getValue(), "abc", "rejected mutation must not change the model")
    }

    /// Editability check: a read-only target rejects before commit.
    func testRejectsWhenNotEditable() {
        let f = makeGateway(text: "abc", isEditable: { false })
        let request = MonaAXMutationRequest(
            action: .setValue(text: "xyz"),
            issuedModelVersion: f.model.getVersionId()
        )
        XCTAssertEqual(f.gateway.perform(request), .rejected(reason: .notEditable))
        XCTAssertEqual(f.announcementBridge.pendingCount, 0)
    }

    /// Model-version check: a stale issued version rejects before commit.
    func testRejectsStaleModelVersion() {
        let f = makeGateway(text: "abc")
        let request = MonaAXMutationRequest(
            action: .setValue(text: "xyz"),
            issuedModelVersion: f.model.getVersionId() + 1
        )
        XCTAssertEqual(f.gateway.perform(request), .rejected(reason: .staleModelVersion))
        XCTAssertEqual(f.announcementBridge.pendingCount, 0)
    }

    /// Range check: an out-of-bounds range rejects before commit.
    func testRejectsInvalidRange() {
        let f = makeGateway(text: "abc")
        // (1,1)..(5,1) extends past the single-line model → invalid.
        let badRange = MonaRange(startLine: 1, startColumn: 1, endLine: 5, endColumn: 1)
        let request = MonaAXMutationRequest(
            action: .setSelection(range: badRange),
            issuedModelVersion: f.model.getVersionId()
        )
        XCTAssertEqual(f.gateway.perform(request), .rejected(reason: .invalidRange))
        XCTAssertEqual(f.announcementBridge.pendingCount, 0)
    }

    /// Owner-generation check: a stale issued generation rejects before commit.
    func testRejectsStaleGeneration() {
        let f = makeGateway(text: "abc\ndef\nghi", withGeometry: true)
        guard let gb = f.geometry, let gen = gb.currentGeneration else {
            return XCTFail("geometry barrier must have a published generation")
        }
        let request = MonaAXMutationRequest(
            action: .setValue(text: "xyz"),
            issuedModelVersion: f.model.getVersionId(),
            issuedGeneration: gen + 1
        )
        XCTAssertEqual(f.gateway.perform(request), .rejected(reason: .staleGeneration))
        XCTAssertEqual(f.announcementBridge.pendingCount, 0)
    }

    /// A matching issued generation passes the owner-generation check (the
    /// mutation commits). This is the positive control for the generation gate.
    func testMatchingGenerationPasses() {
        let f = makeGateway(text: "abc\ndef\nghi", withGeometry: true)
        guard let gb = f.geometry, let gen = gb.currentGeneration else {
            return XCTFail("geometry barrier must have a published generation")
        }
        let request = MonaAXMutationRequest(
            action: .setValue(text: "xyz"),
            issuedModelVersion: f.model.getVersionId(),
            issuedGeneration: gen
        )
        XCTAssertEqual(f.gateway.perform(request), .applied)
    }

    // MARK: - Operation 3: Notifications fire only on success

    /// A successful commit publishes exactly one accessibility announcement.
    func testNotificationFiresOnSuccess() {
        let f = makeGateway(text: "abc")
        let request = MonaAXMutationRequest(
            action: .setValue(text: "xyz"),
            issuedModelVersion: f.model.getVersionId()
        )
        XCTAssertEqual(f.gateway.perform(request), .applied)
        XCTAssertEqual(f.announcementBridge.pendingCount, 1,
                       "a successful commit must publish one announcement")
        XCTAssertEqual(f.announcementBridge.nextAnnouncement(), "Selection changed")
    }

    /// A pre-commit rejection publishes NO announcement.
    func testNotificationSuppressedOnPreCommitRejection() {
        let f = makeGateway(text: "abc", focus: .widget)
        let request = MonaAXMutationRequest(
            action: .setValue(text: "xyz"),
            issuedModelVersion: f.model.getVersionId()
        )
        XCTAssertEqual(f.gateway.perform(request), .rejected(reason: .focusNotEditingCapable))
        XCTAssertEqual(f.announcementBridge.pendingCount, 0,
                       "a rejected mutation must not publish an announcement")
    }

    /// When the barrier rolls back (the prepared plan's range becomes invalid
    /// for the model between validation and commit), NO announcement is published.
    func testNotificationSuppressedOnRollback() {
        let f = makeGateway(text: "abc\ndef\nghi")
        let model = f.model
        // Seam: mutate the model BEFORE prepare so prepare captures the new
        // version, but the plan's full-range edit (built against the prior
        // model) is invalid for the mutated model → the barrier rolls back.
        f.gateway.beforePrepare = { _, m in m.setValue("x") }
        let request = MonaAXMutationRequest(
            action: .setValue(text: "new"),
            issuedModelVersion: model.getVersionId()
        )
        XCTAssertEqual(f.gateway.perform(request), .rolledBack)
        XCTAssertEqual(f.announcementBridge.pendingCount, 0,
                       "a rolled-back transaction must not publish an announcement")
    }

    /// When the barrier drops (the captured version diverges from the live
    /// model between prepare and commit), NO announcement is published.
    func testNotificationSuppressedOnDrop() {
        let f = makeGateway(text: "abc\ndef\nghi")
        let model = f.model
        // Seam: mutate the model AFTER prepare so the captured version diverges
        // from the live version → the barrier drops.
        f.gateway.beforeCommit = { _, _, m in m.setValue("x") }
        let request = MonaAXMutationRequest(
            action: .setValue(text: "new"),
            issuedModelVersion: model.getVersionId()
        )
        XCTAssertEqual(f.gateway.perform(request), .dropped)
        XCTAssertEqual(f.announcementBridge.pendingCount, 0,
                       "a dropped transaction must not publish an announcement")
    }

    /// press / custom handlers are NOT dispatched when the mutation is rejected
    /// pre-commit. (Handlers fire only on a successful commit.)
    func testPressHandlerSuppressedOnRejection() {
        let f = makeGateway(text: "abc", focus: .widget)
        var invoked = false
        f.gateway.registerPressHandler("openFind") { invoked = true }
        let request = MonaAXMutationRequest(
            action: .press(command: "openFind", at: MonaPosition(line: 1, column: 1)),
            issuedModelVersion: f.model.getVersionId()
        )
        XCTAssertEqual(f.gateway.perform(request), .rejected(reason: .focusNotEditingCapable))
        XCTAssertFalse(invoked, "handlers must not fire on a rejected mutation")
        XCTAssertEqual(f.announcementBridge.pendingCount, 0)
    }
}
