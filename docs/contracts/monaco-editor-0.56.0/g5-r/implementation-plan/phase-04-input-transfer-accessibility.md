# Phase 04: Input, transfer, accessibility, and embedding

Status: adopted plan content is not product implementation evidence. This phase is complete only after every task's future red/green commands and evidence assertions pass on the pinned qualification environment.

Authority: `global-g5r-authoritative-contract.html`, `monacode-g5r-authoritative-manifest.json`, and `monacode-g5r-implementation-plan-manifest.json`.

Phase dependency: Phase 03.

Task count: 16.

<!-- monacode-plan-task:{"id":"P04-T001","recordSha256":"1b043c704588f93d8d14228a8fdfdfadf0faaaed4c8c020259e9f3a00b3eb433"} -->
## P04-T001 — Define platform-neutral keyboard event semantics in Core

Contract: `I3-R.keyboardSemantics`, `I3-R4.publicEvents`, `F1-R5.nativeEventTypes`

Dependencies:
- `P03-T012`

Ownership selectors:
- `input:core-key-event`
- `input:key-dispatch-outcome`

Files to create:
- `Sources/MonaCode/Input/MonaKeyEvent.swift`
- `Sources/MonaCode/Input/MonaKeyDispatchOutcome.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Input/MonaKeyEventTests.swift`

Interfaces consumed:
- `MonaKeyCode`
- `MonaKeyMod`

Interfaces produced:
- `MonaKeyEvent`
- `MonaKeyDispatchOutcome`

Red verification:
- Run: `swift test --filter MonaKeyEventTests/testModifierAndRepeatMatrix`
  - Expected exit: `1`
  - Expected output includes: `KEY_EVENT_SEMANTIC_MISMATCH fixture=modifier-repeat`

Minimal implementation operations:
- `Represent key code, scan-independent key text, modifiers, repeat, composing state, and handled outcome as platform-neutral values.`
- `Separate prevent-default and stop-propagation decisions from platform dispatch.`
- `Preserve unknown key codes without collapsing them to a known case.`

Green verification:
- Run: `swift test --filter MonaKeyEventTests`
  - Expected exit: `0`
  - Expected output includes: `CORE_KEY_EVENTS matrices=36 unknownCodes=preserved`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-04/P04-T001.json`

Completion assertions:
- `Core input values contain no platform types.`
- `Modifier and repeat semantics match frozen traces.`
- `Dispatch outcomes remain explicit.`

Commit boundary:
- `Sources/MonaCode/Input/MonaKeyEvent.swift`
- `Sources/MonaCode/Input/MonaKeyDispatchOutcome.swift`
- `Tests/MonaCodeTests/Input/MonaKeyEventTests.swift`

<!-- monacode-plan-task:{"id":"P04-T002","recordSha256":"057de9b559ac983a203f79aded69ffc73197a93c17418061af0b3967bcc42fa8"} -->
## P04-T002 — Translate AppKit key events through one native gateway

Contract: `I3-R.AppKeyEventGateway`, `I3-R2.keyMapping`, `C07`

Dependencies:
- `P04-T001`

Ownership selectors:
- `input:appkit-key-gateway`

Files to create:
- `Sources/MonaCodeAppKit/Input/MonaAppKeyEventGateway.swift`
- `Sources/MonaCodeAppKit/Input/MonaMacKeyCodeMap.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Input/MonaAppKeyEventGatewayTests.swift`

Interfaces consumed:
- `MonaKeyEvent`
- `MonaKeyDispatchOutcome`

Interfaces produced:
- `MonaAppKeyEventGateway`
- `MonaMacKeyCodeMap`

Red verification:
- Run: `swift test --filter MonaAppKeyEventGatewayTests/testABCDeadKeyAndRepeatMatrix`
  - Expected exit: `1`
  - Expected output includes: `APP_KEY_GATEWAY_MISMATCH fixture=abc-dead-key`

Minimal implementation operations:
- `Translate hardware-independent AppKit event fields to Core key values exactly once.`
- `Preserve dead-key, repeat, function-key, keypad, modifier-only, and unrecognized cases.`
- `Apply Core dispatch outcomes at the native boundary after command resolution.`

Green verification:
- Run: `swift test --filter MonaAppKeyEventGatewayTests`
  - Expected exit: `0`
  - Expected output includes: `APP_KEY_GATEWAY ABC=pass keyMap=exact`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-04/P04-T002.json`

Completion assertions:
- `ABC key matrices match I3-R.`
- `Unknown keys survive translation.`
- `Native default handling follows Core outcomes.`

