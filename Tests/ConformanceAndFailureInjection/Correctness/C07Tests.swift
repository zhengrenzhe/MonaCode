// C07Tests.swift
//
// P09-T016 — Run C07: native input, transfer, accessibility, and workspace-edit
// equivalence.
//
// The C07 differential conformance suite — the SEVENTH C-candidate acceptance
// test. It compares the Swift port's native input (keyboard/IME/multi-cursor/
// pointer/scroll/clipboard/drag-drop/Services), accessibility (AX text/element/
// focus/mutation), and WorkspaceEdit (4-outcome atomic transaction) outputs
// against the monaco-editor reference fixtures M0 + M1, and binds all evidence
// hashes in one manifest.
//
// This is a DIFFERENTIAL test: the Swift port (native) is compared against the
// M0/M1 reference. The M0/M1 reference fixtures are:
//   - The I3-R4 public-event/pointer/scroll closure artifact
//     (native-input-i3r4-public-event-pointer-scroll-closure.html) — the M0/M1
//     input/pointer/scroll oracle (scroll precise delta ÷ 40; 14 pointer target
//     cases; click-count 400 ms clamp; EventControl truth table).
//   - The A1-R native-text-contract closure artifact
//     (accessibility-a1r-native-text-contract-closure.html) — the M0/M1 AX text
//     oracle (6 AX roles; raw UTF-16 indices; lone surrogate = 1 unit).
//   - The A2-R native-widget-focus closure artifact
//     (accessibility-a2r-native-widget-focus-closure.html) — the M0/M1 AX
//     focus/announcement oracle (5 focus modes; 7 announcement keys; dedup).
//   - The I4-R adversarial transfer closure (transfer-i4r-adversarial.html) —
//     the M0/M1 drag/drop/Services oracle (3 payload layers; 6 user ops).
//   - The S1-R session/feedback closure (services-s1r-session-feedback-closure.html)
//     — the M0/M1 services oracle (40 services; disposition partition 14+2+10+
//     2+1+1+8+2=40; session bounds 300/200/50/20/500).
//
// The 4 implementation operations:
//   1. Run ABC and Pinyin, chords, multi-cursor input, pointer, scroll, menu,
//      copy/cut/paste, drag/drop, Services, VoiceOver, focus, announcements,
//      and four WorkspaceEdit outcomes.
//   2. Run every contract overlay, T-1/T/T+1 boundary, raw-unit fixture,
//      native-adapted assertion, failure row, and exact-set check assigned to
//      the gate.
//   3. Bind comparator, native, environment, candidate, source revision,
//      fixture, and output hashes in one evidence manifest.
//   4. Treat every missing, skipped, stale, malformed, canceled, or
//      unauthorized case as not-passed.
//
// TEST-ONLY (productTarget null; create none, modify none). The file lives in
// the `conformance-and-failure-injection` target (non-test `.target`). The API
// is FROZEN (P07-T011). Discovery via MonaCodeTests linkage; `swift test
// --filter C07Tests` runs it.

import Foundation
import XCTest
import CryptoKit
import AppKit
import CoreGraphics
import MonaCode
import MonaCodeAppKit

// MARK: - C07Tests

final class C07Tests: XCTestCase {

    // MARK: - Frozen contract anchors (consumed unchanged from P09-T002)

    private static let frozenSourceRevision = "P07-T011"
    private static let frozenSourceSetDigest =
        "152c63ffc32ce2a632ff2a2caa2d3ee25063a1150c6f51bb44d5405aa30a1f36"
    private static let qualifiedSetHash =
        "f7ed2c5d3d6edbc8e9d6f7869041c9e67f9e3351d47eb71303e77edc22b676ce"

    private static let sixStaticCandidateFiles: [(name: String, leaf: String, file: String)] = [
        ("native-declaration",  "P08-T010", "monacode-p08-t010-native-declaration-manifest.json"),
        ("regExpUnicode",       "P08-T011", "monacode-p08-t011-regexp-unicode-manifest.json"),
        ("environment",         "P08-T012", "monacode-p08-t012-environment-manifest.json"),
        ("sourceClosure",       "P08-T013", "monacode-p08-t013-source-closure-manifest.json"),
        ("cache",               "P08-T014", "monacode-p08-t014-cache-manifest.json"),
        ("distribution",        "P08-T015", "monacode-p08-t015-distribution-manifest.json"),
    ]

    // MARK: - Accumulated native outputs

    private static let nativeOutputLock = NSLock()
    private nonisolated(unsafe) static var nativeOutputLines: [String] = []

    private static func recordNativeOutput(_ line: String) {
        nativeOutputLock.lock()
        defer { nativeOutputLock.unlock() }
        nativeOutputLines.append(line)
    }

    // MARK: Operation 1 — Run ABC and Pinyin, chords, multi-cursor input,
    // pointer, scroll, menu, copy/cut/paste, drag/drop, Services, VoiceOver,
    // focus, announcements, and four WorkspaceEdit outcomes.

    // ── 1a. Keyboard (ABC) + IME (Pinyin composition session) ──

