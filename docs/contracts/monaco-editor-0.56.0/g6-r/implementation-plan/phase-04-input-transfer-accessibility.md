<!-- G6-R-PHASE:04 -->

# Phase 04 — Input, transfer, accessibility, and embedding

- Phase: `04`
- Title: Input, transfer, accessibility, and embedding
- Document: `implementation-plan/phase-04-input-transfer-accessibility.md`
- Dependencies: `03` 
- Tasks: 16

## Tasks

<!-- G6-R-TASK:P04-T001:c571936cc5dcf8a917b0778b80157a423a8708384bddc81f93453297521cbb9b -->

### P04-T001 — Define platform-neutral keyboard event semantics in Core

- Record SHA-256: `c571936cc5dcf8a917b0778b80157a423a8708384bddc81f93453297521cbb9b`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P03-T012` 
- Test contract cases: 1
- Red-scaffold rows: 2
- Source acquisitions: 0
- Product commit message: `monacode: complete P04-T001`
- Evidence commit message: `evidence(monacode): complete P04-T001`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-04/P04-T001.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Input/MonaKeyEventTests.swift`

### Stage `red`

- verification-command: `P04-T001.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Represent key code, scan-independent key text, modifiers, repeat, composing state, and handled outcome as platform-neutral values.`
- implementation-operation: `Separate prevent-default and stop-propagation decisions from platform dispatch.`
- implementation-operation: `Preserve unknown key codes without collapsing them to a known case.`

### Stage `green`

- verification-command: `P04-T001.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Input/MonaKeyEvent.swift
  - Sources/MonaCode/Input/MonaKeyDispatchOutcome.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Input/MonaKeyEventTests.swift

<!-- G6-R-TASK:P04-T002:9fb90482824d87100d123ce1984da42d7e2286ec700f8db7c5b60747ddc14253 -->

### P04-T002 — Translate AppKit key events through one native gateway

- Record SHA-256: `9fb90482824d87100d123ce1984da42d7e2286ec700f8db7c5b60747ddc14253`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P04-T001` 
- Test contract cases: 1
- Red-scaffold rows: 2
- Source acquisitions: 0
- Product commit message: `monacode: complete P04-T002`
- Evidence commit message: `evidence(monacode): complete P04-T002`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-04/P04-T002.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Input/MonaAppKeyEventGatewayTests.swift`

### Stage `red`

- verification-command: `P04-T002.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Translate hardware-independent AppKit event fields to Core key values exactly once.`
- implementation-operation: `Preserve dead-key, repeat, function-key, keypad, modifier-only, and unrecognized cases.`
- implementation-operation: `Apply Core dispatch outcomes at the native boundary after command resolution.`

### Stage `green`

- verification-command: `P04-T002.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Input/MonaAppKeyEventGateway.swift
  - Sources/MonaCodeAppKit/Input/MonaMacKeyCodeMap.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Input/MonaAppKeyEventGatewayTests.swift

<!-- G6-R-TASK:P04-T003:def4cda8d55a3b4f14506b572e986593f9535187e2f3542a57c4b7f1310070eb -->

### P04-T003 — Port keybinding resolution and chord state to Core

- Record SHA-256: `def4cda8d55a3b4f14506b572e986593f9535187e2f3542a57c4b7f1310070eb`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P01-T012`, `P04-T001` 
- Test contract cases: 1
- Red-scaffold rows: 3
- Source acquisitions: 0
- Product commit message: `monacode: complete P04-T003`
- Evidence commit message: `evidence(monacode): complete P04-T003`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-04/P04-T003.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Input/MonaKeybindingResolverTests.swift`

### Stage `red`

- verification-command: `P04-T003.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Port resolver ordering, weight, command removal, when-clause matching, chord entry, timeout, cancellation, and replay.`
- implementation-operation: `Store chord state per editor with deterministic clock injection.`
- implementation-operation: `Return a Core dispatch outcome without invoking platform APIs.`

### Stage `green`