Commit boundary:
- `Sources/MonaCodeAppKit/Input/MonaAppKeyEventGateway.swift`
- `Sources/MonaCodeAppKit/Input/MonaMacKeyCodeMap.swift`
- `Tests/MonaCodeAppKitTests/Input/MonaAppKeyEventGatewayTests.swift`

<!-- monacode-plan-task:{"id":"P04-T003","recordSha256":"903a10a13a35022425288257b6588c91cbbf3a6e05825b3d2f19365a1b41a93e"} -->
## P04-T003 — Port keybinding resolution and chord state to Core

Contract: `I3-R2.keybindingResolver`, `F1-R3.keybindings`, `C04`

Dependencies:
- `P04-T001`
- `P01-T012`

Ownership selectors:
- `normativeLayer:native-input:I3-R2`
- `input:keybinding-resolver`
- `input:chord-state`

Files to create:
- `Sources/MonaCode/Input/MonaKeybinding.swift`
- `Sources/MonaCode/Input/MonaKeybindingResolver.swift`
- `Sources/MonaCode/Input/MonaChordState.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Input/MonaKeybindingResolverTests.swift`

Interfaces consumed:
- `MonaKeyEvent`
- `MonaGlobalLifetime`

Interfaces produced:
- `MonaKeybinding`
- `MonaKeybindingResolver`
- `MonaChordState`

Red verification:
- Run: `swift test --filter MonaKeybindingResolverTests/testChordWeightAndWhenOrder`
  - Expected exit: `1`
  - Expected output includes: `KEYBINDING_RESOLUTION_MISMATCH fixture=chord-weight-when`

Minimal implementation operations:
- `Port resolver ordering, weight, command removal, when-clause matching, chord entry, timeout, cancellation, and replay.`
- `Store chord state per editor with deterministic clock injection.`
- `Return a Core dispatch outcome without invoking platform APIs.`