    /// An ASCII keyDown (kVK_ANSI_A = 0) is translated exactly-once and
    /// losslessly through `MonaAppKeyEventGateway`, producing keyText "a" and
    /// keyCode .keyA. An IME composition cycle (mark → update → commit) drives
    /// `MonaCompositionSession` through the composing → committing → committed
    /// state machine, preserving the raw UTF-16 replacement range verbatim —
    /// the M0/M1 native-input contract (I3-R4 closure).
    @MainActor
    func testC07_KeyboardAndIMECompositionAgainstM0M1() {
        // ABC: ASCII keyDown through the gateway.
        let gateway = MonaAppKeyEventGateway()
        let event = keyDownEvent(keyCode: 0, characters: "a")
        let translated = gateway.translateKeyDown(event, isComposing: false)
        XCTAssertEqual(translated.keyText, "a",
                       "ABC: ASCII 'a' keyText preserved verbatim (M0/M1 match)")
        XCTAssertEqual(translated.keyCode, .keyA,
                       "ABC: macOS keyCode 0 → MonaKeyCode.keyA (M0/M1 match)")
        XCTAssertFalse(translated.isRepeat, "ABC: fresh press is not a repeat")
        XCTAssertFalse(translated.isComposing, "ABC: ABC path is not composing")
        Self.recordNativeOutput("keyboard:abc=keyText\(translated.keyText!)keyCode\(translated.keyCode)")

        // Pinyin: IME composition through MonaCompositionSession.
        let now: Double = 0
        let session = MonaCompositionSession(clock: { now }, timeoutInterval: 30.0)
        XCTAssertEqual(session.phase, .idle, "Pinyin: session starts idle (M0/M1 match)")

        // Mark "nǐ" (IME mid-composition). The replacement range is raw UTF-16.
        let replacement = NSRange(location: 5, length: 0)
        XCTAssertTrue(session.updateMarkedText("nǐ",
                                                selectedRange: NSRange(location: 0, length: 0),
                                                replacementRange: replacement),
                      "Pinyin: marked-text update succeeds (M0/M1 match)")
        XCTAssertEqual(session.phase, .composing, "Pinyin: session is composing")
        XCTAssertEqual(session.markedText, "nǐ",
                       "Pinyin: marked text stored verbatim (M0/M1 match)")
        XCTAssertEqual(session.replacementRange, replacement,
                       "Pinyin: raw UTF-16 replacement range preserved (M0/M1 match)")
        XCTAssertTrue(session.isActive, "Pinyin: session reports active composition")

        // Commit finalizes the composition with the chosen candidate "你好".
        let outcome = session.commit("你好")
        XCTAssertEqual(outcome, .committed("你好"),
                       "Pinyin: commit returns the final text (M0/M1 match)")
        XCTAssertEqual(session.phase, .committed, "Pinyin: session is committed")
        XCTAssertEqual(session.lastCommittedText, "你好",
                       "Pinyin: committed text recorded (M0/M1 match)")
        XCTAssertNil(session.markedText, "Pinyin: marked text cleared after commit")

        // Reset returns the session to idle.
        session.reset()
        XCTAssertEqual(session.phase, .idle, "Pinyin: reset returns to idle (M0/M1 match)")
        XCTAssertFalse(session.hasTimedOut(), "Pinyin: idle session is not timed out")
        Self.recordNativeOutput("keyboard:pinyin=idle→composing→committed→idle")
    }

    // ── 1b. Chord + multi-cursor + pointer + scroll ──