- verification-command: `P04-T003.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Input/MonaKeybinding.swift
  - Sources/MonaCode/Input/MonaKeybindingResolver.swift
  - Sources/MonaCode/Input/MonaChordState.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Input/MonaKeybindingResolverTests.swift

<!-- G6-R-TASK:P04-T004:4c2a3a31b88e4963550e437fbf529e3b6d6aa91a70021eeb7d4ca1ab6d6aa165 -->

### P04-T004 — Implement marked-text input and composition arbitration

- Record SHA-256: `4c2a3a31b88e4963550e437fbf529e3b6d6aa91a70021eeb7d4ca1ab6d6aa165`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P03-T007`, `P04-T002`, `P04-T003` 
- Test contract cases: 1
- Red-scaffold rows: 3
- Source acquisitions: 0
- Product commit message: `monacode: complete P04-T004`
- Evidence commit message: `evidence(monacode): complete P04-T004`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-04/P04-T004.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Input/MonaCompositionTests.swift`

### Stage `red`

- verification-command: `P04-T004.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement marked text, selected range, replacement range, attributed substring, first-rect, and character-index queries.`
- implementation-operation: `Arbitrate keybinding, command insertion, marked-text update, commit, cancel, fold, and disposal through one session state machine.`
- implementation-operation: `Use the geometry barrier for every synchronous native geometry query.`
- implementation-operation: `Preserve raw UTF-16 replacement ranges through ABC and Pinyin traces.`

### Stage `green`

- verification-command: `P04-T004.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Input/MonaTextInputClient.swift
  - Sources/MonaCodeAppKit/Input/MonaCompositionSession.swift
  - Sources/MonaCodeAppKit/Input/MonaCompositionArbiter.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Input/MonaCompositionTests.swift

<!-- G6-R-TASK:P04-T005:64e109672cc9c97cb5873d74312d5a283afdb7abce1bab2682ffe08250a1521a -->

### P04-T005 — Replicate multi-cursor input through ModelInputBarrier

- Record SHA-256: `64e109672cc9c97cb5873d74312d5a283afdb7abce1bab2682ffe08250a1521a`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P01-T010`, `P04-T004` 
- Test contract cases: 1
- Red-scaffold rows: 2
- Source acquisitions: 0
- Product commit message: `monacode: complete P04-T005`
- Evidence commit message: `evidence(monacode): complete P04-T005`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-04/P04-T005.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Input/MonaModelInputBarrierTests.swift`

### Stage `red`

- verification-command: `P04-T005.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Prepare primary and secondary cursor edits against one immutable model version.`
- implementation-operation: `Apply overlap, merge, ordering, snippet, clipboard, and composition replication rules before commit.`
- implementation-operation: `Publish all cursor edits and selections in one transaction or publish none.`

### Stage `green`

- verification-command: `P04-T005.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Input/MonaModelInputBarrier.swift
  - Sources/MonaCode/Input/MonaMultiCursorInputPlan.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Input/MonaModelInputBarrierTests.swift

<!-- G6-R-TASK:P04-T006:1d70c7a582ce3643b4a2fc841e29dcf9879218b04d88301c56d09f49e3f9792f -->

### P04-T006 — Project pointer, scroll, and context-menu events through AppKit

- Record SHA-256: `1d70c7a582ce3643b4a2fc841e29dcf9879218b04d88301c56d09f49e3f9792f`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P03-T007`, `P04-T002` 
- Test contract cases: 1
- Red-scaffold rows: 3
- Source acquisitions: 0
- Product commit message: `monacode: complete P04-T006`
- Evidence commit message: `evidence(monacode): complete P04-T006`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-04/P04-T006.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Input/MonaPointerScrollMenuTests.swift`

### Stage `red`

- verification-command: `P04-T006.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Translate button, click count, modifiers, pressure, precise scrolling, phases, momentum, magnification, and coordinates.`
- implementation-operation: `Resolve targets through the geometry barrier before Core command dispatch.`
- implementation-operation: `Build native context menus from the ordered Core menu model.`

### Stage `green`

- verification-command: `P04-T006.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Input/MonaPointerGateway.swift
  - Sources/MonaCodeAppKit/Input/MonaScrollGateway.swift
  - Sources/MonaCodeAppKit/Input/MonaContextMenuGateway.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Input/MonaPointerScrollMenuTests.swift

<!-- G6-R-TASK:P04-T007:c0fb0f4deef26ecb283f1ffc2f25b1a91ba3b321ea5f9107736266d57d7e482c -->

### P04-T007 — Implement public EventControl and native event adaptation

- Record SHA-256: `c0fb0f4deef26ecb283f1ffc2f25b1a91ba3b321ea5f9107736266d57d7e482c`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P04-T001`, `P04-T006` 
- Test contract cases: 1
- Red-scaffold rows: 2
- Source acquisitions: 0
- Product commit message: `monacode: complete P04-T007`
- Evidence commit message: `evidence(monacode): complete P04-T007`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-04/P04-T007.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeTests/Input/MonaEventControlTests.swift`