Green verification:
- Run: `swift test --filter MonaKeybindingResolverTests`
  - Expected exit: `0`
  - Expected output includes: `KEYBINDING_RESOLVER registrations=379 order=exact`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-04/P04-T003.json`

Completion assertions:
- `All 379 frozen keybinding identities retain order.`
- `Chord state and timeout traces match.`
- `Core remains platform-neutral.`

Commit boundary:
- `Sources/MonaCode/Input/MonaKeybinding.swift`
- `Sources/MonaCode/Input/MonaKeybindingResolver.swift`
- `Sources/MonaCode/Input/MonaChordState.swift`
- `Tests/MonaCodeTests/Input/MonaKeybindingResolverTests.swift`

<!-- monacode-plan-task:{"id":"P04-T004","recordSha256":"63bb33e7de82969328a1daf53f42fbd9fd2ed3367e49df51a72ba1e55c783461"} -->
## P04-T004 — Implement marked-text input and composition arbitration

Contract: `I3-R`, `I3-R3.compositionArbitration`, `C07`, `P13`

Dependencies:
- `P04-T002`
- `P04-T003`
- `P03-T007`

Ownership selectors:
- `normativeLayer:native-input:I3-R`
- `input:text-client`
- `input:composition-arbitration`

Files to create:
- `Sources/MonaCodeAppKit/Input/MonaTextInputClient.swift`
- `Sources/MonaCodeAppKit/Input/MonaCompositionSession.swift`
- `Sources/MonaCodeAppKit/Input/MonaCompositionArbiter.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Input/MonaCompositionTests.swift`

Interfaces consumed:
- `MonaAppKeyEventGateway`
- `MonaKeybindingResolver`
- `MonaQueryGeometryBarrier`
- `MonaTransactionGateway`

Interfaces produced:
- `MonaTextInputClient`
- `MonaCompositionSession`
- `MonaCompositionArbiter`

Red verification:
- Run: `swift test --filter MonaCompositionTests/testPinyinMarkedTextBarrierTrace`
  - Expected exit: `1`
  - Expected output includes: `COMPOSITION_ARBITRATION_MISMATCH fixture=pinyin-marked-text`

Minimal implementation operations:
- `Implement marked text, selected range, replacement range, attributed substring, first-rect, and character-index queries.`
- `Arbitrate keybinding, command insertion, marked-text update, commit, cancel, fold, and disposal through one session state machine.`
- `Use the geometry barrier for every synchronous native geometry query.`
- `Preserve raw UTF-16 replacement ranges through ABC and Pinyin traces.`

Green verification:
- Run: `swift test --filter MonaCompositionTests`
  - Expected exit: `0`
  - Expected output includes: `COMPOSITION_GATE ABC=pass Pinyin=pass mixedGeneration=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-04/P04-T004.json`

Completion assertions:
- `ABC and Pinyin marked-text matrices pass.`
- `No keybinding mutates an active protected composition incorrectly.`
- `Composition geometry uses one complete generation.`

Commit boundary:
- `Sources/MonaCodeAppKit/Input/MonaTextInputClient.swift`
- `Sources/MonaCodeAppKit/Input/MonaCompositionSession.swift`
- `Sources/MonaCodeAppKit/Input/MonaCompositionArbiter.swift`
- `Tests/MonaCodeAppKitTests/Input/MonaCompositionTests.swift`

<!-- monacode-plan-task:{"id":"P04-T005","recordSha256":"2f29e86ec96d0fb7e40c52925901a99c576dc29cb698b3295a97512e7914dd16"} -->
## P04-T005 — Replicate multi-cursor input through ModelInputBarrier

Contract: `I3-R3.multiCursorComposition`, `R1.inputBarrier`, `P09`

Dependencies:
- `P04-T004`
- `P01-T010`

Ownership selectors:
- `normativeLayer:native-input:I3-R3`
- `input:model-input-barrier`

Files to create:
- `Sources/MonaCode/Input/MonaModelInputBarrier.swift`
- `Sources/MonaCode/Input/MonaMultiCursorInputPlan.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Input/MonaModelInputBarrierTests.swift`

Interfaces consumed:
- `MonaTransactionGateway`
- `MonaPublicationGate`
- `MonaSelection`

Interfaces produced:
- `MonaModelInputBarrier`
- `MonaMultiCursorInputPlan`

Red verification:
- Run: `swift test --filter MonaModelInputBarrierTests/testOverlappingCompositionReplication`
  - Expected exit: `1`
  - Expected output includes: `MODEL_INPUT_BARRIER_PARTIAL_COMMIT cursors=10000`

Minimal implementation operations:
- `Prepare primary and secondary cursor edits against one immutable model version.`
- `Apply overlap, merge, ordering, snippet, clipboard, and composition replication rules before commit.`
- `Publish all cursor edits and selections in one transaction or publish none.`

Green verification:
- Run: `swift test --filter MonaModelInputBarrierTests`
  - Expected exit: `0`
  - Expected output includes: `MODEL_INPUT_BARRIER cursorCounts=1,100,10000 partialCommits=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-04/P04-T005.json`

Completion assertions:
- `Multi-cursor traces match comparator ordering.`
- `Overlap resolution is deterministic.`
- `Failure and cancellation publish no partial cursor edits.`

Commit boundary:
- `Sources/MonaCode/Input/MonaModelInputBarrier.swift`
- `Sources/MonaCode/Input/MonaMultiCursorInputPlan.swift`
- `Tests/MonaCodeTests/Input/MonaModelInputBarrierTests.swift`

<!-- monacode-plan-task:{"id":"P04-T006","recordSha256":"31126b2a7a59852317995c8e72b1fd90f029cf73972b8703066c4092c80e9868"} -->
## P04-T006 — Project pointer, scroll, and context-menu events through AppKit

Contract: `I3-R4.pointerScrollMenu`, `F1-R5.nativeEventTypes`, `C07`

Dependencies:
- `P04-T002`
- `P03-T007`

Ownership selectors:
- `input:pointer`
- `input:scroll`
- `input:context-menu`

Files to create:
- `Sources/MonaCodeAppKit/Input/MonaPointerGateway.swift`
- `Sources/MonaCodeAppKit/Input/MonaScrollGateway.swift`
- `Sources/MonaCodeAppKit/Input/MonaContextMenuGateway.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Input/MonaPointerScrollMenuTests.swift`

Interfaces consumed:
- `MonaHitTester`
- `MonaScrollModel`

Interfaces produced:
- `MonaPointerGateway`
- `MonaScrollGateway`
- `MonaContextMenuGateway`

Red verification:
- Run: `swift test --filter MonaPointerScrollMenuTests/testPreciseScrollPhaseTrace`
  - Expected exit: `1`
  - Expected output includes: `POINTER_SCROLL_MISMATCH fixture=precise-scroll-phase`

Minimal implementation operations:
- `Translate button, click count, modifiers, pressure, precise scrolling, phases, momentum, magnification, and coordinates.`
- `Resolve targets through the geometry barrier before Core command dispatch.`
- `Build native context menus from the ordered Core menu model.`

Green verification:
- Run: `swift test --filter MonaPointerScrollMenuTests`
  - Expected exit: `0`
  - Expected output includes: `POINTER_SCROLL_MENU targetMatrices=42 phaseOrder=exact`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-04/P04-T006.json`

Completion assertions:
- `Pointer targets and scroll phases match native contract fixtures.`
- `Context menu order matches the registry.`
- `No stale geometry target is dispatched.`