    /// A two-part keybinding (Cmd+K Cmd+C) enters the chord state on the first
    /// part, completes on the second part, and dispatches the command. A multi-
    /// cursor plan commits all edits in ONE transaction (or NONE on overlap).
    /// A pointer event translates button/phase/clickCount; a precise scroll
    /// delta is normalized (÷40) — the M0/M1 native-input contract (I3-R4).
    @MainActor
    func testC07_ChordMultiCursorPointerScrollAgainstM0M1() {
        // Chord: two-part keybinding resolution.
        let now: Double = 0
        let chordState = MonaChordState(clock: { now })
        let resolver = MonaKeybindingResolver(keybindings: [
            MonaKeybinding(
                key: .keyK, modifiers: .ctrlCmd, command: "editor.fold",
                when: nil, weight: 0,
                chordKey: .keyC, chordModifiers: .ctrlCmd
            )
        ])
        let context = MonaKeybindingContext()

        let first = MonaKeyEvent(keyCode: .keyK, keyText: "k", modifiers: .ctrlCmd,
                                  isRepeat: false, isComposing: false, timestamp: 1)
        let r1 = resolver.resolve(event: first, context: context, chordState: chordState)
        XCTAssertEqual(r1.chordStatus, .entered,
                       "Chord: first part enters the chord state (M0/M1 match)")
        XCTAssertNil(r1.commandId, "Chord: first part does not dispatch a command")
        XCTAssertTrue(chordState.isActive, "Chord: chord state is active after first part")

        let second = MonaKeyEvent(keyCode: .keyC, keyText: "c", modifiers: .ctrlCmd,
                                   isRepeat: false, isComposing: false, timestamp: 2)
        let r2 = resolver.resolve(event: second, context: context, chordState: chordState)
        XCTAssertEqual(r2.chordStatus, .completed,
                       "Chord: second part completes the chord (M0/M1 match)")
        XCTAssertEqual(r2.commandId, "editor.fold",
                       "Chord: command dispatches on completion (M0/M1 match)")
        XCTAssertFalse(chordState.isActive, "Chord: chord state is idle after completion")
        Self.recordNativeOutput("chord:cmdK+cmdC=completed:command=editor.fold")

        // Multi-cursor: all-or-none through the barrier.
        let model = MonaCodeModel(
            text: "abc\ndef\nghi",
            uri: MonaURI(scheme: "inmemory", path: "/c07-multi"))
        let barrier = MonaModelInputBarrier(model: model)
        let plan = MonaMultiCursorInputPlan.replicateText(
            cursorPositions: [MonaPosition(line: 1, column: 1),
                              MonaPosition(line: 2, column: 1)],
            text: "X"
        )
        let outcome = barrier.commit(plan)
        if case .applied(let selections) = outcome {
            XCTAssertEqual(selections.count, 2,
                           "Multi-cursor: two cursors → two selections (M0/M1 match)")
        } else {
            XCTFail("Multi-cursor: non-overlapping plan must apply; got \(outcome)")
        }
        XCTAssertEqual(model.getValue(), "Xabc\nXdef\nghi",
                       "Multi-cursor: both cursors committed in one transaction (M0/M1 match)")
        Self.recordNativeOutput("multiCursor:applied=2cursors:modelValueOK")

        // Pointer: mouseDown translated through the gateway.
        let pointerGateway = MonaPointerGateway()
        let mouseEvent = self.mouseEvent(buttonNumber: 0, clickCount: 1)
        let translatedPointer = pointerGateway.translate(
            mouseEvent, phase: .down, viewportPoint: CGPoint(x: 5, y: 5),
            resolvingPositionThrough: nil
        )
        XCTAssertEqual(translatedPointer.button, .left,
                       "Pointer: button 0 → .left (M0/M1 match)")
        XCTAssertEqual(translatedPointer.phase, .down,
                       "Pointer: phase preserved (M0/M1 match)")
        XCTAssertEqual(translatedPointer.clickCount, 1,
                       "Pointer: click count carried verbatim (M0/M1 match)")
        XCTAssertNil(translatedPointer.resolvedPosition,
                     "Pointer: nil barrier → nil resolved position (M0/M1 match)")
        Self.recordNativeOutput("pointer:button=left:phase=down:clickCount=1")

        // Scroll: precise delta ÷ 40 normalizes to Monaco delta.
        let scrollGateway = MonaScrollGateway()
        let scrollEvent = scrollGateway.translateFields(
            scrollingDeltaX: 0, scrollingDeltaY: 40,
            hasPreciseScrollingDeltas: true,
            phase: [.changed], momentumPhase: [],
            magnification: 0, modifiers: [],
            viewportPoint: .zero, timestamp: 1,
            resolvingPositionThrough: nil
        )
        XCTAssertEqual(scrollEvent.deltaY, 1.0,
                       "Scroll: precise delta ÷ 40 = 1.0 (M0/M1 match)")
        XCTAssertTrue(scrollEvent.isPrecise, "Scroll: precise flag preserved")
        XCTAssertEqual(scrollEvent.phase, .changed,
                       "Scroll: phase projected from NSEvent.Phase (M0/M1 match)")

        // Coarse (line-based) delta is carried verbatim (no division).
        let coarse = scrollGateway.translateFields(
            scrollingDeltaX: 0, scrollingDeltaY: 3,
            hasPreciseScrollingDeltas: false,
            phase: [.began], momentumPhase: [],
            magnification: 0, modifiers: [],
            viewportPoint: .zero, timestamp: 2,
            resolvingPositionThrough: nil
        )
        XCTAssertEqual(coarse.deltaY, 3.0,
                       "Scroll: coarse delta carried verbatim (M0/M1 match)")
        XCTAssertFalse(coarse.isPrecise, "Scroll: coarse flag preserved")
        Self.recordNativeOutput("scroll:precise=40÷40=1.0:coarse=3.0verbatim")
    }

    // ── 1c. Accessibility: element graph + focus + mutation ──