### Stage `red`

- verification-command: `P04-T007.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Expose explicit prevent-default and stop-propagation state transitions.`
- implementation-operation: `Project platform-neutral keyboard, mouse, and scroll fields into public native-adapted event values.`
- implementation-operation: `Ensure public callbacks cannot mutate the underlying native event object.`

### Stage `green`

- verification-command: `P04-T007.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCode`
- create:
  - Sources/MonaCode/Input/MonaEventControl.swift
  - Sources/MonaCode/Input/MonaPublicInputEvents.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeTests/Input/MonaEventControlTests.swift

<!-- G6-R-TASK:P04-T008:4b1c611364b51fecc4edfced6a64941c9a86d4079f0d0410686d987bab68e1a3 -->

### P04-T008 — Implement copy, cut, paste, and paste-edit pipelines

- Record SHA-256: `4b1c611364b51fecc4edfced6a64941c9a86d4079f0d0410686d987bab68e1a3`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P04-T005` 
- Test contract cases: 1
- Red-scaffold rows: 2
- Source acquisitions: 0
- Product commit message: `monacode: complete P04-T008`
- Evidence commit message: `evidence(monacode): complete P04-T008`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-04/P04-T008.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Transfer/MonaPasteboardTests.swift`

### Stage `red`

- verification-command: `P04-T008.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Read and write the exact retained plain-text, rich-text, and editor metadata representations.`
- implementation-operation: `Run direct paste-edit providers in deterministic order under cancellation and validity tickets.`
- implementation-operation: `Commit cut and multi-cursor paste through the model input barrier.`

### Stage `green`

- verification-command: `P04-T008.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Transfer/MonaPasteboardGateway.swift
  - Sources/MonaCodeAppKit/Transfer/MonaPasteEditPipeline.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Transfer/MonaPasteboardTests.swift

<!-- G6-R-TASK:P04-T009:260bf49744a167dbe56bdabed197f3bde9257ff091584770d757d9928719ebdc -->

### P04-T009 — Implement drag, drop, and macOS Services transfer

- Record SHA-256: `260bf49744a167dbe56bdabed197f3bde9257ff091584770d757d9928719ebdc`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P04-T006`, `P04-T008` 
- Test contract cases: 1
- Red-scaffold rows: 2
- Source acquisitions: 0
- Product commit message: `monacode: complete P04-T009`
- Evidence commit message: `evidence(monacode): complete P04-T009`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-04/P04-T009.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Transfer/MonaDragDropServicesTests.swift`

### Stage `red`

- verification-command: `P04-T009.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Validate drag types, operation masks, drop geometry, direct drop-edit providers, and transfer payloads before commit.`
- implementation-operation: `Map macOS Services read and write selection operations to the same transfer pipeline.`
- implementation-operation: `Reject stale drop geometry and dispose provider lists exactly once.`

### Stage `green`

- verification-command: `P04-T009.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Transfer/MonaDragDropGateway.swift
  - Sources/MonaCodeAppKit/Transfer/MonaServicesGateway.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Transfer/MonaDragDropServicesTests.swift

<!-- G6-R-TASK:P04-T010:f217f705116845826d9dc28f39d51b9a1cc86c99c7073f530fee2fa83c701acd -->

### P04-T010 — Expose the raw UTF-16 native text accessibility surface

- Record SHA-256: `f217f705116845826d9dc28f39d51b9a1cc86c99c7073f530fee2fa83c701acd`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P03-T007`, `P04-T004` 
- Test contract cases: 1
- Red-scaffold rows: 2
- Source acquisitions: 0
- Product commit message: `monacode: complete P04-T010`
- Evidence commit message: `evidence(monacode): complete P04-T010`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-04/P04-T010.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Accessibility/MonaAXTextAreaTests.swift`

### Stage `red`

- verification-command: `P04-T010.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement the frozen native text selectors for value, selection, visible range, attributed substring, range-for-position, bounds-for-range, and line mapping.`
- implementation-operation: `Convert between accessibility integer ranges and raw model UTF-16 offsets without repair.`
- implementation-operation: `Route geometry queries through the complete-generation barrier.`

### Stage `green`