Commit boundary:
- `Sources/MonaCodeAppKit/Input/MonaPointerGateway.swift`
- `Sources/MonaCodeAppKit/Input/MonaScrollGateway.swift`
- `Sources/MonaCodeAppKit/Input/MonaContextMenuGateway.swift`
- `Tests/MonaCodeAppKitTests/Input/MonaPointerScrollMenuTests.swift`

<!-- monacode-plan-task:{"id":"P04-T007","recordSha256":"0d0d738700a5a5a1d6239b10cce80f84c1982b0508739b1de9a8c814965c527a"} -->
## P04-T007 — Implement public EventControl and native event adaptation

Contract: `I3-R4.publicEventControl`, `F1-R5.eventAdaptation`, `C04`

Dependencies:
- `P04-T001`
- `P04-T006`

Ownership selectors:
- `normativeLayer:native-input:I3-R4`
- `input:event-control`

Files to create:
- `Sources/MonaCode/Input/MonaEventControl.swift`
- `Sources/MonaCode/Input/MonaPublicInputEvents.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeTests/Input/MonaEventControlTests.swift`

Interfaces consumed:
- `MonaKeyEvent`
- `MonaKeyDispatchOutcome`

Interfaces produced:
- `MonaEventControl`
- `MonaPublicKeyboardEvent`
- `MonaPublicMouseEvent`
- `MonaPublicScrollEvent`

Red verification:
- Run: `swift test --filter MonaEventControlTests/testPreventDefaultStopPropagationIndependence`
  - Expected exit: `1`
  - Expected output includes: `EVENT_CONTROL_MISMATCH fixture=independent-flags`

Minimal implementation operations:
- `Expose explicit prevent-default and stop-propagation state transitions.`
- `Project platform-neutral keyboard, mouse, and scroll fields into public native-adapted event values.`
- `Ensure public callbacks cannot mutate the underlying native event object.`