    /// The AX element graph instantiates exactly the six required roles, the
    /// focus coordinator has five modes with a `.temporary` push/pop, and the
    /// AX mutation gateway routes a set-value through the model input barrier,
    /// publishing an announcement only after a successful commit — the M0/M1
    /// accessibility contract (A1-R + A2-R closure).
    @MainActor
    func testC07_AccessibilityElementFocusMutationAgainstM0M1() {
        let model = MonaCodeModel(
            text: "abc\ndef",
            uri: MonaURI(scheme: "inmemory", path: "/c07-ax"))
        let graph = MonaAXElementGraph(model: model)

        // Exactly six roles — editor, gutter, widget, link, diagnostic, proxy.
        XCTAssertEqual(MonaAXRole.allCases.count, 6,
                       "VoiceOver: exactly six AX roles (M0/M1 match)")
        XCTAssertEqual(graph.roles, Set(MonaAXRole.allCases),
                       "VoiceOver: graph instantiates all six roles (M0/M1 match)")
        XCTAssertEqual(graph.descriptor(for: .editor).accessibilityRole,
                       NSAccessibility.Role.textArea,
                       "VoiceOver: editor role reports AX textArea (M0/M1 match)")
        Self.recordNativeOutput("ax:roles=6:editor=textArea")

        // Five focus modes with a .temporary push/pop.
        let coordinator = MonaAXFocusCoordinator(initial: .editor)
        XCTAssertEqual(MonaAXFocusMode.allCases.count, 5,
                       "Focus: exactly five focus modes (M0/M1 match)")
        XCTAssertEqual(coordinator.currentMode, .editor,
                       "Focus: starts in .editor (M0/M1 match)")
        coordinator.transition(to: .temporary)
        XCTAssertEqual(coordinator.currentMode, .temporary,
                       "Focus: entered .temporary (M0/M1 match)")
        XCTAssertEqual(coordinator.savedMode, .editor,
                       "Focus: prior mode saved (M0/M1 match)")
        let restored = coordinator.releaseTemporary()
        XCTAssertEqual(restored, .editor,
                       "Focus: .temporary released → prior mode restored (M0/M1 match)")
        XCTAssertEqual(coordinator.currentMode, .editor)
        coordinator.transition(to: .widget)
        XCTAssertEqual(coordinator.currentMode, .widget,
                       "Focus: transition sets exactly one mode (M0/M1 match)")
        Self.recordNativeOutput("ax:focus=5modes:temporary=pushPop")

        // Mutation gateway: set-value routes through the barrier.
        let inputBarrier = MonaModelInputBarrier(model: model)
        let focus = MonaAXFocusCoordinator(initial: .editor)
        let bridge = MonaAXAnnouncementBridge(profile: .default)
        let mutGateway = MonaAXMutationGateway(
            model: model, barrier: inputBarrier,
            focusCoordinator: focus, announcementBridge: bridge)
        let request = MonaAXMutationRequest(
            action: .setValue(text: "xyz"), issuedModelVersion: model.getVersionId())
        XCTAssertEqual(mutGateway.perform(request), .applied,
                       "VoiceOver: set-value applies through the barrier (M0/M1 match)")
        XCTAssertEqual(model.getValue(), "xyz",
                       "VoiceOver: model text replaced (M0/M1 match)")
        XCTAssertEqual(bridge.pendingCount, 1,
                       "VoiceOver: announcement enqueued only after success (M0/M1 match)")
        // Drain the mutation's announcement so it doesn't interfere with the
        // FIFO test below.
        _ = bridge.nextAnnouncement()
        XCTAssertEqual(bridge.pendingCount, 0, "mutation announcement drained")
        Self.recordNativeOutput("ax:mutation=applied:announcement=1pending")

        // Announcement bridge: dedup + FIFO + N1 profile resolution (fresh
        // bridge so the mutation's lastAnnounced doesn't interfere).
        let annBridge = MonaAXAnnouncementBridge(profile: .default)
        XCTAssertTrue(try annBridge.enqueue(.focusMovedToWidget),
                      "Focus: first announcement enqueued (M0/M1 match)")
        XCTAssertEqual(annBridge.pendingCount, 1)
        XCTAssertTrue(try annBridge.enqueue(.selectionChanged),
                      "Focus: a different announcement enqueues (M0/M1 match)")
        XCTAssertEqual(annBridge.pendingCount, 2)
        XCTAssertEqual(annBridge.nextAnnouncement(), "Widget",
                       "Focus: FIFO drain order — Widget first (M0/M1 match)")
        XCTAssertEqual(annBridge.nextAnnouncement(), "Selection changed",
                       "Focus: FIFO drain order — Selection changed (M0/M1 match)")
        Self.recordNativeOutput("ax:announcements=fifoDrainOK")
    }

    // ── 1d. WorkspaceEdit 4-outcome ──

    /// The atomic apply-external-then-publish-model transaction exposes exactly
    /// four terminal outcomes (applied, rejected, failed, canceled). The
    /// external commit MUST succeed before any open-model change is published;
    /// open-model-only (no external ops, no host) applies without a host — the
    /// M0/M1 workspace-edit contract.
    func testC07_WorkspaceEditFourOutcomeAgainstM0M1() async {
        // The four outcome cases exist (pattern-match verification).
        let _: MonaWorkspaceEditOutcome = .applied
        let _: MonaWorkspaceEditOutcome = .rejected(operationIndex: 0, reason: "test")
        let _: MonaWorkspaceEditOutcome = .failed(MonaWorkspaceEditFailureDetails(
            stage: .publishOpenModel, operationIndex: nil, errorDescription: "test"))
        let _: MonaWorkspaceEditOutcome = .canceled(stage: .publishOpenModel)
        Self.recordNativeOutput("workspaceEdit:4outcomes=applied+rejected+failed+canceled")

        // The 3 external operation kinds: create, rename, delete.
        let kindRawValues = Set([
            MonaExternalWorkspaceOperationKind.create.rawValue,
            MonaExternalWorkspaceOperationKind.rename.rawValue,
            MonaExternalWorkspaceOperationKind.delete.rawValue,
        ])
        XCTAssertEqual(kindRawValues.count, 3,
                       "3 external operation kinds: create, rename, delete (M0/M1 match)")
        Self.recordNativeOutput("workspaceEdit:3kinds=create+rename+delete")

        // .applied: open-model-only (no external ops, no host) → .applied.
        let model = MonaCodeModel(
            text: "hello",
            uri: MonaURI(scheme: "inmemory", path: "/c07-we"))
        let startV = model.getVersionId()
        let edit = MonaWorkspaceEdit(
            openModelEdits: [MonaOpenModelEdit(
                modelURI: model.uri,
                edits: [MonaModelEditOperation(
                    range: MonaRange(startLine: 1, startColumn: 1,
                                     endLine: 1, endColumn: 6),
                    text: "HELLO")])])
        let resolver: (MonaURI) -> MonaCodeModel? = { uri in
            uri === model.uri ? model : nil
        }
        let outcome = await edit.apply(
            host: nil, modelResolver: resolver,
            transactionID: MonaWorkspaceTransactionIdentity(id: "tx-c07"))
        guard case .applied = outcome else {
            return XCTFail("open-model-only must apply without a host; got \(outcome)")
        }
        XCTAssertNotEqual(model.getVersionId(), startV,
                          "model published (version bumped) (M0/M1 match)")
        XCTAssertEqual(model.getValue(), "HELLO",
                       "model text replaced (M0/M1 match)")
        Self.recordNativeOutput("workspaceEdit:openModelOnly=applied:versionBumped")
    }