- verification-command: `P04-T010.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Accessibility/MonaAXTextArea.swift
  - Sources/MonaCodeAppKit/Accessibility/MonaAXTextRangeMapper.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Accessibility/MonaAXTextAreaTests.swift

<!-- G6-R-TASK:P04-T011:2b029567529bec3c8689866aaf45e84dc9f7382605bc8e94c9c7b09d8269d594 -->

### P04-T011 — Implement accessibility controls, proxies, links, diagnostics, and actions

- Record SHA-256: `2b029567529bec3c8689866aaf45e84dc9f7382605bc8e94c9c7b09d8269d594`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P04-T006`, `P04-T010` 
- Test contract cases: 1
- Red-scaffold rows: 3
- Source acquisitions: 0
- Product commit message: `monacode: complete P04-T011`
- Evidence commit message: `evidence(monacode): complete P04-T011`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-04/P04-T011.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Accessibility/MonaAXElementGraphTests.swift`

### Stage `red`

- verification-command: `P04-T011.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Instantiate exactly the required editor, gutter, widget, link, diagnostic, and proxy roles.`
- implementation-operation: `Expose the frozen selector, attribute, parameterized-attribute, and action sets per role.`
- implementation-operation: `Preserve stable element identity across viewport recycling while semantic ownership remains unchanged.`

### Stage `green`

- verification-command: `P04-T011.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Accessibility/MonaAXElementGraph.swift
  - Sources/MonaCodeAppKit/Accessibility/MonaAXWidgetProxy.swift
  - Sources/MonaCodeAppKit/Accessibility/MonaAXDiagnosticElement.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Accessibility/MonaAXElementGraphTests.swift

<!-- G6-R-TASK:P04-T012:8b56c4c009254df719a6197df62e3e6b802f1af7ca08c6ecdc2b20a864b62f3e -->

### P04-T012 — Implement focus modes and the localized announcement bridge

- Record SHA-256: `8b56c4c009254df719a6197df62e3e6b802f1af7ca08c6ecdc2b20a864b62f3e`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P04-T003`, `P04-T011` 
- Test contract cases: 1
- Red-scaffold rows: 2
- Source acquisitions: 0
- Product commit message: `monacode: complete P04-T012`
- Evidence commit message: `evidence(monacode): complete P04-T012`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-04/P04-T012.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Accessibility/MonaAXFocusAnnouncementTests.swift`

### Stage `red`

- verification-command: `P04-T012.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Implement editor, widget, accessibility-optimized, tab-focus, and temporary focus transitions as one state machine.`
- implementation-operation: `Deduplicate and serialize announcements without audio or unsupported notification UI.`
- implementation-operation: `Resolve announcement text through the explicit N1 localization profile.`

### Stage `green`

- verification-command: `P04-T012.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Accessibility/MonaAXFocusCoordinator.swift
  - Sources/MonaCodeAppKit/Accessibility/MonaAXAnnouncementBridge.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Accessibility/MonaAXFocusAnnouncementTests.swift

<!-- G6-R-TASK:P04-T013:30ff147c3f3a957255901a874a50896aa8c2efafb98109fc0ec97cded6e1fa31 -->

### P04-T013 — Route accessibility setters through ModelInputBarrier

- Record SHA-256: `30ff147c3f3a957255901a874a50896aa8c2efafb98109fc0ec97cded6e1fa31`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P04-T005`, `P04-T010`, `P04-T012` 
- Test contract cases: 1
- Red-scaffold rows: 1
- Source acquisitions: 0
- Product commit message: `monacode: complete P04-T013`
- Evidence commit message: `evidence(monacode): complete P04-T013`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-04/P04-T013.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Accessibility/MonaAXMutationGatewayTests.swift`

### Stage `red`

- verification-command: `P04-T013.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Translate set-value, set-selection, increment, decrement, press, and custom actions into Core input plans.`
- implementation-operation: `Validate focus, editability, model version, range, and owner generation before commit.`
- implementation-operation: `Publish accessibility notifications only after transaction success.`

### Stage `green`

- verification-command: `P04-T013.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Accessibility/MonaAXMutationGateway.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Accessibility/MonaAXMutationGatewayTests.swift

<!-- G6-R-TASK:P04-T014:3b09df78711c605c347b82caa2dfa7eea3105eb7dfaa1af4cc558886f148d79c -->

### P04-T014 — Deliver MonaCodeEditorView as the AppKit editor boundary

- Record SHA-256: `3b09df78711c605c347b82caa2dfa7eea3105eb7dfaa1af4cc558886f148d79c`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P03-T012`, `P04-T006`, `P04-T009`, `P04-T013` 
- Test contract cases: 1
- Red-scaffold rows: 2
- Source acquisitions: 0
- Product commit message: `monacode: complete P04-T014`
- Evidence commit message: `evidence(monacode): complete P04-T014`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-04/P04-T014.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Views/MonaCodeEditorViewLifecycleTests.swift`