Green verification:
- Run: `swift test --filter MonaEventControlTests`
  - Expected exit: `0`
  - Expected output includes: `EVENT_CONTROL flags=independent publicEvents=3`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-04/P04-T007.json`

Completion assertions:
- `Public event controls preserve independent flags.`
- `Three native-adapted event surfaces are stable.`
- `Core public types contain no platform object.`

Commit boundary:
- `Sources/MonaCode/Input/MonaEventControl.swift`
- `Sources/MonaCode/Input/MonaPublicInputEvents.swift`
- `Tests/MonaCodeTests/Input/MonaEventControlTests.swift`

<!-- monacode-plan-task:{"id":"P04-T008","recordSha256":"cbde53c2065549e21ec3e97dec7e1babce4263cc148e220d4b40d0545999fbc4"} -->
## P04-T008 — Implement copy, cut, paste, and paste-edit pipelines

Contract: `I4-R.clipboard`, `L2-R.DocumentPasteEdit`, `C07`, `P09`

Dependencies:
- `P04-T005`

Ownership selectors:
- `transfer:pasteboard`
- `provider:DocumentPasteEdit`

Files to create:
- `Sources/MonaCodeAppKit/Transfer/MonaPasteboardGateway.swift`
- `Sources/MonaCodeAppKit/Transfer/MonaPasteEditPipeline.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Transfer/MonaPasteboardTests.swift`

Interfaces consumed:
- `MonaModelInputBarrier`
- `MonaAsyncValidityTicket`

Interfaces produced:
- `MonaPasteboardGateway`
- `MonaPasteEditPipeline`

Red verification:
- Run: `swift test --filter MonaPasteboardTests/testMultiCursorPasteSpreadAndRollback`
  - Expected exit: `1`
  - Expected output includes: `PASTE_TRANSACTION_PARTIAL_COMMIT cursor=99`

Minimal implementation operations:
- `Read and write the exact retained plain-text, rich-text, and editor metadata representations.`
- `Run direct paste-edit providers in deterministic order under cancellation and validity tickets.`
- `Commit cut and multi-cursor paste through the model input barrier.`

Green verification:
- Run: `swift test --filter MonaPasteboardTests`
  - Expected exit: `0`
  - Expected output includes: `PASTEBOARD copy=pass cut=pass paste=pass partialCommits=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-04/P04-T008.json`

Completion assertions:
- `Copy/cut/paste matrices match I4-R.`
- `Provider cancellation has no side effects.`
- `Clipboard spreading preserves cursor order.`

Commit boundary:
- `Sources/MonaCodeAppKit/Transfer/MonaPasteboardGateway.swift`
- `Sources/MonaCodeAppKit/Transfer/MonaPasteEditPipeline.swift`
- `Tests/MonaCodeAppKitTests/Transfer/MonaPasteboardTests.swift`

<!-- monacode-plan-task:{"id":"P04-T009","recordSha256":"d0b6f7c8721301557642f37c0e5eb076acc7d2e18ca75d583193bb1eeed5b248"} -->
## P04-T009 — Implement drag, drop, and macOS Services transfer

Contract: `I4-R.dragDropServices`, `L2-R.DocumentDropEdit`, `C07`

Dependencies:
- `P04-T008`
- `P04-T006`

Ownership selectors:
- `normativeLayer:clipboard-drag-drop-services:I4-R`
- `transfer:drag-drop-services`

Files to create:
- `Sources/MonaCodeAppKit/Transfer/MonaDragDropGateway.swift`
- `Sources/MonaCodeAppKit/Transfer/MonaServicesGateway.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Transfer/MonaDragDropServicesTests.swift`

Interfaces consumed:
- `MonaPasteEditPipeline`
- `MonaHitTester`
- `MonaModelInputBarrier`

Interfaces produced:
- `MonaDragDropGateway`
- `MonaServicesGateway`

Red verification:
- Run: `swift test --filter MonaDragDropServicesTests/testStaleDropLocationIsRejected`
  - Expected exit: `1`
  - Expected output includes: `DROP_VALIDITY_REJECTED expectedGeneration=4 actualGeneration=3`

Minimal implementation operations:
- `Validate drag types, operation masks, drop geometry, direct drop-edit providers, and transfer payloads before commit.`
- `Map macOS Services read and write selection operations to the same transfer pipeline.`
- `Reject stale drop geometry and dispose provider lists exactly once.`

Green verification:
- Run: `swift test --filter MonaDragDropServicesTests`
  - Expected exit: `0`
  - Expected output includes: `DRAG_DROP_SERVICES matrices=28 staleDrops=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-04/P04-T009.json`

Completion assertions:
- `Drag/drop and Services traces pass.`
- `Stale geometry never mutates the model.`
- `All transfers use one transactional boundary.`

Commit boundary:
- `Sources/MonaCodeAppKit/Transfer/MonaDragDropGateway.swift`
- `Sources/MonaCodeAppKit/Transfer/MonaServicesGateway.swift`
- `Tests/MonaCodeAppKitTests/Transfer/MonaDragDropServicesTests.swift`

<!-- monacode-plan-task:{"id":"P04-T010","recordSha256":"cb55cf7de62af715b98976f036dc18a837e04b2bab881d369b82ece4bc0a7c22"} -->
## P04-T010 — Expose the raw UTF-16 native text accessibility surface

Contract: `A1-R`, `A1-R2.textSelectors`, `C07`, `P13`

Dependencies:
- `P04-T004`
- `P03-T007`

Ownership selectors:
- `normativeLayer:accessibility:A1-R`
- `accessibility:text-area`

Files to create:
- `Sources/MonaCodeAppKit/Accessibility/MonaAXTextArea.swift`
- `Sources/MonaCodeAppKit/Accessibility/MonaAXTextRangeMapper.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Accessibility/MonaAXTextAreaTests.swift`

Interfaces consumed:
- `MonaCodeModel`
- `MonaSelection`
- `MonaQueryGeometryBarrier`

Interfaces produced:
- `MonaAXTextArea`
- `MonaAXTextRangeMapper`

Red verification:
- Run: `swift test --filter MonaAXTextAreaTests/testIsolatedSurrogateRangeRoundTrip`
  - Expected exit: `1`
  - Expected output includes: `AX_RAW_UTF16_ROUNDTRIP_MISMATCH range=7:1`

Minimal implementation operations:
- `Implement the frozen native text selectors for value, selection, visible range, attributed substring, range-for-position, bounds-for-range, and line mapping.`
- `Convert between accessibility integer ranges and raw model UTF-16 offsets without repair.`
- `Route geometry queries through the complete-generation barrier.`

Green verification:
- Run: `swift test --filter MonaAXTextAreaTests`
  - Expected exit: `0`
  - Expected output includes: `AX_TEXT_SURFACE selectors=closed rawUTF16=pass`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-04/P04-T010.json`

Completion assertions:
- `Every required text selector exists.`
- `Isolated-surrogate ranges round-trip.`
- `Large full-document queries remain bounded by the contract.`

Commit boundary:
- `Sources/MonaCodeAppKit/Accessibility/MonaAXTextArea.swift`
- `Sources/MonaCodeAppKit/Accessibility/MonaAXTextRangeMapper.swift`
- `Tests/MonaCodeAppKitTests/Accessibility/MonaAXTextAreaTests.swift`