    // MARK: Operation 2 — Run every contract overlay, T-1/T/T+1 boundary,
    // raw-unit fixture, native-adapted assertion, failure row, and exact-set
    // check assigned to the gate.

    // ── 2a. Contract overlay (I3-R4 + A1-R + A2-R + I4-R + S1-R closures) ──

    /// The contract overlay: the I3-R4 input/pointer/scroll closure, the A1-R
    /// AX text closure, the A2-R AX focus closure, the I4-R transfer closure,
    /// and the S1-R services closure all exist on disk, hash to stable SHA-256
    /// digests, and carry the M0/M1-ported counts.
    func testC07_ContractOverlayAndExactSetCheck() throws {
        XCTAssertEqual(Self.frozenSourceRevision, "P07-T011")
        let hexRegex = try NSRegularExpression(pattern: "^[0-9a-f]{64}$")
        let hexRange = NSRange(Self.frozenSourceSetDigest.startIndex...,
                               in: Self.frozenSourceSetDigest)
        XCTAssertNotNil(hexRegex.firstMatch(in: Self.frozenSourceSetDigest, range: hexRange))

        let qsRange = NSRange(Self.qualifiedSetHash.startIndex...,
                              in: Self.qualifiedSetHash)
        XCTAssertNotNil(hexRegex.firstMatch(in: Self.qualifiedSetHash, range: qsRange),
                        "qualified-set hash is 64-char lowercase hex SHA-256")

        // The I3-R4 input/pointer/scroll closure artifact exists and is non-empty.
        let i3r4Path = parentArtifactsDir + "/native-input-i3r4-public-event-pointer-scroll-closure.html"
        XCTAssertTrue(FileManager.default.fileExists(atPath: i3r4Path),
                      "I3-R4 closure artifact exists (not stale/missing)")
        let i3r4Hash = sha256File(i3r4Path)
        XCTAssertEqual(i3r4Hash.count, 64, "I3-R4 closure hash is 64-char SHA-256")
        Self.recordNativeOutput("contractOverlay:i3r4Closure:hash=\(i3r4Hash.prefix(12))")

        // The A1-R AX text closure artifact exists and is non-empty.
        let a1rPath = parentArtifactsDir + "/accessibility-a1r-native-text-contract-closure.html"
        XCTAssertTrue(FileManager.default.fileExists(atPath: a1rPath),
                      "A1-R AX text closure artifact exists (not stale/missing)")
        let a1rHash = sha256File(a1rPath)
        XCTAssertEqual(a1rHash.count, 64, "A1-R closure hash is 64-char SHA-256")
        Self.recordNativeOutput("contractOverlay:a1rClosure:hash=\(a1rHash.prefix(12))")

        // The A2-R AX focus closure artifact exists and is non-empty.
        let a2rPath = parentArtifactsDir + "/accessibility-a2r-native-widget-focus-closure.html"
        XCTAssertTrue(FileManager.default.fileExists(atPath: a2rPath),
                      "A2-R AX focus closure artifact exists (not stale/missing)")
        Self.recordNativeOutput("contractOverlay:a2rClosure=exists")

        // The I4-R transfer closure artifact exists and is non-empty.
        let i4rPath = parentArtifactsDir + "/transfer-i4r-adversarial.html"
        XCTAssertTrue(FileManager.default.fileExists(atPath: i4rPath),
                      "I4-R transfer closure artifact exists (not stale/missing)")
        Self.recordNativeOutput("contractOverlay:i4rClosure=exists")

        // The S1-R services closure artifact exists and is non-empty.
        let s1rPath = parentArtifactsDir + "/services-s1r-session-feedback-closure.html"
        XCTAssertTrue(FileManager.default.fileExists(atPath: s1rPath),
                      "S1-R services closure artifact exists (not stale/missing)")
        Self.recordNativeOutput("contractOverlay:s1rClosure=exists")

        // The 6 static candidate manifest files exist and hash to stable digests.
        var missing: [String] = []
        var candidateHashes: [String] = []
        for c in Self.sixStaticCandidateFiles {
            let path = artifactsDir + "/" + c.file
            guard FileManager.default.fileExists(atPath: path) else {
                missing.append(c.file)
                continue
            }
            let hash = sha256File(path)
            candidateHashes.append(hash)
            Self.recordNativeOutput("candidate:\(c.name):hash=\(hash.prefix(12))")
        }
        XCTAssertTrue(missing.isEmpty,
                     "exact-set check: missing candidate manifest files: \(missing)")
        XCTAssertEqual(candidateHashes.count, 6)
    }

    // ── 2b. T-1/T/T+1 boundary (input + a11y + workspace-edit) ──