### Stage `red`

- verification-command: `P04-T014.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Compose model attachment, projection, renderer branch, input, transfer, accessibility, widgets, and lifetime ownership in one native view.`
- implementation-operation: `Keep model lifetime independent from view attachment and detach all callbacks before disposal.`
- implementation-operation: `Expose only the contract-owned editor view surface.`

### Stage `green`

- verification-command: `P04-T014.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeAppKit`
- create:
  - Sources/MonaCodeAppKit/Views/MonaCodeEditorView.swift
  - Sources/MonaCodeAppKit/Views/MonaEditorAttachment.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Views/MonaCodeEditorViewLifecycleTests.swift

<!-- G6-R-TASK:P04-T015:9f5de8bf66d5512a601238abbcddc863816fe44ac248dabe6a7cb962b77644d4 -->

### P04-T015 — Deliver MonaCodeEditor and MonaSwiftUIEditorController lifecycle wrappers

- Record SHA-256: `9f5de8bf66d5512a601238abbcddc863816fe44ac248dabe6a7cb962b77644d4`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P04-T014` 
- Test contract cases: 1
- Red-scaffold rows: 2
- Source acquisitions: 0
- Product commit message: `monacode: complete P04-T015`
- Evidence commit message: `evidence(monacode): complete P04-T015`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-04/P04-T015.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/MonaCodeAppKitTests/Views/MonaCodeEditorSwiftUILifecycleTests.swift`

### Stage `red`

- verification-command: `P04-T015.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Wrap the AppKit view with stable identity and explicit controller ownership.`
- implementation-operation: `Map SwiftUI updates to declared option, model, and focus changes only.`
- implementation-operation: `Keep text semantics, rendering, input, provider execution, and command logic outside the wrapper.`

### Stage `green`

- verification-command: `P04-T015.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `MonaCodeSwiftUI`
- create:
  - Sources/MonaCodeSwiftUI/MonaCodeEditor.swift
  - Sources/MonaCodeSwiftUI/MonaSwiftUIEditorController.swift
- modify:
  - _(none)_
- test:
  - Tests/MonaCodeAppKitTests/Views/MonaCodeEditorSwiftUILifecycleTests.swift

<!-- G6-R-TASK:P04-T016:e84b7e7a22338355b54dd0d3ed5bea56f097027f68cfb29ea6572b14d2d6ca6a -->

### P04-T016 — Close native input, transfer, accessibility, and editor embedding

- Record SHA-256: `e84b7e7a22338355b54dd0d3ed5bea56f097027f68cfb29ea6572b14d2d6ca6a`
- Platform scope: `macOS-26-arm64`
- Dependencies: `P04-T007`, `P04-T009`, `P04-T013`, `P04-T015` 
- Test contract cases: 1
- Red-scaffold rows: 0
- Source acquisitions: 0
- Product commit message: `monacode: complete P04-T016`
- Evidence commit message: `evidence(monacode): complete P04-T016`
- Staged evidence path: `artifacts/acceptance-evidence/g6-r/phase-04/P04-T016.json`

#### Stages

### Stage `preflight`

- controller-action: `begin-task`

### Stage `test-authoring`

- authoring-operation: `Tests/ConformanceAndFailureInjection/Phase04NativeBoundaryConformanceTests.swift`

### Stage `red`

- verification-command: `P04-T016.RED.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `implementation`

- implementation-operation: `Run ABC, Pinyin, chord, multi-cursor, pointer, scroll, menu, clipboard, drag/drop, Services, VoiceOver, focus, and lifecycle matrices.`
- implementation-operation: `Inject reentry, stale geometry, cancellation, disposal, read-only, provider, and allocation failures.`
- implementation-operation: `Verify Core source remains free of AppKit-owned types and every mutation uses a declared gateway.`

### Stage `green`

- verification-command: `P04-T016.GREEN.001` (kind=process, network=forbidden, timeout=600000ms, leaves=1)

### Stage `commit`

- controller-action: `commit-task`

### Stage `evidence`

- controller-action: `finalize-evidence`

#### Paths

- productTarget: `null`
- create:
  - _(none)_
- modify:
  - _(none)_
- test:
  - Tests/ConformanceAndFailureInjection/Phase04NativeBoundaryConformanceTests.swift