<!-- monacode-plan-task:{"id":"P04-T011","recordSha256":"af53bd520141b5c28ccc489eab8e4871814bdf3b476320de51e8875b7ed4a3a5"} -->
## P04-T011 — Implement accessibility controls, proxies, links, diagnostics, and actions

Contract: `A1-R2.selectorAttributeActionClosure`, `A2-R2.widgetClosure`, `C07`

Dependencies:
- `P04-T010`
- `P04-T006`

Ownership selectors:
- `normativeLayer:accessibility:A1-R2`
- `machineArtifact:A2-R2-accessibility`

Files to create:
- `Sources/MonaCodeAppKit/Accessibility/MonaAXElementGraph.swift`
- `Sources/MonaCodeAppKit/Accessibility/MonaAXWidgetProxy.swift`
- `Sources/MonaCodeAppKit/Accessibility/MonaAXDiagnosticElement.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Accessibility/MonaAXElementGraphTests.swift`

Interfaces consumed:
- `MonaAXTextArea`
- `MonaHitTester`

Interfaces produced:
- `MonaAXElementGraph`
- `MonaAXWidgetProxy`
- `MonaAXDiagnosticElement`

Red verification:
- Run: `swift test --filter MonaAXElementGraphTests/testSelectorAttributeActionManifest`
  - Expected exit: `1`
  - Expected output includes: `AX_SURFACE_MISSING selector=accessibilityPerformPress`

Minimal implementation operations:
- `Instantiate exactly the required editor, gutter, widget, link, diagnostic, and proxy roles.`
- `Expose the frozen selector, attribute, parameterized-attribute, and action sets per role.`
- `Preserve stable element identity across viewport recycling while semantic ownership remains unchanged.`