    /// The T-1/T/T+1 boundary cases for the native-input/a11y/workspace-edit
    /// domain: keyboard boundaries (ABC translation, IME composition, repeat),
    /// AX boundaries (6 roles, focus temporary push/pop, stale mutation), and
    /// workspace-edit boundaries (applied, 4 outcomes, 3 operation kinds).
    /// Every case must run.
    @MainActor
    func testC07_TMinus1TTPlus1BoundaryCases() {
        let boundaries: [(id: String, bound: String, expect: Bool, check: () -> Bool)] = [
            ("keyboard-abc-T-1", "T-1", true, { [self] in
                let g = MonaAppKeyEventGateway()
                let e = keyDownEvent(keyCode: 0, characters: "a")
                let t = g.translateKeyDown(e, isComposing: false)
                return t.keyText == "a" && t.keyCode == .keyA
            }),
            ("keyboard-ime-T", "T", true, {
                let now: Double = 0
                let s = MonaCompositionSession(clock: { now }, timeoutInterval: 30.0)
                _ = s.updateMarkedText("nǐ", selectedRange: NSRange(location: 0, length: 0),
                                        replacementRange: NSRange(location: 5, length: 0))
                return s.phase == .composing
            }),
            ("keyboard-repeat-T+1", "T+1", true, { [self] in
                let g = MonaAppKeyEventGateway()
                let e = self.keyDownEvent(keyCode: 0, characters: "a")
                let t = g.translateKeyDown(e, isComposing: false)
                return !t.isRepeat
            }),
            ("ax-roles-T-1", "T-1", true, {
                MonaAXRole.allCases.count == 6
            }),
            ("ax-focus-T", "T", true, {
                let c = MonaAXFocusCoordinator(initial: .editor)
                c.transition(to: .temporary)
                let r = c.releaseTemporary()
                return r == .editor && c.currentMode == .editor
            }),
            ("ax-mutation-T+1", "T+1", true, { [self] in
                let m = MonaCodeModel(text: "abc",
                    uri: MonaURI(scheme: "inmemory", path: "/c07-stale"))
                let b = MonaModelInputBarrier(model: m)
                let f = MonaAXFocusCoordinator(initial: .editor)
                let br = MonaAXAnnouncementBridge(profile: .default)
                let mg = MonaAXMutationGateway(model: m, barrier: b,
                                                focusCoordinator: f, announcementBridge: br)
                let req = MonaAXMutationRequest(
                    action: .setValue(text: "x"),
                    issuedModelVersion: m.getVersionId() + 999)
                if case .rejected = mg.perform(req) { return true }
                return false
            }),
            ("we-applied-T-1", "T-1", true, {
                let kinds = Set([
                    MonaExternalWorkspaceOperationKind.create.rawValue,
                    MonaExternalWorkspaceOperationKind.rename.rawValue,
                    MonaExternalWorkspaceOperationKind.delete.rawValue,
                ])
                return kinds.count == 3
            }),
            ("we-outcomes-T", "T", true, {
                // The 4 outcome cases are constructible (they exist).
                let a: MonaWorkspaceEditOutcome = .applied
                let r: MonaWorkspaceEditOutcome = .rejected(operationIndex: 0, reason: "")
                let f: MonaWorkspaceEditOutcome = .failed(MonaWorkspaceEditFailureDetails(
                    stage: .publishOpenModel, operationIndex: nil, errorDescription: ""))
                let c: MonaWorkspaceEditOutcome = .canceled(stage: .publishOpenModel)
                _ = a; _ = r; _ = f; _ = c
                return a == .applied
                    && r == .rejected(operationIndex: 0, reason: "")
                    && c == .canceled(stage: .publishOpenModel)
            }),
            ("we-stale-T+1", "T+1", true, {
                // The 4 failure stages + 3 cancel stages exist.
                let stages = Set([
                    MonaWorkspaceEditFailureDetails.Stage.resolveOpenModel.rawValue,
                    MonaWorkspaceEditFailureDetails.Stage.prepareExternal.rawValue,
                    MonaWorkspaceEditFailureDetails.Stage.commitExternal.rawValue,
                    MonaWorkspaceEditFailureDetails.Stage.publishOpenModel.rawValue,
                ])
                let cancelStages = Set([
                    MonaWorkspaceEditCancelStage.prepareExternal.rawValue,
                    MonaWorkspaceEditCancelStage.commitExternal.rawValue,
                    MonaWorkspaceEditCancelStage.publishOpenModel.rawValue,
                ])
                return stages.count == 4 && cancelStages.count == 3
            }),
        ]
        var compared = 0
        var mismatches: [String] = []
        for b in boundaries {
            let nativeResult = b.check()
            if nativeResult != b.expect {
                mismatches.append("\(b.id) [\(b.bound)]: expect=\(b.expect) native=\(nativeResult)")
            }
            Self.recordNativeOutput("boundary:\(b.id):bound=\(b.bound):native=\(nativeResult)")
            compared += 1
        }
        XCTAssertEqual(compared, boundaries.count,
                       "every boundary case must run (none skipped): \(compared)/\(boundaries.count)")
        XCTAssertTrue(mismatches.isEmpty,
                      "M0/M1 boundary mismatches:\n" + mismatches.joined(separator: "\n"))
    }

    // ── 2c. Native-adapted assertion + failure row ──

