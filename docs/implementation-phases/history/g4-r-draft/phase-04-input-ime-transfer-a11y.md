# Phase 4 — Input, IME, Multicursor, Transfer, Accessibility

**Goal:** Implement the native interaction layer: `NSTextInputClient` + keybinding resolver + composition arbitration + pointer/scroll/menu (I3-R*), multicursor, `NSPasteboard`/`NSDraggingDestination` transfer (I4-R), and `NSAccessibilityElement` proxies + `MonaAXTextArea` (A1-R/A2-R2). Completes the **C07 native-interaction core** (full C07 at Phase 7).

**G4-R mapping:** native-input I3-R, I3-R2, I3-R3, I3-R4; clipboard-drag-drop-services I4-R; accessibility A1-R, A1-R2, A2-R2.

**Prerequisites:** Phase 3 (`LineLayoutRecord`, `QueryGeometryBarrier`, hit-test, `MonaScrollModel`). Phase 1 (`EditTransaction`, `ModelInputBarrier` substrate, `GlobalModelEventHub`).

**Exit Gates (this phase completes):**
- **C07 native-interaction core (pass)** — ABC + 拼音 real input-context traces; IME marked text/candidate/dead key/dictation/multicursor; synthesized NSEvent numpad; VoiceOver range/value/frame/action; copy/cut/paste/drag/drop/workspace-edit. (Full C07 — with N1/MD1/S1/SN1/X1 overlays — passes at Phase 7.)
- No candidate artifact.
- Preflight: audit/verify-contract pass.

---

## Task 4.1 — AppKeyEventGateway + NSEvent→KeyCode mapping

**Dependencies:** 1.4, 3.5
**Files:** Create `Sources/MonaCodeAppKit/Input/MonaKeyEventGateway.swift`, `Sources/MonaCodeAppKit/Input/MonaKeyCodeUtils.swift`; Test `Tests/MonaCodeAppKitTests/Input/test_KeyEventGateway.swift`
**Tests:** Single ref-counted `NSEvent` local monitor (runs before `NSApplication.sendEvent`) creates an immutable dispatch record keyed by event identity + `eventNumber` + timestamp, shared across local monitor / menu action / NSView sink (no double-resolve/double-input). Modifiers map device-independently (Command→meta/CtrlCmd, Control→ctrl/WinCtrl, Option→alt, Shift→shift; capsLock/fn excluded). Printable keys use `characters(byApplyingModifiers: [])` + fixed `KeyCodeUtils` table; special keys use `NSEvent.specialKey` + function-key Unicode range; numpad separated via `numericPad`. Dead/IME keys use no-modifier translation for the resolver while the original `NSEvent` goes to `interpretKeyEvents`.
**Contract:** G4-R §architecture.input (custom NSTextInputClient, keybinding resolver, pointer/scroll adapter; NSTextView never owns model truth); I3-R (AppKeyEventGateway, NSEvent→MonaKeyCode); §surfaceCounts (keybindings 379, menus 18/121 items).
**Produces:** —
**Exit-gate contribution:** C07 keyboard/input.
**Steps:**
- [ ] Implement the gateway + dispatch record + mapping table; commit.

## Task 4.2 — Keybinding resolver + chord

**Dependencies:** 4.1, 1.12
**Files:** Create `Sources/MonaCodeAppKit/Input/MonaKeybindingResolver.swift`, `Sources/MonaCodeAppKit/Input/MonaChordState.swift`; Test `Tests/MonaCodeAppKitTests/Input/test_KeybindingResolver.swift`
**Tests:** 379 default keybindings ported with primary/secondary/mac override sorting. Chord timeout strictly >5000ms polled every 500ms; single-modifier candidate cleared at 300ms. Resolver-first when idle; `IME.disable`/`IME.enable` around chord enforced natively.
**Contract:** G4-R §architecture.input; I3-R2 (keybinding and chord overlay); §surfaceCounts.keybindings=379.
**Produces:** —
**Exit-gate contribution:** C07 keybinding.
**Steps:**
- [ ] Implement resolver + chord state machine; capture chord-timing fixtures; commit.

## Task 4.3 — NSTextInputClient + composition arbitration