Green verification:
- Run: `swift test --filter MonaAXElementGraphTests`
  - Expected exit: `0`
  - Expected output includes: `AX_ELEMENT_GRAPH roles=exact selectors=exact actions=exact`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-04/P04-T011.json`

Completion assertions:
- `A1-R2 and A2-R2 identity sets match.`
- `Recycled views do not change semantic element identity.`
- `Unsupported actions are absent rather than inert.`

Commit boundary:
- `Sources/MonaCodeAppKit/Accessibility/MonaAXElementGraph.swift`
- `Sources/MonaCodeAppKit/Accessibility/MonaAXWidgetProxy.swift`
- `Sources/MonaCodeAppKit/Accessibility/MonaAXDiagnosticElement.swift`
- `Tests/MonaCodeAppKitTests/Accessibility/MonaAXElementGraphTests.swift`

<!-- monacode-plan-task:{"id":"P04-T012","recordSha256":"6c2966eaad9de81c7da1d60877e697567d0682f6e052c9abbe9ede896709be23"} -->
## P04-T012 — Implement focus modes and the localized announcement bridge

Contract: `A2-R2.focusModes`, `N1-R.announcements`, `S1-R.feedback`, `C07`

Dependencies:
- `P04-T011`
- `P04-T003`

Ownership selectors:
- `normativeLayer:accessibility:A2-R2`
- `accessibility:focus`
- `accessibility:announcements`

Files to create:
- `Sources/MonaCodeAppKit/Accessibility/MonaAXFocusCoordinator.swift`
- `Sources/MonaCodeAppKit/Accessibility/MonaAXAnnouncementBridge.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Accessibility/MonaAXFocusAnnouncementTests.swift`

Interfaces consumed:
- `MonaAXElementGraph`
- `MonaChordState`
- `MonaCodeEnvironment`

Interfaces produced:
- `MonaAXFocusCoordinator`
- `MonaAXAnnouncementBridge`

Red verification:
- Run: `swift test --filter MonaAXFocusAnnouncementTests/testFocusModeTransitionOrder`
  - Expected exit: `1`
  - Expected output includes: `AX_FOCUS_ORDER_MISMATCH transition=widget-to-editor`

Minimal implementation operations:
- `Implement editor, widget, accessibility-optimized, tab-focus, and temporary focus transitions as one state machine.`
- `Deduplicate and serialize announcements without audio or unsupported notification UI.`
- `Resolve announcement text through the explicit N1 localization profile.`

Green verification:
- Run: `swift test --filter MonaAXFocusAnnouncementTests`
  - Expected exit: `0`
  - Expected output includes: `AX_FOCUS_ANNOUNCEMENT focusModes=exact duplicates=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-04/P04-T012.json`

Completion assertions:
- `Focus transition matrices match A2-R2.`
- `Announcements use explicit localized messages.`
- `No prohibited audio or notification surface is introduced.`

Commit boundary:
- `Sources/MonaCodeAppKit/Accessibility/MonaAXFocusCoordinator.swift`
- `Sources/MonaCodeAppKit/Accessibility/MonaAXAnnouncementBridge.swift`
- `Tests/MonaCodeAppKitTests/Accessibility/MonaAXFocusAnnouncementTests.swift`

<!-- monacode-plan-task:{"id":"P04-T013","recordSha256":"448863f224f4e3b8a25740e2fa40287b672e97d4611719764c5ac1f7e0851587"} -->
## P04-T013 — Route accessibility setters through ModelInputBarrier

Contract: `A1-R2.setters`, `R1.transactionRecovery`, `C07`

Dependencies:
- `P04-T005`
- `P04-T010`
- `P04-T012`

Ownership selectors:
- `accessibility:model-input-barrier`

Files to create:
- `Sources/MonaCodeAppKit/Accessibility/MonaAXMutationGateway.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Accessibility/MonaAXMutationGatewayTests.swift`

Interfaces consumed:
- `MonaAXTextArea`
- `MonaModelInputBarrier`
- `MonaAXFocusCoordinator`

Interfaces produced:
- `MonaAXMutationGateway`

Red verification:
- Run: `swift test --filter MonaAXMutationGatewayTests/testSetValueFailureRollsBack`
  - Expected exit: `1`
  - Expected output includes: `AX_MUTATION_PARTIAL_COMMIT selector=setValue`

Minimal implementation operations:
- `Translate set-value, set-selection, increment, decrement, press, and custom actions into Core input plans.`
- `Validate focus, editability, model version, range, and owner generation before commit.`
- `Publish accessibility notifications only after transaction success.`

Green verification:
- Run: `swift test --filter MonaAXMutationGatewayTests`
  - Expected exit: `0`
  - Expected output includes: `AX_MUTATION_GATEWAY actions=closed partialCommits=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-04/P04-T013.json`

Completion assertions:
- `Every mutating accessibility action uses the model barrier.`
- `Failure emits no success notification.`
- `Read-only and stale mutations fail explicitly.`

Commit boundary:
- `Sources/MonaCodeAppKit/Accessibility/MonaAXMutationGateway.swift`
- `Tests/MonaCodeAppKitTests/Accessibility/MonaAXMutationGatewayTests.swift`

<!-- monacode-plan-task:{"id":"P04-T014","recordSha256":"7b86dcc53babd742743b1df1b000fb7d8502101428beb6bff9a066386e1ea8c5"} -->
## P04-T014 — Deliver MonaCodeEditorView as the AppKit editor boundary

Contract: `H1-R.editorView`, `G5-R.deliveryScope.requiredViews`, `C09`

Dependencies:
- `P04-T006`
- `P04-T009`
- `P04-T013`
- `P03-T012`

Ownership selectors:
- `public-view:MonaCodeEditorView`

Files to create:
- `Sources/MonaCodeAppKit/Views/MonaCodeEditorView.swift`
- `Sources/MonaCodeAppKit/Views/MonaEditorAttachment.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Views/MonaCodeEditorViewLifecycleTests.swift`

Interfaces consumed:
- `MonaCodeModel`
- `MonaCoreGraphicsRenderer`
- `ConditionalMonaMetalRenderer`
- `MonaTextInputClient`
- `MonaAXElementGraph`

Interfaces produced:
- `MonaCodeEditorView`
- `MonaEditorAttachment`

Red verification:
- Run: `swift test --filter MonaCodeEditorViewLifecycleTests/testAttachDetachDisposeBaseline`
  - Expected exit: `1`
  - Expected output includes: `EDITOR_VIEW_LIFETIME_LEAK cycle=1000`

Minimal implementation operations:
- `Compose model attachment, projection, renderer branch, input, transfer, accessibility, widgets, and lifetime ownership in one native view.`
- `Keep model lifetime independent from view attachment and detach all callbacks before disposal.`
- `Expose only the contract-owned editor view surface.`

Green verification:
- Run: `swift test --filter MonaCodeEditorViewLifecycleTests`
  - Expected exit: `0`
  - Expected output includes: `MONACODE_EDITOR_VIEW cycles=1000 baselineReturn=pass`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-04/P04-T014.json`

Completion assertions:
- `The required AppKit editor view exists.`
- `Attach/detach/dispose returns to warm baseline.`
- `No hidden global owner is created.`

Commit boundary:
- `Sources/MonaCodeAppKit/Views/MonaCodeEditorView.swift`
- `Sources/MonaCodeAppKit/Views/MonaEditorAttachment.swift`
- `Tests/MonaCodeAppKitTests/Views/MonaCodeEditorViewLifecycleTests.swift`

<!-- monacode-plan-task:{"id":"P04-T015","recordSha256":"2fe5326bffe7b5b93c659df74a8a9819917b281f271d669ab6fcff1f5ce69ddd"} -->
## P04-T015 — Deliver MonaCodeEditor and MonaSwiftUIEditorController lifecycle wrappers