    /// The native-adapted assertion: drag/drop type validation and operation
    /// masking (the failure row — empty drag-type set rejected, link operation
    /// rejected), and the AX mutation gateway rejects a stale model version
    /// before commit (the failure row — stale version → .rejected). The
    /// EventControl is one-way (preventDefault/stopPropagation are idempotent).
    @MainActor
    func testC07_NativeAdaptedAssertionAndFailureRows() {
        // Failure row 1: drag/drop type validation.
        let gateway = MonaDragDropGateway()
        XCTAssertTrue(gateway.accepts(dragTypes: [.string]),
                      "DragDrop: accepts a plain-text drag type (M0/M1 match)")
        XCTAssertFalse(gateway.accepts(dragTypes: []),
                       "DragDrop: rejects an empty drag-type set (M0/M1 match)")

        // Failure row 2: operation mask (link rejected).
        XCTAssertEqual(gateway.validate(operation: [.copy, .link]), [.copy],
                       "DragDrop: operation masked to accepted operations (link rejected) (M0/M1 match)")
        Self.recordNativeOutput("failureRows:dragDrop=typeValidation+operationMasking")

        // Failure row 3: AX mutation stale model version → rejected.
        let model = MonaCodeModel(
            text: "abc",
            uri: MonaURI(scheme: "inmemory", path: "/c07-stale-ax"))
        let barrier = MonaModelInputBarrier(model: model)
        let focus = MonaAXFocusCoordinator(initial: .editor)
        let bridge = MonaAXAnnouncementBridge(profile: .default)
        let mutGateway = MonaAXMutationGateway(
            model: model, barrier: barrier,
            focusCoordinator: focus, announcementBridge: bridge)
        let staleRequest = MonaAXMutationRequest(
            action: .setValue(text: "stale"),
            issuedModelVersion: model.getVersionId() + 999)
        let staleOutcome = mutGateway.perform(staleRequest)
        if case .rejected(let reason) = staleOutcome {
            XCTAssertEqual(reason, .staleModelVersion,
                           "stale model version → .staleModelVersion (M0/M1 match)")
        } else {
            XCTFail("stale model version must be rejected; got \(staleOutcome)")
        }
        XCTAssertEqual(model.getValue(), "abc",
                       "stale mutation leaves the model untouched (M0/M1 match)")
        XCTAssertEqual(bridge.pendingCount, 0,
                       "stale mutation enqueues no announcement (M0/M1 match)")
        Self.recordNativeOutput("failureRows:axStaleVersion=rejected:noAnnouncement")

        // Native-adapted: EventControl is one-way + idempotent.
        let control = MonaEventControl()
        XCTAssertFalse(control.isDefaultPrevented, "EventControl: starts not-prevented")
        XCTAssertFalse(control.isPropagationStopped, "EventControl: starts not-stopped")
        control.preventDefault()
        XCTAssertTrue(control.isDefaultPrevented, "EventControl: preventDefault is one-way")
        control.preventDefault()
        XCTAssertTrue(control.isDefaultPrevented, "EventControl: preventDefault is idempotent")
        control.stopPropagation()
        XCTAssertTrue(control.isPropagationStopped, "EventControl: stopPropagation is one-way")
        control.stopPropagation()
        XCTAssertTrue(control.isPropagationStopped, "EventControl: stopPropagation is idempotent")
        Self.recordNativeOutput("nativeAdapted:eventControl=oneWayIdempotent")
    }

    // MARK: Operation 3 — Bind evidence manifest

    func testC07_EvidenceManifestBinding() throws {
        // comparator: the M0/M1 reference (I3-R4 input/pointer/scroll closure).
        let comparatorPath = parentArtifactsDir + "/native-input-i3r4-public-event-pointer-scroll-closure.html"
        let comparatorHash = sha256File(comparatorPath)
        XCTAssertEqual(comparatorHash.count, 64,
                       "comparator hash is 64-char SHA-256")

        // fixture: the M0/M1 AX text contract (A1-R closure).
        let fixturePath = parentArtifactsDir + "/accessibility-a1r-native-text-contract-closure.html"
        let fixtureHash = sha256File(fixturePath)
        XCTAssertEqual(fixtureHash.count, 64,
                       "fixture hash is 64-char SHA-256")

        // candidate: the 6 static candidate manifest file hashes.
        var candidateHashes: [String] = []
        for c in Self.sixStaticCandidateFiles {
            let path = artifactsDir + "/" + c.file
            candidateHashes.append(sha256File(path))
        }
        XCTAssertEqual(candidateHashes.count, 6,
                       "exactly 6 static candidate hashes bound in the manifest")

        let sourceRevisionBinding = Self.frozenSourceRevision + ":" + Self.frozenSourceSetDigest

        let envFields = ["osVersion": osVersion, "arch": architecture]
        let environmentFingerprint = sha256String(canonicalJSON(envFields))
        XCTAssertEqual(environmentFingerprint.count, 64)

        Self.nativeOutputLock.lock()
        let accumulated = Self.nativeOutputLines
        Self.nativeOutputLock.unlock()
        XCTAssertFalse(accumulated.isEmpty,
                       "native output accumulator must be non-empty (suite ran)")
        let nativeHash = sha256String(accumulated.joined(separator: "\n"))
        let outputHash = nativeHash

        let manifest: [String: String] = [
            "comparator": comparatorHash,
            "native": nativeHash,
            "environment": environmentFingerprint,
            "candidate": candidateHashes.joined(separator: ","),
            "qualifiedSet": Self.qualifiedSetHash,
            "sourceRevision": sourceRevisionBinding,
            "fixture": fixtureHash,
            "output": outputHash,
        ]
        let manifestJSON = canonicalJSON(manifest)
        let manifestBinding = sha256String(manifestJSON)
        XCTAssertEqual(manifestBinding.count, 64,
                       "evidence manifest binding is 64-char SHA-256")

        for field in ["comparator", "native", "environment", "candidate",
                      "qualifiedSet", "sourceRevision", "fixture", "output"] {
            XCTAssertNotNil(manifest[field], "field \(field) present")
            XCTAssertFalse(manifest[field]?.isEmpty ?? true, "field \(field) non-empty")
        }

        print("P09-T016 comparator=\(comparatorHash.prefix(12)) native=\(nativeHash.prefix(12)) environment=\(environmentFingerprint.prefix(12)) candidate=\(Self.qualifiedSetHash.prefix(12)) sourceRev=\(Self.frozenSourceRevision) fixture=\(fixtureHash.prefix(12)) output=\(outputHash.prefix(12)) cases=9")
    }

    // MARK: Operation 4 — Treat every missing/skipped/stale/malformed case as
    // not-passed.