**Dependencies:** 4.1, 4.2, 1.9
**Files:** Create `Sources/MonaCodeAppKit/Input/MonaTextInputClient.swift`, `Sources/MonaCodeAppKit/Input/MonaCompositionArbitrator.swift`; Test `Tests/MonaCodeAppKitTests/Input/test_Composition.swift`
**Tests:** Custom `NSView` conforms to `NSTextInputClient`; system projects only the primary selection (single UTF-16 range) — `NSTextView` rejected because `selectedRanges` cannot express multiple carets. `NSTextInputContext.handleEvent` gets first-consumption during composition; resolver first when idle. Composition-aware arbitration (I3-R2's resolver-first-on-every-keyDown was invalidated): `MarkedActive` → `inputContext.handleEvent` first; `Idle` → resolver first; `ChordActive` → resolver only; `MarkedActive` and `ChordActive` mutually exclusive. 5 transient marked attributes (underline style/color, foreground, background, marked clause segment) trimmed from NSTextView's 12.
**Contract:** G4-R §architecture.input; I3-R (NSTextInputClient base); I3-R3 (composition arbitration overlay — corrected rule); §explicitCuts (NSTextView text backend).
**Produces:** —
**Exit-gate contribution:** C07 IME/composition.
**Steps:**
- [ ] Implement `NSTextInputClient` conformance + arbitrator; capture ABC + 拼音 composition fixtures; commit.

## Task 4.4 — Multi-cursor composition replication + ModelInputBarrier

**Dependencies:** 4.3, 1.9
**Files:** Create `Sources/MonaCodeAppKit/Input/MonaMulticursorComposition.swift`, `Sources/MonaCodeAppKit/Input/MonaModelInputBarrier.swift`; Test `Tests/MonaCodeAppKitTests/Input/test_MulticursorComposition.swift`
**Tests:** When input target is `NSNotFound` or equals primary, text replicates to all logical selections in one atomic `PreparedInputCommit`. When system specifies an explicit range differing from primary, only primary is modified. Subsequent ranges inside the primary marked replica map proportionally; ranges jumping outside degrade the session to `PrimaryOnly`. `ModelInputBarrier`: any model/selection mutation lacking the current composition token first finishes composition on all editors sharing that model (`discardMarkedText`, retains written text, clears marks), then re-validates R1 `DependencyStamp`/`ApplyTicket`.
**Contract:** G4-R §architecture.input; I3-R3 (multi-cursor composition replication; ModelInputBarrier); R1 (PreparedInputCommit, DependencyStamp revalidation); §equivalenceDomains.exact.
**Produces:** —
**Exit-gate contribution:** C07 multicursor IME; P09 multicursor substrate.
**Steps:**
- [ ] Implement multicursor composition + barrier; capture multicursor composition fixtures; commit.

## Task 4.5 — Pointer / scroll / context menu

**Dependencies:** 4.1, 3.5, 3.7
**Files:** Create `Sources/MonaCodeAppKit/Input/MonaPointerAdapter.swift`, `Sources/MonaCodeAppKit/Input/MonaScrollAdapter.swift`, `Sources/MonaCodeAppKit/Input/MonaContextMenu.swift`; Test `Tests/MonaCodeAppKitTests/Input/test_PointerScroll.swift`
**Tests:** 14 pointer target cases (UNKNOWN, TEXTAREA anchor, 3 gutter, 2 view-zone, content text/empty, content/overlay widget, overview, scrollbar, outside). `NSEvent.clickCount` is only an input; Monaco's 400ms clear, no-skip, position-equal count clamp ported. Scroll delta normalization: precise = `scrollingDeltaY÷40`, coarse = raw delta, internal displacement constant 50. AppKit natural-scroll reversal NOT re-inverted. Zoom clamps to `[-5,20]`. Context menu (18 menus / 121 items per F1-R3) routes through Phase 5 command registry.
**Contract:** G4-R §architecture.input; I3-R4 (pointer, scroll, menu overlay); §surfaceCounts (menus 18, menuItems 121).
**Produces:** —
**Exit-gate contribution:** C07 pointer/scroll; P04 scroll workload substrate.
**Steps:**
- [ ] Implement pointer/scroll/menu adapters; capture pointer-target fixtures; commit.

## Task 4.6 — Public event EventControl

**Dependencies:** 4.2
**Files:** Create `Sources/MonaCodeAppKit/Input/MonaEventControl.swift`; Test `Tests/MonaCodeAppKitTests/Input/test_EventControl.swift`
**Tests:** Public `onKeyDown`/`onKeyUp` fires synchronously BEFORE internal arbitration. `preventDefault`/`stopPropagation` are separate `EventControl` flags sealed after callback return; async mutation is logged as misuse fault.
**Contract:** G4-R §architecture.input; I3-R4 (public event overlay; EventControl).
**Produces:** —
**Exit-gate contribution:** C07 public events.
**Steps:**
- [ ] Implement EventControl; commit.

## Task 4.7 — NSPasteboard transfer pipeline

**Dependencies:** 1.9, 2.8
**Files:** Create `Sources/MonaCodeAppKit/Transfer/MonaDataTransfer.swift`, `Sources/MonaCodeAppKit/Transfer/MonaMacPasteboardAdapter.swift`, `Sources/MonaCodeAppKit/Transfer/MonaCopyMetadata.swift`, `Sources/MonaCodeAppKit/Transfer/MonaPreparedTransferRegistry.swift`; Test `Tests/MonaCodeAppKitTests/Transfer/test_Pasteboard.swift`
**Tests:** Three payload layers: (1) public native formats (plain string, HTML, URI list); (2) `CopyMetadataV1` (binary plist, schema version, transfer UUID, source EOL, language mode, line-copy flag; decode cap 8 MiB); (3) in-process `PreparedTransferRegistry` for async copy-provider results. `NSPasteboardItem` written immediately; `NSPasteboardItemDataProvider` REJECTED for async providers (synchronous `nonisolated` callback cannot await). Copy success precondition: public plain string write must succeed before any cut deletion. HTML threshold 65,536 UTF-16 units (explicit "Copy with Syntax Highlighting" bypasses); HTML reads only the accepted token snapshot. Metadata validation: SHA-256 checksum, no-BOM LE UTF-16, ordered non-overflowing offsets with gaps = source EOL; any failure → plain-text paste. RTF/RTFD NEVER produced. Copy/Cut disabled during marked text.
**Contract:** G4-R §architecture.input (transfer pipeline); I4-R (three-layer transfer contract; 8 MiB cap; HTML 65536 threshold); §explicitCuts (RTF/RTFD); §equivalenceDomains.exact.
**Produces:** —
**Exit-gate contribution:** C07 copy/cut/paste.
**Steps:**
- [ ] Implement the 3-layer pipeline + metadata codec; capture paste/drop fixtures; commit.

## Task 4.8 — NSDraggingDestination + Services

**Dependencies:** 4.7
**Files:** Create `Sources/MonaCodeAppKit/Transfer/MonaDraggingDestination.swift`, `Sources/MonaCodeAppKit/Transfer/MonaServicesMenuRequestor.swift`, `Sources/MonaCodeAppKit/Transfer/MonaTransferTicket.swift`; Test `Tests/MonaCodeAppKitTests/Transfer/test_DragDrop.swift`
**Tests:** `NSView` implements `NSDraggingDestination` + `NSServicesMenuRequestor`. External drop is always a copy; internal drag-move restricted to the same editor view. Services advertises plain string only; send/return affects only primary selection; return text → `ServiceReplace` commit (not Paste As Provider). Paste/Drop tickets lock model identity + contentVersion + selections (paste) or drop position (drop); cursor movement after drop does NOT cancel. Post-edit selector switching verifies `WorkspaceUndoGroupID` is still stack-top across all touched models before undo+resolve+apply. Cross-editor/cross-model drag-move forbidden. Apple's unpublished `multipleTextSelection` payload is opaque third-party type; core never parses it. Provider private data lost on app exit.
**Contract:** G4-R §architecture.input; I4-R (drag/drop, Services, ticket model); §explicitCuts (cross-editor drag-move); §equivalenceDomains.exact.
**Produces:** —
**Exit-gate contribution:** C07 drag/drop/workspace-edit.
**Steps:**
- [ ] Implement drag/drop + Services + tickets → R1 gate; commit.

## Task 4.9 — MonaAXTextArea + native text surface

**Dependencies:** 3.7, 1.9, 4.4
**Files:** Create `Sources/MonaCodeAppKit/Accessibility/MonaAXTextArea.swift`, `Sources/MonaCodeAppKit/Accessibility/MonaNativeTextIndex.swift`; Test `Tests/MonaCodeAppKitTests/Accessibility/test_AXTextArea.swift`
**Tests:** Custom `MonaAXTextArea: NSView` exposing `NSAccessibilityProtocol` text selectors (NOT `NSTextView` — self-drawn, projects same model + `NativeTextIndex` + `ViewGraph` synchronously). All AX indices are LF-normalized raw UTF-16 code units (CRLF→single LF; no fold/inlay/faux-indent/bidi-control). `@objc` selector ABI: getters return `NSString`/`NSAttributedString` reading directly from raw `UInt16`/`CFString`, NEVER through Swift `String` (would repair isolated surrogates); a probe against the deployment toolchain (Swift `.v6` / macOS 26.0 SDK per Phase 0 Task 0.1) confirms `@objc` returning `NSString` preserves raw U+D800 at length 1 — this is a test assertion (A1-R raw-UTF16 surface contract), not a toolchain dependency. `RTFForRange` returns nil permanently; rich AX only via `accessibilityAttributedStringForRange`. `AXTextCompletion` attribute NOT emitted (ghost text not in raw model). All `valueChanged`/`selectedTextChanged`/`layoutChanged`/`markingSessionBegan/Ended`/`announcementRequested` explicitly posted per `GlobalModelEventHub` batch.
**Contract:** G4-R §architecture.accessibility (raw-UTF16 native text surface + native controls/proxies/focus/announcement); A1-R (native text surface base); §explicitCuts (RTF/RTFD; AXTextCompletion; NSTextView automatic notifications).
**Produces:** —
**Exit-gate contribution:** C07 AX text surface.
**Steps:**
- [ ] Implement `MonaAXTextArea` + `NativeTextIndex` + `@objc` selectors; capture VoiceOver fixtures; commit.

## Task 4.10 — AX controls, proxies, links, diagnostics

**Dependencies:** 4.9, 1.12
**Files:** Create `Sources/MonaCodeAppKit/Accessibility/MonaAXControls.swift`, `Sources/MonaCodeAppKit/Accessibility/MonaAXProxy.swift`, `Sources/MonaCodeAppKit/Accessibility/MonaAXLink.swift`; Test `Tests/MonaCodeAppKitTests/Accessibility/test_AXControls.swift`
**Tests:** Real `NSButton`/`NSTextField`/`NSSearchField`/`NSTableView`/`NSOutlineView`/`NSPopUpButton`/`NSSlider`/`NSColorWell`/`NSProgressIndicator`/`NSBox` wherever Monaco uses HTML controls. Canvas-only interactive items (CodeLens, inlay actions, sticky rows, diff controls) get stable `NSAccessibilityElement` proxies with configured roles. Pure visual surfaces (minimap, ruler, margin, view zones, glyph margin, cursors, block decorations) have NO AX node. `MonaAXTextLink` children (role=AXLink, label=range substring, help=tooltip/URI, frame=same-generation range frame); press re-checks editor/model/link identity before opener. Diagnostics: generic markers use `AXAnnotation` arrays; `AXMarkedMisspelled` only for actual spelling markers. Proxy key = feature ID + semantic item ID + model identity; only viewport-visible interactive items + two viewport heights of overscan get proxies.
**Contract:** G4-R §architecture.accessibility; A1-R2 (selector, attribute, action overlay); §equivalenceDomains.nativeAdapted (AppKit control roles replace DOM/ARIA).
**Produces:** —
**Exit-gate contribution:** C07 AX controls/links.
**Steps:**
- [ ] Implement controls + proxies + links; commit.

## Task 4.11 — Focus modes + announcement bridge

**Dependencies:** 4.10, 1.5
**Files:** Create `Sources/MonaCodeAppKit/Accessibility/MonaFocusModel.swift`, `Sources/MonaCodeAppKit/Accessibility/MonaAnnouncementBridge.swift`; Test `Tests/MonaCodeAppKitTests/Accessibility/test_FocusAnnouncement.swift`
**Tests:** 8 focus modes (editor-shared, owned-input, owned-collection, explicit-popover, native-control, modal-dialog, host-owned, passive); every widget contract references only these 8 IDs; every mode exercised by ≥1 contract (24 widget contracts). `accessibilitySupport=auto` maps to `NSWorkspace.shared.isVoiceOverEnabled` + KVO; when enabled, forces `wrappingStrategy=advanced` + `wrappingIndent=none`. Announcement bridge: two stable `NSAccessibilityElement` announcer targets per channel (alert/status), alternated on consecutive events (mirrors Monaco's two-container pattern); raw UTF-16 cap 20,000; empty messages update logical channel but post nothing; non-empty equal consecutive messages NEVER coalesced; stale async events dropped at the main-actor commit barrier; ordering: state mutation → layout/AX tree → selection/focus notification → announcement; high precedes medium from same barrier. 39 announcement patterns (30 effective + 9 excluded).
**Contract:** G4-R §architecture.accessibility; A2-R2 (widget, focus, feature, announcement overlay); §surfaceCounts.accessibility (widgetContracts 24, focusModes 8, announcementPatternOccurrences 39, effectiveAnnouncementSites 30, excludedAnnouncementOccurrences 9); §equivalenceDomains.nativeAdapted.
**Produces:** —
**Exit-gate contribution:** C07 AX focus/announcements; P13 IME/AX workload substrate.
**Steps:**
- [ ] Implement focus model + announcement bridge; capture announcement fixtures; commit.

## Task 4.12 — AX setters → ModelInputBarrier

**Dependencies:** 4.11, 4.4
**Files:** Create `Sources/MonaCodeAppKit/Accessibility/MonaAXSetters.swift`; Test `Tests/MonoCodeAppKitTests/Accessibility/test_AXSetters.swift`
**Tests:** AX setters (`selectedText`, `value`, `selectedTextRange`/`selectedTextRanges`) all go through `ModelInputBarrier` → R1 transaction. `value` setter performs a model flush (clears undo/redo, tracked decorations, trim state) — NOT an undoable edit. `selectedText` performs Monaco type-replacement across all current selections, ending each as a collapsed caret. `selectedTextRanges` returns all editor selections as normalized LF `NSRange`s, primary first, rest stably sorted by location/length; direction exists only in editor `Selection`; `NSRange` never fakes direction. `frameForRange` uses V1-R3 `QueryGeometryBarrier`; `rangeForPosition` uses V1-R4 single hit-test; `rangeForIndex` uses AppKit composed-character contract.
**Contract:** G4-R §architecture.accessibility; A2-R2 (AX is not a second editor; setters → ModelInputBarrier → R1); §equivalenceDomains.exact.
**Produces:** —
**Exit-gate contribution:** C07 AX setters.
**Steps:**
- [ ] Implement AX setters → barrier → R1; commit.

## Task 4.13 — Phase 4 integration + C07 differential

**Dependencies:** 4.1–4.12
**Files:** Modify `Tests/DifferentialFixtures/input/`; Create `docs/implementation-phases/verification/phase-04-verification.md` (after verification)
**Tests:** C07 full differential passes (ABC + 拼音 IME; VoiceOver; copy/cut/paste/drag/drop) vs M0/M1; `QEnvironmentID` records enabled input sources; `swift test` green.
**Contract:** G4-R §designClosure.phaseRule; §acceptance.overlays.C07.
**Produces:** —
**Exit-gate contribution:** C07 pass; Phase 4 done when committed + three adversarial rounds pass.
**Steps:**
- [ ] Run C07 differential; commit; trigger per-phase adversarial verification.

---

## Revision 2 — Verification Corrections (supersedes conflicting original text)

Applied from `verification/phase-04-verification.md` (3 rounds, no BLOCKING):

- **Exit gate (M1):** Phase 4 completes the **C07 native-interaction core** (input/IME/transfer/AX) only. The C07 overlay clauses for N1-R (Phase 5), MD1-R/SN1 (Phase 6), S1-R/X1-R (Phase 7) are vacuously satisfied until their phases; **full C07 pass is at Phase 7/8**. (Master-plan C07 row updated.)
- **Tasks 4.9–4.12 (M2):** Contract blocks cite `artifact=monaco-0.56.0-a2r-accessibility-manifest.json` (SHA `f8f8123c4c8d426106c40ea71ba64d08940d3961e57db0a0bbb276a87e2432da`).
- **Tasks 4.7/4.8 (M3):** paste/drop add dependency **4.4** and state "paste/drop → **ModelInputBarrier** (finish active composition, clear marks) → R1 `PreparedModelCommit` with `DependencyStamp`/`ApplyTicket` revalidation" — consistent with copy/cut disabled during marked text. Task 4.8 also add dependency **3.7** (drop uses `rangeForPosition` hit-test).
- **Task 4.7:** SHA-256 for `CopyMetadataV1` via CryptoKit (allowed Apple framework).
- **Task 4.11:** A1-R accessibility-mode computed-option effects beyond `wrappingStrategy=advanced`/`wrappingIndent=none` (also `allowVariableFonts` effective-font, disable `optimized-*` options when VoiceOver enabled); defer the option computation to Phase 5 with an A1-R cross-reference.
- **Citation fixes:** RTF/RTFD, cross-editor drag-move, AXTextCompletion, NSTextView automatic notifications cite the owning layer (I4-R / A1-R / A1-R2 native adaptation), NOT `§explicitCuts` (they are not in the manifest's `explicitCuts` arrays). `AXTextCompletion`: A1-R2 retains the Boolean `TextCompletion` run attribute in `accessibilityAttributedStringForRange` (for Phase 5 inline-completion); only the `NSAccessibilityTextCompletionAttribute` emission is absent. Task 4.4 splits citation (I3-R for NSNotFound/PrimaryOnly replication; I3-R3 for `ModelInputBarrier`). Task 4.1 drops the spurious 3.5 dependency. Task 4.12 path typo corrected `MonoCodeAppKitTests` → `MonaCodeAppKitTests`.

---

## Task 4.13b — Delivery-scope editor view + SwiftUI types

**Dependencies:** 4.3, 4.9, 3.6
**Files:**
- Create: `Sources/MonaCodeAppKit/Views/MonaCodeEditorView.swift` (`: NSView`, conforms `NSTextInputClient`; composes `MonaTextInputClient` + `MonaAXTextArea` + the Core Graphics renderer + `MonaScrollModel`; the AppKit hot view path — holds no model truth)
- Create: `Sources/MonaCodeSwiftUI/MonaCodeEditor.swift` (`NSViewRepresentable`; lifecycle/binding bridge only; holds no model/view state, no `Binding<String>`, no second selection/scroll/undo authority)
- Create: `Sources/MonaCodeSwiftUI/MonaSwiftUIEditorController.swift` (a weak `@MainActor` handle to the live editor; never retains model/view state; the SwiftUI type's only escape hatch)
**Tests:** `MonaCodeEditorView` is an `NSView` (not `NSTextView`); `MonaCodeModel` remains the sole undo/redo truth (`NSUndoManager` holds no history); the SwiftUI `Representable` overrides only `makeNSView`/`updateNSView`/`dismantleNSView`; `MonaSwiftUIEditorController` is weak (does not extend editor lifetime). Symbol-graph present in `MonaNativeDeclarationManifest` (Phase 5).
**Contract:** G4-R §deliveryScope.requiredViews (`MonaCodeEditorView`), requiredSwiftUITypes (`MonaCodeEditor`, `MonaSwiftUIEditorController`); §architecture.embedding (AppKit owns hot view path; SwiftUI owns lifecycle only); §hostContractClosure.
**Produces:** —
**Exit-gate contribution:** C09 (3 AppKit views / 4 SwiftUI types — 1 of each here; remaining in Task 7.9b).
**Steps:**
- [ ] Implement `MonaCodeEditorView` composing the Phase-4 input/AX + Phase-3 renderer/scroll.
- [ ] Implement `MonaCodeEditor` (`NSViewRepresentable`, lifecycle-only) + `MonaSwiftUIEditorController` (weak handle).
- [ ] Verify `MonaCodeModel` is sole undo truth; commit.