Contract: `H1-R.swiftUIBoundary`, `G5-R.deliveryScope.requiredSwiftUITypes`, `C09`

Dependencies:
- `P04-T014`

Ownership selectors:
- `public-swiftui:MonaCodeEditor`
- `public-swiftui:MonaSwiftUIEditorController`

Files to create:
- `Sources/MonaCodeSwiftUI/MonaCodeEditor.swift`
- `Sources/MonaCodeSwiftUI/MonaSwiftUIEditorController.swift`

Files to modify:
- None.

Test files:
- `Tests/MonaCodeAppKitTests/Views/MonaCodeEditorSwiftUILifecycleTests.swift`

Interfaces consumed:
- `MonaCodeEditorView`
- `MonaEditorAttachment`

Interfaces produced:
- `MonaCodeEditor`
- `MonaSwiftUIEditorController`

Red verification:
- Run: `swift test --filter MonaCodeEditorSwiftUILifecycleTests/testUpdateDoesNotRecreateModel`
  - Expected exit: `1`
  - Expected output includes: `SWIFTUI_LIFECYCLE_IDENTITY_DRIFT update=2`

Minimal implementation operations:
- `Wrap the AppKit view with stable identity and explicit controller ownership.`
- `Map SwiftUI updates to declared option, model, and focus changes only.`
- `Keep text semantics, rendering, input, provider execution, and command logic outside the wrapper.`

Green verification:
- Run: `swift test --filter MonaCodeEditorSwiftUILifecycleTests`
  - Expected exit: `0`
  - Expected output includes: `SWIFTUI_EDITOR_WRAPPER updates=100 identityStable=pass`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-04/P04-T015.json`

Completion assertions:
- `Both required SwiftUI editor types exist.`
- `Updates preserve model and view identity.`
- `Wrapper behavior remains lifecycle-only.`

Commit boundary:
- `Sources/MonaCodeSwiftUI/MonaCodeEditor.swift`
- `Sources/MonaCodeSwiftUI/MonaSwiftUIEditorController.swift`
- `Tests/MonaCodeAppKitTests/Views/MonaCodeEditorSwiftUILifecycleTests.swift`

<!-- monacode-plan-task:{"id":"P04-T016","recordSha256":"dbe9e720a7b492b0613d58b926627fd8b2959c2d518e04378b31790b07a1a01a"} -->
## P04-T016 — Close native input, transfer, accessibility, and editor embedding

Contract: `I3-R`, `I3-R2`, `I3-R3`, `I3-R4`, `I4-R`, `A1-R`, `A1-R2`, `A2-R2`, `C07`

Dependencies:
- `P04-T007`
- `P04-T009`
- `P04-T013`
- `P04-T015`

Ownership selectors:
- `phase-gate:04`

Files to create:
- None.

Files to modify:
- None.

Test files:
- `Tests/ConformanceAndFailureInjection/Phase04NativeBoundaryConformanceTests.swift`

Interfaces consumed:
- `MonaCodeEditorView`
- `MonaCodeEditor`
- `MonaTextInputClient`
- `MonaPasteboardGateway`
- `MonaDragDropGateway`
- `MonaAXMutationGateway`

Interfaces produced:
- `Phase04NativeBoundaryGate`

Red verification:
- Run: `swift test --filter Phase04NativeBoundaryConformanceTests/testSeededCompositionReentry`
  - Expected exit: `1`
  - Expected output includes: `PHASE04_NATIVE_GATE_FAILED fixture=composition-reentry`

Minimal implementation operations:
- `Run ABC, Pinyin, chord, multi-cursor, pointer, scroll, menu, clipboard, drag/drop, Services, VoiceOver, focus, and lifecycle matrices.`
- `Inject reentry, stale geometry, cancellation, disposal, read-only, provider, and allocation failures.`
- `Verify Core source remains free of AppKit-owned types and every mutation uses a declared gateway.`

Green verification:
- Run: `swift test --filter Phase04NativeBoundaryConformanceTests`
  - Expected exit: `0`
  - Expected output includes: `PHASE04_NATIVE_GATE C07=pass coreBoundary=pass partialCommits=0`

Evidence:
- `artifacts/acceptance-evidence/g5-r/phase-04/P04-T016.json`

Completion assertions:
- `C07 prerequisites pass for editor scope.`
- `Core and AppKit boundaries remain exact.`
- `No failure path publishes partial input state.`

Commit boundary:
- `Tests/ConformanceAndFailureInjection/Phase04NativeBoundaryConformanceTests.swift`