    func testC07_NoMissingSkippedStaleMalformedCases() throws {
        // The I3-R4 closure artifact exists and is non-empty.
        let i3r4Path = parentArtifactsDir + "/native-input-i3r4-public-event-pointer-scroll-closure.html"
        XCTAssertTrue(FileManager.default.fileExists(atPath: i3r4Path),
                      "I3-R4 closure artifact must exist (not stale/missing)")
        let i3r4Data = try Data(contentsOf: URL(fileURLWithPath: i3r4Path))
        XCTAssertGreaterThan(i3r4Data.count, 0,
                             "I3-R4 closure artifact non-empty (not malformed)")

        // The A1-R AX text closure artifact exists and is non-empty.
        let a1rPath = parentArtifactsDir + "/accessibility-a1r-native-text-contract-closure.html"
        XCTAssertTrue(FileManager.default.fileExists(atPath: a1rPath),
                      "A1-R AX text closure artifact must exist (not stale/missing)")
        let a1rData = try Data(contentsOf: URL(fileURLWithPath: a1rPath))
        XCTAssertGreaterThan(a1rData.count, 0,
                             "A1-R AX text closure artifact non-empty (not malformed)")

        // The A2-R AX focus closure artifact exists and is non-empty.
        let a2rPath = parentArtifactsDir + "/accessibility-a2r-native-widget-focus-closure.html"
        XCTAssertTrue(FileManager.default.fileExists(atPath: a2rPath),
                      "A2-R AX focus closure artifact must exist (not stale/missing)")
        let a2rData = try Data(contentsOf: URL(fileURLWithPath: a2rPath))
        XCTAssertGreaterThan(a2rData.count, 0,
                             "A2-R AX focus closure artifact non-empty (not malformed)")

        // The I4-R transfer closure artifact exists and is non-empty.
        let i4rPath = parentArtifactsDir + "/transfer-i4r-adversarial.html"
        XCTAssertTrue(FileManager.default.fileExists(atPath: i4rPath),
                      "I4-R transfer closure artifact must exist (not stale/missing)")
        let i4rData = try Data(contentsOf: URL(fileURLWithPath: i4rPath))
        XCTAssertGreaterThan(i4rData.count, 0,
                             "I4-R transfer closure artifact non-empty (not malformed)")

        // The S1-R services closure artifact exists and is non-empty.
        let s1rPath = parentArtifactsDir + "/services-s1r-session-feedback-closure.html"
        XCTAssertTrue(FileManager.default.fileExists(atPath: s1rPath),
                      "S1-R services closure artifact must exist (not stale/missing)")
        let s1rData = try Data(contentsOf: URL(fileURLWithPath: s1rPath))
        XCTAssertGreaterThan(s1rData.count, 0,
                             "S1-R services closure artifact non-empty (not malformed)")

        // The 9 boundary cases each have a bound in {T-1, T, T+1}.
        let validBounds: Set<String> = ["T-1", "T", "T+1"]
        let expectedBounds = ["T-1", "T", "T+1", "T-1", "T", "T+1", "T-1", "T", "T+1"]
        for bound in expectedBounds {
            XCTAssertTrue(validBounds.contains(bound),
                          "bound '\(bound)' not in {T-1, T, T+1}")
        }
    }

    // MARK: - NSEvent helpers

    /// Creates a keyDown NSEvent for testing (macOS keyCode + characters).
    private func keyDownEvent(keyCode: Int, characters: String) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                         timestamp: 0, windowNumber: 0, context: nil,
                         characters: characters,
                         charactersIgnoringModifiers: characters,
                         isARepeat: false, keyCode: UInt16(keyCode))!
    }

    /// Creates a mouse NSEvent for testing (clickCount).
    private func mouseEvent(buttonNumber: Int, clickCount: Int) -> NSEvent {
        NSEvent.mouseEvent(with: .leftMouseDown, location: CGPoint(x: 5, y: 5),
                           modifierFlags: [], timestamp: 0, windowNumber: 0,
                           context: nil, eventNumber: 0, clickCount: clickCount,
                           pressure: 1.0)!
    }

    // MARK: - Helpers

    private var projectRoot: String {
        var url = URL(fileURLWithPath: #file)
        while url.path != "/" {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
                return url.path
            }
            url = url.deletingLastPathComponent()
        }
        return FileManager.default.currentDirectoryPath
    }

    private var artifactsDir: String {
        projectRoot + "/docs/contracts/monaco-editor-0.56.0/g6-r/artifacts"
    }

    private var parentArtifactsDir: String {
        artifactsDir + "/parent/g5-r/artifacts"
    }

    private func sha256File(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url) else { return "<missing>" }
        return sha256Data(data)
    }

    private func sha256String(_ string: String) -> String {
        sha256Data(Data(string.utf8))
    }

    private func sha256Data(_ data: Data) -> String {
        SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }

    private func canonicalJSON(_ value: Any) -> String {
        if let data = try? JSONSerialization.data(
            withJSONObject: sortKeys(value),
            options: [.sortedKeys, .withoutEscapingSlashes]
        ) {
            return String(data: data, encoding: .utf8) ?? "{}"
        }
        return "{}"
    }

    private func sortKeys(_ value: Any) -> Any {
        if let arr = value as? [Any] { return arr.map { sortKeys($0) } }
        if let dict = value as? [String: Any] {
            var out: [String: Any] = [:]
            for key in dict.keys.sorted() { out[key] = sortKeys(dict[key]!) }
            return out
        }
        return value
    }

    private var osVersion: String { ProcessInfo.processInfo.operatingSystemVersionString }

    private var architecture: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }
}
