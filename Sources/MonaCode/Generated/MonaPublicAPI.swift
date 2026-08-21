// MonaPublicAPI.swift
//
// P05-T001 — Generate the exact 555-path native public declaration graph.
//
// GENERATED FILE — do not edit by hand. Regenerate with:
//
//   /opt/homebrew/Cellar/node/26.7.0/bin/node \
//       Tools/Generators/generate-contract-registries.mjs
//
// This file is the MonaCode public declaration graph. It is the Foundation-only Core product: native Swift declarations for every retained F1-R4 path whose product home is MonaCode, plus explicit UNAVAILABLE disposition records for every cut path assigned to the Core product. No AppKit, CoreGraphics, CoreText, Metal, SwiftUI or Process import is permitted inside this file (the foundation-only boundary).
// It records 422 retained native Swift declarations
// and 115 explicit UNAVAILABLE cut dispositions (no production
// symbol emitted for cut paths). 537 of the 555 F1-R4 paths live here.
//
// Source artifacts (frozen, G6-R contract archive):
//   - monaco-0.56.0-f1r3-scope-manifest.json
//   - monaco-0.56.0-f1r3-instance-surface-manifest.json
//   - monaco-0.56.0-f1r4-public-declaration-manifest.json
//   - monacode-f1r5-native-type-contract-manifest.json
//
// Generator SHA-256: c1eb9c4ae3713dd778e7242a22f6535f0bff47f4d4ea484dc5d44d24fe48599f
// Generator rule: read F1-R3 + F1-R4, emit individual rows without renaming
// or coalescing identities; generate native declarations with exact
// optionals, overloads, extensible raw values, reference/value identity,
// throwing, async and event adaptation; reject zero-expansion selectors;
// keep cut declarations as explicit UNAVAILABLE dispositions.

import Foundation
// PATH: topLevel.CancellationTokenSource
// ORDINAL: 0
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: value-export
// RESOLVED-KIND: class
// BASELINE: CancellationTokenSource
// BASELINE-LOCAL: editor_main_CancellationTokenSource
// SOURCE-LINE: 10219
// DECLARATION-SHA256: e8535731be63c9f7368011690b44e78d137e881146b13a1ace0b1aa6bd41d567
// DECLARATION-TEXT-LENGTH: 649
// RESOLVED-ALIAS-GRAPH-SHA256: f2ace7206cf82eae9fd0ec190d77014982f7a3cafa8c16583eb982b3b442e741
// RESOLVED-ALIAS-PARTS: type:editor_main_CancellationTokenSource@10176, const:editor_main_CancellationTokenSource@10177, class:CancellationTokenSource@362
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - reference identity: @MainActor final reference type; non-Sendable
public final class MonaTopLevelCancellationTokenSource {}

// PATH: topLevel.Emitter
// ORDINAL: 1
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: value-export
// RESOLVED-KIND: class
// BASELINE: Emitter
// BASELINE-LOCAL: editor_main_Emitter
// SOURCE-LINE: 10219
// DECLARATION-SHA256: e8535731be63c9f7368011690b44e78d137e881146b13a1ace0b1aa6bd41d567
// DECLARATION-TEXT-LENGTH: 649
// RESOLVED-ALIAS-GRAPH-SHA256: 26e87628bc7bce7ba1b33b3dc43b68aa38c9a5dede771aaf4da25d6701762666
// RESOLVED-ALIAS-PARTS: type:editor_main_Emitter@10178, const:editor_main_Emitter@10179, class:Emitter@343
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - reference identity: @MainActor final reference type; non-Sendable
public final class MonaTopLevelEmitter {}

// PATH: topLevel.KeyCode
// ORDINAL: 2
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: value-export
// RESOLVED-KIND: enum
// BASELINE: KeyCode
// BASELINE-LOCAL: editor_main_KeyCode
// SOURCE-LINE: 10219
// DECLARATION-SHA256: e8535731be63c9f7368011690b44e78d137e881146b13a1ace0b1aa6bd41d567
// DECLARATION-TEXT-LENGTH: 649
// RESOLVED-ALIAS-GRAPH-SHA256: 688c41caeb336ec5ed80eec172399612422a28ed64d20cb12bcaf90fa33e57f9
// RESOLVED-ALIAS-PARTS: type:editor_main_KeyCode@10192, const:editor_main_KeyCode@10193, enum:KeyCode@542
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaTopLevelKeyCode {}

// PATH: topLevel.KeyMod
// ORDINAL: 3
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: value-export
// RESOLVED-KIND: class
// BASELINE: KeyMod
// BASELINE-LOCAL: editor_main_KeyMod
// SOURCE-LINE: 10219
// DECLARATION-SHA256: e8535731be63c9f7368011690b44e78d137e881146b13a1ace0b1aa6bd41d567
// DECLARATION-TEXT-LENGTH: 649
// RESOLVED-ALIAS-GRAPH-SHA256: 15acad642cfbaa9e41d2acc0a55aacb7a8d4c8cf5aaeeb9f3ff62ff9cae38807
// RESOLVED-ALIAS-PARTS: type:editor_main_KeyMod@10194, const:editor_main_KeyMod@10195, class:KeyMod@741
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - reference identity: @MainActor final reference type; non-Sendable
public final class MonaTopLevelKeyMod {}

// PATH: topLevel.MarkerSeverity
// ORDINAL: 4
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: value-export
// RESOLVED-KIND: enum
// BASELINE: MarkerSeverity
// BASELINE-LOCAL: editor_main_MarkerSeverity
// SOURCE-LINE: 10219
// DECLARATION-SHA256: e8535731be63c9f7368011690b44e78d137e881146b13a1ace0b1aa6bd41d567
// DECLARATION-TEXT-LENGTH: 649
// RESOLVED-ALIAS-GRAPH-SHA256: 4e964606b502f0ecd9cbaa53e74bcd0049bd826c474d73f4609699249648d9da
// RESOLVED-ALIAS-PARTS: type:editor_main_MarkerSeverity@10197, const:editor_main_MarkerSeverity@10198, enum:MarkerSeverity@355
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaTopLevelMarkerSeverity {}

// PATH: topLevel.MarkerTag
// ORDINAL: 5
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: value-export
// RESOLVED-KIND: enum
// BASELINE: MarkerTag
// BASELINE-LOCAL: editor_main_MarkerTag
// SOURCE-LINE: 10219
// DECLARATION-SHA256: e8535731be63c9f7368011690b44e78d137e881146b13a1ace0b1aa6bd41d567
// DECLARATION-TEXT-LENGTH: 649
// RESOLVED-ALIAS-GRAPH-SHA256: 1c4321a4ba48957fccb95f394e0812c7b5bdb0dbc3b8850277745f94d3eb0600
// RESOLVED-ALIAS-PARTS: type:editor_main_MarkerTag@10199, const:editor_main_MarkerTag@10200, enum:MarkerTag@350
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaTopLevelMarkerTag {}

// PATH: topLevel.Position
// ORDINAL: 6
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: value-export
// RESOLVED-KIND: class
// BASELINE: Position
// BASELINE-LOCAL: editor_main_Position
// SOURCE-LINE: 10219
// DECLARATION-SHA256: e8535731be63c9f7368011690b44e78d137e881146b13a1ace0b1aa6bd41d567
// DECLARATION-TEXT-LENGTH: 649
// RESOLVED-ALIAS-GRAPH-SHA256: 0c0fdce6fefb6e532e674553cc82db92137f32a4da134e348aac33fc32abec79
// RESOLVED-ALIAS-PARTS: type:editor_main_Position@10201, const:editor_main_Position@10202, class:Position@826
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - reference identity: @MainActor final reference type; non-Sendable
public final class MonaTopLevelPosition {}

// PATH: topLevel.Range
// ORDINAL: 7
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: value-export
// RESOLVED-KIND: class
// BASELINE: Range
// BASELINE-LOCAL: editor_main_Range
// SOURCE-LINE: 10219
// DECLARATION-SHA256: e8535731be63c9f7368011690b44e78d137e881146b13a1ace0b1aa6bd41d567
// DECLARATION-TEXT-LENGTH: 649
// RESOLVED-ALIAS-GRAPH-SHA256: 8c62104c6f04209bbfa9bb6e76b9ed17ccef7a55e51f8b7484c82840af51fd74
// RESOLVED-ALIAS-PARTS: type:editor_main_Range@10203, const:editor_main_Range@10204, class:Range@926
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - reference identity: @MainActor final reference type; non-Sendable
public final class MonaTopLevelRange {}

// PATH: topLevel.Selection
// ORDINAL: 8
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: value-export
// RESOLVED-KIND: class
// BASELINE: Selection
// BASELINE-LOCAL: editor_main_Selection
// SOURCE-LINE: 10219
// DECLARATION-SHA256: e8535731be63c9f7368011690b44e78d137e881146b13a1ace0b1aa6bd41d567
// DECLARATION-TEXT-LENGTH: 649
// RESOLVED-ALIAS-GRAPH-SHA256: f264ad767ed3967007c4522d4fd6c4cc3b4582a7550a2f2630a3418ab577bb85
// RESOLVED-ALIAS-PARTS: type:editor_main_Selection@10205, const:editor_main_Selection@10206, class:Selection@1121
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - reference identity: @MainActor final reference type; non-Sendable
public final class MonaTopLevelSelection {}

// PATH: topLevel.SelectionDirection
// ORDINAL: 9
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: value-export
// RESOLVED-KIND: enum
// BASELINE: SelectionDirection
// BASELINE-LOCAL: editor_main_SelectionDirection
// SOURCE-LINE: 10219
// DECLARATION-SHA256: e8535731be63c9f7368011690b44e78d137e881146b13a1ace0b1aa6bd41d567
// DECLARATION-TEXT-LENGTH: 649
// RESOLVED-ALIAS-GRAPH-SHA256: 74eda7108d2b7d3b2544588869e833e0696d0684560715cbc8bce9c95b8be2ac
// RESOLVED-ALIAS-PARTS: type:editor_main_SelectionDirection@10207, const:editor_main_SelectionDirection@10208, enum:SelectionDirection@1200
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaTopLevelSelectionDirection {}

// PATH: topLevel.Token
// ORDINAL: 10
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: value-export
// RESOLVED-KIND: class
// BASELINE: Token
// BASELINE-LOCAL: editor_main_Token
// SOURCE-LINE: 10219
// DECLARATION-SHA256: e8535731be63c9f7368011690b44e78d137e881146b13a1ace0b1aa6bd41d567
// DECLARATION-TEXT-LENGTH: 649
// RESOLVED-ALIAS-GRAPH-SHA256: e67679273f43daea8770e46b03207eff1ffb356e5d97004b39a45f4e934220dd
// RESOLVED-ALIAS-PARTS: type:editor_main_Token@10210, const:editor_main_Token@10211, class:Token@1211
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - reference identity: @MainActor final reference type; non-Sendable
public final class MonaTopLevelToken {}

// PATH: topLevel.Uri
// ORDINAL: 11
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: value-export
// RESOLVED-KIND: class
// BASELINE: Uri
// BASELINE-LOCAL: editor_main_Uri
// SOURCE-LINE: 10219
// DECLARATION-SHA256: e8535731be63c9f7368011690b44e78d137e881146b13a1ace0b1aa6bd41d567
// DECLARATION-TEXT-LENGTH: 649
// RESOLVED-ALIAS-GRAPH-SHA256: 9df0295c4a3c74a1766087cedfb68a627cb3f6e29d910df56db44bfc28dbbfc1
// RESOLVED-ALIAS-PARTS: type:editor_main_Uri@10212, const:editor_main_Uri@10213, class:Uri@400
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - reference identity: @MainActor final reference type; non-Sendable
public final class MonaTopLevelUri {}

// PATH: topLevel.css
// ORDINAL: 12
// DISPOSITION: cut-builtin-language-pack
// SOURCE-KIND: value-export
// BASELINE: css
// BASELINE-LOCAL: register$3
// SOURCE-LINE: 10219
// DECLARATION-SHA256: e8535731be63c9f7368011690b44e78d137e881146b13a1ace0b1aa6bd41d567
// DECLARATION-TEXT-LENGTH: 649
// RESOLVED-ALIAS-GRAPH-SHA256: 81ed9f8630b99c3f4c6b76a85602a0fa81fca5fbbde697f780d58da1b4afff3a
// RESOLVED-ALIAS-PARTS: namespace:register$3@9262
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: builtin language pack is cut; the four css/html/json/typescript packs are already removed

// PATH: topLevel.editor
// ORDINAL: 13
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: value-export
// RESOLVED-KIND: namespace
// BASELINE: editor
// BASELINE-LOCAL: editor_main_editor
// SOURCE-LINE: 10219
// DECLARATION-SHA256: e8535731be63c9f7368011690b44e78d137e881146b13a1ace0b1aa6bd41d567
// DECLARATION-TEXT-LENGTH: 649
// RESOLVED-ALIAS-GRAPH-SHA256: 050fcab17ba337f092a4fbe47e9d08f2cb1ce04e6e0549081b3b0c1503d63e11
// RESOLVED-ALIAS-PARTS: import-equals:editor_main_editor@10215, namespace:editor@1220
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public enum MonaTopLevelEditor {}

// PATH: topLevel.html
// ORDINAL: 14
// DISPOSITION: cut-builtin-language-pack
// SOURCE-KIND: value-export
// BASELINE: html
// BASELINE-LOCAL: register$2
// SOURCE-LINE: 10219
// DECLARATION-SHA256: e8535731be63c9f7368011690b44e78d137e881146b13a1ace0b1aa6bd41d567
// DECLARATION-TEXT-LENGTH: 649
// RESOLVED-ALIAS-GRAPH-SHA256: fe869f21ec6438457d1619ecdc448e860bc2916dd3781a72669e86cbfdd8b00d
// RESOLVED-ALIAS-PARTS: namespace:register$2@9447
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: builtin language pack is cut; the four css/html/json/typescript packs are already removed

// PATH: topLevel.json
// ORDINAL: 15
// DISPOSITION: cut-builtin-language-pack
// SOURCE-KIND: value-export
// BASELINE: json
// BASELINE-LOCAL: register$1
// SOURCE-LINE: 10219
// DECLARATION-SHA256: e8535731be63c9f7368011690b44e78d137e881146b13a1ace0b1aa6bd41d567
// DECLARATION-TEXT-LENGTH: 649
// RESOLVED-ALIAS-GRAPH-SHA256: b793ccef9d80b565d66c521d802cb9f9ad0d828f781a6731d2acd5bbb5ca6f8c
// RESOLVED-ALIAS-PARTS: namespace:register$1@9701
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: builtin language pack is cut; the four css/html/json/typescript packs are already removed

// PATH: topLevel.languages
// ORDINAL: 16
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: value-export
// RESOLVED-KIND: namespace
// BASELINE: languages
// BASELINE-LOCAL: editor_main_languages
// SOURCE-LINE: 10219
// DECLARATION-SHA256: e8535731be63c9f7368011690b44e78d137e881146b13a1ace0b1aa6bd41d567
// DECLARATION-TEXT-LENGTH: 649
// RESOLVED-ALIAS-GRAPH-SHA256: 47612fb9aa78885b1944aa21924063670c775e05e51e7b4a6efe15c536e1343c
// RESOLVED-ALIAS-PARTS: import-equals:editor_main_languages@10216, namespace:languages@6833, namespace:languages@10225
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public enum MonaTopLevelLanguages {}

// PATH: topLevel.lsp
// ORDINAL: 17
// DISPOSITION: retained-and-extended-native-lsp-umbrella
// SOURCE-KIND: value-export
// RESOLVED-KIND: namespace
// BASELINE: lsp
// BASELINE-LOCAL: index_d
// SOURCE-LINE: 10219
// DECLARATION-SHA256: e8535731be63c9f7368011690b44e78d137e881146b13a1ace0b1aa6bd41d567
// DECLARATION-TEXT-LENGTH: 649
// RESOLVED-ALIAS-GRAPH-SHA256: d4d08d0a06e51d0ae5095ea6e2be33472d7063cb3c0ce91ad8db2ce200a46d01
// RESOLVED-ALIAS-PARTS: namespace:index_d@269
//   - LSP umbrella extension: retained native lsp namespace
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public enum MonaTopLevelLsp {}

// PATH: topLevel.typescript
// ORDINAL: 18
// DISPOSITION: cut-builtin-language-pack
// SOURCE-KIND: value-export
// BASELINE: typescript
// BASELINE-LOCAL: register
// SOURCE-LINE: 10219
// DECLARATION-SHA256: e8535731be63c9f7368011690b44e78d137e881146b13a1ace0b1aa6bd41d567
// DECLARATION-TEXT-LENGTH: 649
// RESOLVED-ALIAS-GRAPH-SHA256: a3da9b5daedf0c0f4909bf9750f1fc605aece4eab1c9553efe177cb0ce57dc2a
// RESOLVED-ALIAS-PARTS: namespace:register@10170
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: builtin language pack is cut; the four css/html/json/typescript packs are already removed

// PATH: topLevel.worker
// ORDINAL: 19
// DISPOSITION: cut-webworker-namespace
// SOURCE-KIND: value-export
// BASELINE: worker
// BASELINE-LOCAL: editor_main_worker
// SOURCE-LINE: 10219
// DECLARATION-SHA256: e8535731be63c9f7368011690b44e78d137e881146b13a1ace0b1aa6bd41d567
// DECLARATION-TEXT-LENGTH: 649
// RESOLVED-ALIAS-GRAPH-SHA256: b4a1756563c4e32487050051044b4daa871f8b5304113ab277447cd5bd36fc13
// RESOLVED-ALIAS-PARTS: import-equals:editor_main_worker@10217, namespace:worker@9037
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: WebWorker namespace is absent from the runtime scope and cut wholesale

// PATH: topLevel.CancellationToken
// ORDINAL: 20
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: type-export
// RESOLVED-KIND: interface
// BASELINE: CancellationToken
// BASELINE-LOCAL: editor_main_CancellationToken
// SOURCE-LINE: 10220
// DECLARATION-SHA256: 209565d6acc43aed691e1f123f6308a15eb050a4e498f1b5e1bd4d9c8c810ed0
// DECLARATION-TEXT-LENGTH: 731
// RESOLVED-ALIAS-GRAPH-SHA256: 114efe003e4fb6ec26f77ce15dbee5c2e0b2201ecd70a4ff5b774b39ddc7992f
// RESOLVED-ALIAS-PARTS: type:editor_main_CancellationToken@10175, interface:CancellationToken@369
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaTopLevelCancellationToken {}

// PATH: topLevel.Environment
// ORDINAL: 21
// DISPOSITION: cut-web-runtime-policy
// SOURCE-KIND: type-export
// BASELINE: Environment
// BASELINE-LOCAL: editor_main_Environment
// SOURCE-LINE: 10220
// DECLARATION-SHA256: 209565d6acc43aed691e1f123f6308a15eb050a4e498f1b5e1bd4d9c8c810ed0
// DECLARATION-TEXT-LENGTH: 731
// RESOLVED-ALIAS-GRAPH-SHA256: 0623d623fb941aab98399aa4f47aa884f478f5f2e7db731c8f8c8fab324b9c76
// RESOLVED-ALIAS-PARTS: type:editor_main_Environment@10180, interface:Environment@290
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: web-only runtime policy with no native host equivalent

// PATH: topLevel.IDisposable
// ORDINAL: 22
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: type-export
// RESOLVED-KIND: interface
// BASELINE: IDisposable
// BASELINE-LOCAL: editor_main_IDisposable
// SOURCE-LINE: 10220
// DECLARATION-SHA256: 209565d6acc43aed691e1f123f6308a15eb050a4e498f1b5e1bd4d9c8c810ed0
// DECLARATION-TEXT-LENGTH: 731
// RESOLVED-ALIAS-GRAPH-SHA256: f61d03401cc41c2cc6558ada11aa7ef998d06997c45f976e60f4a3b1635de058
// RESOLVED-ALIAS-PARTS: type:editor_main_IDisposable@10181, interface:IDisposable@332
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaTopLevelIDisposable {}

// PATH: topLevel.IEvent
// ORDINAL: 23
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: type-export
// RESOLVED-KIND: interface
// BASELINE: IEvent
// BASELINE-LOCAL: editor_main_IEvent
// SOURCE-LINE: 10220
// DECLARATION-SHA256: 209565d6acc43aed691e1f123f6308a15eb050a4e498f1b5e1bd4d9c8c810ed0
// DECLARATION-TEXT-LENGTH: 731
// RESOLVED-ALIAS-GRAPH-SHA256: 25df14115eef2e4f8d46e0e299a820b81c9ccb941a22114797120a18b3d91361
// RESOLVED-ALIAS-PARTS: type:editor_main_IEvent@10182, interface:IEvent@336
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaTopLevelIEvent {}

// PATH: topLevel.IKeyboardEvent
// ORDINAL: 24
// DISPOSITION: retained-native-event-adaptation
// SOURCE-KIND: type-export
// RESOLVED-KIND: interface
// BASELINE: IKeyboardEvent
// BASELINE-LOCAL: editor_main_IKeyboardEvent
// SOURCE-LINE: 10220
// DECLARATION-SHA256: 209565d6acc43aed691e1f123f6308a15eb050a4e498f1b5e1bd4d9c8c810ed0
// DECLARATION-TEXT-LENGTH: 731
// RESOLVED-ALIAS-GRAPH-SHA256: fc38980e31e6052b55925937a807ae5065553a9135f66a8544d7ffc7b53a2b8f
// RESOLVED-ALIAS-PARTS: type:editor_main_IKeyboardEvent@10183, interface:IKeyboardEvent@764
//   - event adaptation: browser keyboard/mouse/scroll -> immutable Mona native event snapshot
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaTopLevelIKeyboardEvent {}

// PATH: topLevel.IMarkdownString
// ORDINAL: 25
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: type-export
// RESOLVED-KIND: interface
// BASELINE: IMarkdownString
// BASELINE-LOCAL: editor_main_IMarkdownString
// SOURCE-LINE: 10220
// DECLARATION-SHA256: 209565d6acc43aed691e1f123f6308a15eb050a4e498f1b5e1bd4d9c8c810ed0
// DECLARATION-TEXT-LENGTH: 731
// RESOLVED-ALIAS-GRAPH-SHA256: 98dbebc061448c665893802c7cdfddd5e93ea01ac84204922d8100e96c62356f
// RESOLVED-ALIAS-PARTS: type:editor_main_IMarkdownString@10184, interface:IMarkdownString@749
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaTopLevelIMarkdownString {}

// PATH: topLevel.IMouseEvent
// ORDINAL: 26
// DISPOSITION: retained-native-event-adaptation
// SOURCE-KIND: type-export
// RESOLVED-KIND: interface
// BASELINE: IMouseEvent
// BASELINE-LOCAL: editor_main_IMouseEvent
// SOURCE-LINE: 10220
// DECLARATION-SHA256: 209565d6acc43aed691e1f123f6308a15eb050a4e498f1b5e1bd4d9c8c810ed0
// DECLARATION-TEXT-LENGTH: 731
// RESOLVED-ALIAS-GRAPH-SHA256: 3b60ccd9c5393e6921784ba323b7f130bf94acbee8a973ae70111418866426cc
// RESOLVED-ALIAS-PARTS: type:editor_main_IMouseEvent@10185, interface:IMouseEvent@779
//   - event adaptation: browser keyboard/mouse/scroll -> immutable Mona native event snapshot
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaTopLevelIMouseEvent {}

// PATH: topLevel.IPosition
// ORDINAL: 27
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: type-export
// RESOLVED-KIND: interface
// BASELINE: IPosition
// BASELINE-LOCAL: editor_main_IPosition
// SOURCE-LINE: 10220
// DECLARATION-SHA256: 209565d6acc43aed691e1f123f6308a15eb050a4e498f1b5e1bd4d9c8c810ed0
// DECLARATION-TEXT-LENGTH: 731
// RESOLVED-ALIAS-GRAPH-SHA256: 79c46695609cee09f43c125411bbd78a59d282f9982ae66aeddc4f1704db1fd5
// RESOLVED-ALIAS-PARTS: type:editor_main_IPosition@10186, interface:IPosition@812
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaTopLevelIPosition {}

// PATH: topLevel.IRange
// ORDINAL: 28
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: type-export
// RESOLVED-KIND: interface
// BASELINE: IRange
// BASELINE-LOCAL: editor_main_IRange
// SOURCE-LINE: 10220
// DECLARATION-SHA256: 209565d6acc43aed691e1f123f6308a15eb050a4e498f1b5e1bd4d9c8c810ed0
// DECLARATION-TEXT-LENGTH: 731
// RESOLVED-ALIAS-GRAPH-SHA256: 568f6cffcfc05e55ef4ac8d535fe0493fe045f84b5eb1fd194c5103e35b423a2
// RESOLVED-ALIAS-PARTS: type:editor_main_IRange@10187, interface:IRange@904
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaTopLevelIRange {}

// PATH: topLevel.IScrollEvent
// ORDINAL: 29
// DISPOSITION: retained-native-event-adaptation
// SOURCE-KIND: type-export
// RESOLVED-KIND: interface
// BASELINE: IScrollEvent
// BASELINE-LOCAL: editor_main_IScrollEvent
// SOURCE-LINE: 10220
// DECLARATION-SHA256: 209565d6acc43aed691e1f123f6308a15eb050a4e498f1b5e1bd4d9c8c810ed0
// DECLARATION-TEXT-LENGTH: 731
// RESOLVED-ALIAS-GRAPH-SHA256: c20910f9fc21f2b9272e5961415d4d91778b00a1885fca70974b72677b46c3dd
// RESOLVED-ALIAS-PARTS: type:editor_main_IScrollEvent@10188, interface:IScrollEvent@799
//   - event adaptation: browser keyboard/mouse/scroll -> immutable Mona native event snapshot
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaTopLevelIScrollEvent {}

// PATH: topLevel.ISelection
// ORDINAL: 30
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: type-export
// RESOLVED-KIND: interface
// BASELINE: ISelection
// BASELINE-LOCAL: editor_main_ISelection
// SOURCE-LINE: 10220
// DECLARATION-SHA256: 209565d6acc43aed691e1f123f6308a15eb050a4e498f1b5e1bd4d9c8c810ed0
// DECLARATION-TEXT-LENGTH: 731
// RESOLVED-ALIAS-GRAPH-SHA256: d5062882fe73bbc395aaee388184771680c77637d02ca98dc9269922f148bb5c
// RESOLVED-ALIAS-PARTS: type:editor_main_ISelection@10189, interface:ISelection@1098
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaTopLevelISelection {}

// PATH: topLevel.ITrustedTypePolicy
// ORDINAL: 31
// DISPOSITION: cut-web-runtime-policy
// SOURCE-KIND: type-export
// BASELINE: ITrustedTypePolicy
// BASELINE-LOCAL: editor_main_ITrustedTypePolicy
// SOURCE-LINE: 10220
// DECLARATION-SHA256: 209565d6acc43aed691e1f123f6308a15eb050a4e498f1b5e1bd4d9c8c810ed0
// DECLARATION-TEXT-LENGTH: 731
// RESOLVED-ALIAS-GRAPH-SHA256: 009c39532e4d97b9cd5c629024daaa8d5fa5a90c9771cafb300c5875cc9a74b9
// RESOLVED-ALIAS-PARTS: type:editor_main_ITrustedTypePolicy@10190, interface:ITrustedTypePolicy@325
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: web-only runtime policy with no native host equivalent

// PATH: topLevel.ITrustedTypePolicyOptions
// ORDINAL: 32
// DISPOSITION: cut-web-runtime-policy
// SOURCE-KIND: type-export
// BASELINE: ITrustedTypePolicyOptions
// BASELINE-LOCAL: editor_main_ITrustedTypePolicyOptions
// SOURCE-LINE: 10220
// DECLARATION-SHA256: 209565d6acc43aed691e1f123f6308a15eb050a4e498f1b5e1bd4d9c8c810ed0
// DECLARATION-TEXT-LENGTH: 731
// RESOLVED-ALIAS-GRAPH-SHA256: bb42d06b7a38d0ff1ca2bd6de5ddaf6df1e9135fea784341496ef9b8b89307d0
// RESOLVED-ALIAS-PARTS: type:editor_main_ITrustedTypePolicyOptions@10191, interface:ITrustedTypePolicyOptions@319
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: web-only runtime policy with no native host equivalent

// PATH: topLevel.MarkdownStringTrustedOptions
// ORDINAL: 33
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: type-export
// RESOLVED-KIND: interface
// BASELINE: MarkdownStringTrustedOptions
// BASELINE-LOCAL: editor_main_MarkdownStringTrustedOptions
// SOURCE-LINE: 10220
// DECLARATION-SHA256: 209565d6acc43aed691e1f123f6308a15eb050a4e498f1b5e1bd4d9c8c810ed0
// DECLARATION-TEXT-LENGTH: 731
// RESOLVED-ALIAS-GRAPH-SHA256: 209e4cc3b77b740969470d095f435a10617b12e2d059403c1793751c1bb44af0
// RESOLVED-ALIAS-PARTS: type:editor_main_MarkdownStringTrustedOptions@10196, interface:MarkdownStringTrustedOptions@760
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaTopLevelMarkdownStringTrustedOptions {}

// PATH: topLevel.Thenable
// ORDINAL: 34
// DISPOSITION: retained-swift-async-adaptation
// SOURCE-KIND: type-export
// RESOLVED-KIND: type
// BASELINE: Thenable
// BASELINE-LOCAL: editor_main_Thenable
// SOURCE-LINE: 10220
// DECLARATION-SHA256: 209565d6acc43aed691e1f123f6308a15eb050a4e498f1b5e1bd4d9c8c810ed0
// DECLARATION-TEXT-LENGTH: 731
// RESOLVED-ALIAS-GRAPH-SHA256: 064caef302de3b1e5a54271b861adb1c243cc8fecacf02dfaf1a81f86d0161e0
// RESOLVED-ALIAS-PARTS: type:editor_main_Thenable@10209, type:Thenable@288
//   - async adaptation: Thenable -> async / Task
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
//   - throws: disposal/failable paths throw
public struct MonaTopLevelThenable {}

// PATH: topLevel.UriComponents
// ORDINAL: 35
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: type-export
// RESOLVED-KIND: interface
// BASELINE: UriComponents
// BASELINE-LOCAL: editor_main_UriComponents
// SOURCE-LINE: 10220
// DECLARATION-SHA256: 209565d6acc43aed691e1f123f6308a15eb050a4e498f1b5e1bd4d9c8c810ed0
// DECLARATION-TEXT-LENGTH: 731
// RESOLVED-ALIAS-GRAPH-SHA256: 07972220f6bff28a334f925d30b3f8bf9cad0e919e9a80cb30621bcbbeeb9c91
// RESOLVED-ALIAS-PARTS: type:editor_main_UriComponents@10214, interface:UriComponents@530
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaTopLevelUriComponents {}

// PATH: editor.onDidCreateEditor
// ORDINAL: 1
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: onDidCreateEditor
// SOURCE-LINE: 1234
// DECLARATION-SHA256: fb28f3dde99b8171692e99221858670c8594cef446096c81ac0f444b8047f01b
// DECLARATION-TEXT-LENGTH: 92
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaEditorOnDidCreateEditor() async throws {}

// PATH: editor.onDidCreateDiffEditor
// ORDINAL: 2
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: onDidCreateDiffEditor
// SOURCE-LINE: 1240
// DECLARATION-SHA256: d84131dfbdbef0ae6b3613d8e3063b6f08359439c88017e000c654494548e936
// DECLARATION-TEXT-LENGTH: 96
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaEditorOnDidCreateDiffEditor() async throws {}

// PATH: editor.getEditors
// ORDINAL: 3
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: getEditors
// SOURCE-LINE: 1245
// DECLARATION-SHA256: 027ae61d94e50cf2be464e691d0b5e4deff019112a0188199d06e3060dc212be
// DECLARATION-TEXT-LENGTH: 53
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaEditorGetEditors() async throws {}

// PATH: editor.getDiffEditors
// ORDINAL: 4
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: getDiffEditors
// SOURCE-LINE: 1250
// DECLARATION-SHA256: c5bd1a9ec2e8d279fd708fa4e601ef5c23a10510cffc84ab9c086a4a6befe918
// DECLARATION-TEXT-LENGTH: 57
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaEditorGetDiffEditors() async throws {}

// PATH: editor.createMultiFileDiffEditor
// ORDINAL: 6
// DISPOSITION: retained-native-replacement
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: createMultiFileDiffEditor
// SOURCE-LINE: 1259
// DECLARATION-SHA256: ebfd3032a3df88a1dfd47b37c21f18445cc71541f2e14a193c72844426703285
// DECLARATION-TEXT-LENGTH: 108
// WEB-TYPE-REFERENCES: HTMLElement
//   - native replacement: DOM-returning function -> typed native return
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaEditorCreateMultiFileDiffEditor() async throws {}

// PATH: editor.ICommandDescriptor
// ORDINAL: 7
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: ICommandDescriptor
// SOURCE-LINE: 1264
// DECLARATION-SHA256: f069bd5cdab6cae6eaf9fc442fe6491e7ab331cf0bd53c76e0acd94f0260b3af
// DECLARATION-TEXT-LENGTH: 223
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorICommandDescriptor {}

// PATH: editor.addCommand
// ORDINAL: 8
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: addCommand
// SOURCE-LINE: 1278
// DECLARATION-SHA256: 153281d8d14f22c380ab9c718c3529b2d52e3acad8b36ddd0c85bd402b86f23f
// DECLARATION-TEXT-LENGTH: 72
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaEditorAddCommand() async throws {}

// PATH: editor.addEditorAction
// ORDINAL: 9
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: addEditorAction
// SOURCE-LINE: 1283
// DECLARATION-SHA256: 75dd01d317d53d347496d673cef930c595a4fbb71dd38a3ed7eead3fc1e68d5b
// DECLARATION-TEXT-LENGTH: 76
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaEditorAddEditorAction() async throws {}

// PATH: editor.IKeybindingRule
// ORDINAL: 10
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IKeybindingRule
// SOURCE-LINE: 1288
// DECLARATION-SHA256: ce3ab3d3f9cc5f3e6ad74b00249200dabc2a5fd1cb14e9fafef7598536fe63e2
// DECLARATION-TEXT-LENGTH: 131
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIKeybindingRule {}

// PATH: editor.addKeybindingRule
// ORDINAL: 11
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: addKeybindingRule
// SOURCE-LINE: 1298
// DECLARATION-SHA256: 56d8c67cff161cf39440b60ea5321102f452859d50225dd0f8537b5a865e2fc4
// DECLARATION-TEXT-LENGTH: 70
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaEditorAddKeybindingRule() async throws {}

// PATH: editor.addKeybindingRules
// ORDINAL: 12
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: addKeybindingRules
// SOURCE-LINE: 1303
// DECLARATION-SHA256: 10a0c04c62fd69bedbcaeaa38598e85c9bf7816136200139daa9060e8b51c753
// DECLARATION-TEXT-LENGTH: 74
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaEditorAddKeybindingRules() async throws {}

// PATH: editor.createModel
// ORDINAL: 13
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: createModel
// SOURCE-LINE: 1309
// DECLARATION-SHA256: c3a3fdacbb9fcd6b363df650446106ddb348178d1ef2a4d43bd51a317fe45f3b
// DECLARATION-TEXT-LENGTH: 85
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaEditorCreateModel(
    value: String,
    language: String? = nil,
    uri: MonaURI? = nil
) async throws -> MonaCodeModel {
    return MonaGlobalModelRegistry.shared.createModel(value: value, language: language, uri: uri)
}

// PATH: editor.setModelLanguage
// ORDINAL: 14
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: setModelLanguage
// SOURCE-LINE: 1314
// DECLARATION-SHA256: d8df5c140c50a338573830658220d257fa196081aafd8f9c037e06ea57e8cde6
// DECLARATION-TEXT-LENGTH: 88
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaEditorSetModelLanguage(model: MonaCodeModel, languageId: String) async throws {
    MonaGlobalModelRegistry.shared.setLanguage(languageId, for: model)
}

// PATH: editor.setModelMarkers
// ORDINAL: 15
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: setModelMarkers
// SOURCE-LINE: 1319
// DECLARATION-SHA256: 61ca07b01962638bef1dd7097843a365c3ab34dd1cce5c1beddfdae888440777
// DECLARATION-TEXT-LENGTH: 96
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaEditorSetModelMarkers(
    model: MonaCodeModel,
    owner: String,
    markers: [MonaMarker]
) async throws {
    MonaMarkerService.shared.setModelMarkers(markers, for: model, owner: owner)
}

// PATH: editor.removeAllMarkers
// ORDINAL: 16
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: removeAllMarkers
// SOURCE-LINE: 1324
// DECLARATION-SHA256: a1cee37e884559c2e7d8a32f21b6e3b96581a4931e52fc1ac923b68e5fb418c3
// DECLARATION-TEXT-LENGTH: 54
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaEditorRemoveAllMarkers(owner: String? = nil) async throws {
    MonaMarkerService.shared.removeAllMarkers(owner: owner)
}

// PATH: editor.getModelMarkers
// ORDINAL: 17
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: getModelMarkers
// SOURCE-LINE: 1331
// DECLARATION-SHA256: ecdacecb2a3474a39a9dffa0b262b12e37abd4a13ee3e97515c2a1cd369849d8
// DECLARATION-TEXT-LENGTH: 110
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaEditorGetModelMarkers(for model: MonaCodeModel) async throws -> [MonaMarker] {
    return MonaMarkerService.shared.getModelMarkers(for: model)
}

// PATH: editor.onDidChangeMarkers
// ORDINAL: 18
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: onDidChangeMarkers
// SOURCE-LINE: 1341
// DECLARATION-SHA256: e66e5f5d3ac7b2c6c4dbb5884afafce670e8949b6f66c693e430e03312d95296
// DECLARATION-TEXT-LENGTH: 87
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaEditorOnDidChangeMarkers() async throws -> MonaEvent<MonaMarkerChangeEvent> {
    return MonaMarkerService.shared.onDidChangeMarkers
}

// PATH: editor.getModel
// ORDINAL: 19
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: getModel
// SOURCE-LINE: 1346
// DECLARATION-SHA256: cf7fbb321c958fa1497efe992a797248f08e33fd04743f1430dc9ae996e53afa
// DECLARATION-TEXT-LENGTH: 54
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaEditorGetModel(uri: MonaURI) async throws -> MonaCodeModel? {
    return MonaGlobalModelRegistry.shared.model(for: uri)
}

// PATH: editor.getModels
// ORDINAL: 20
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: getModels
// SOURCE-LINE: 1351
// DECLARATION-SHA256: 5924e5f5037a893d522b5df618ceaf7d5a9d9149a09216a160f0be5262c1f446
// DECLARATION-TEXT-LENGTH: 42
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaEditorGetModels() async throws -> [MonaCodeModel] {
    return MonaGlobalModelRegistry.shared.models()
}

// PATH: editor.onDidCreateModel
// ORDINAL: 21
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: onDidCreateModel
// SOURCE-LINE: 1357
// DECLARATION-SHA256: 14d88646baa3112927cfc1732f16e4fccb6e25136ecc0a539a4978470d7cab8e
// DECLARATION-TEXT-LENGTH: 85
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaEditorOnDidCreateModel() async throws {}

// PATH: editor.onWillDisposeModel
// ORDINAL: 22
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: onWillDisposeModel
// SOURCE-LINE: 1363
// DECLARATION-SHA256: 0f78a6b8df215762254e1e74016793b49c9a1f3950e1bf9d1da585bb6b0e8bd2
// DECLARATION-TEXT-LENGTH: 87
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaEditorOnWillDisposeModel() async throws {}

// PATH: editor.onDidChangeModelLanguage
// ORDINAL: 23
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: onDidChangeModelLanguage
// SOURCE-LINE: 1369
// DECLARATION-SHA256: 3e45a24f8606c9be0665917a89a9b5298772a00c878d37c210e0f17da5f1452d
// DECLARATION-TEXT-LENGTH: 145
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaEditorOnDidChangeModelLanguage() async throws {}

// PATH: editor.createWebWorker
// ORDINAL: 24
// DISPOSITION: cut-webworker-api
// SOURCE-KIND: function
// BASELINE: createWebWorker
// SOURCE-LINE: 1378
// DECLARATION-SHA256: 9bed67610a8d8e15013a591c9ea60dde5c020ca88f519b0110ffb9095808ef0b
// DECLARATION-TEXT-LENGTH: 103
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: WebWorker API is cut; the three-interface worker namespace is removed

// PATH: editor.colorizeElement
// ORDINAL: 25
// DISPOSITION: retained-native-replacement
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: colorizeElement
// SOURCE-LINE: 1383
// DECLARATION-SHA256: 4598e8833058299977b56458044b6cafebb976c91de347d89dda7852b08af002
// DECLARATION-TEXT-LENGTH: 104
// WEB-TYPE-REFERENCES: HTMLElement
//   - native replacement: DOM-returning function -> typed native return
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaEditorColorizeElement() async throws {}

// PATH: editor.colorize
// ORDINAL: 26
// DISPOSITION: retained-native-replacement
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: colorize
// SOURCE-LINE: 1388
// DECLARATION-SHA256: cf86133cbc215ecf2d33b2b9dbe024da9dcd873b95c8a31a586fdf7de33f13d9
// DECLARATION-TEXT-LENGTH: 104
//   - native replacement: DOM-returning function -> typed native return
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaEditorColorize() async throws {}

// PATH: editor.colorizeModelLine
// ORDINAL: 27
// DISPOSITION: retained-native-replacement
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: colorizeModelLine
// SOURCE-LINE: 1393
// DECLARATION-SHA256: a5afa617115602921151a23c8151fb99d17dddf07b40849059299b2fc60043af
// DECLARATION-TEXT-LENGTH: 99
//   - native replacement: DOM-returning function -> typed native return
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaEditorColorizeModelLine() async throws {}

// PATH: editor.tokenize
// ORDINAL: 28
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: tokenize
// SOURCE-LINE: 1398
// DECLARATION-SHA256: 8c001c300e813777bfec14b3194d02c62ed757049ee3a06459bfd46faea2ca6d
// DECLARATION-TEXT-LENGTH: 70
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaEditorTokenize() async throws {}

// PATH: editor.defineTheme
// ORDINAL: 29
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: defineTheme
// SOURCE-LINE: 1403
// DECLARATION-SHA256: 0bde7948ef5052b004a549ebb7a9e5d97edf3a6da86b25084ba725c3ae2bd3a9
// DECLARATION-TEXT-LENGTH: 86
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaEditorDefineTheme() async throws {}

// PATH: editor.setTheme
// ORDINAL: 30
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: setTheme
// SOURCE-LINE: 1408
// DECLARATION-SHA256: c189cb7ef6f4678f41b0ca375b5f443a754db9cf4ce4a55b37e529642528abc9
// DECLARATION-TEXT-LENGTH: 50
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaEditorSetTheme() async throws {}

// PATH: editor.remeasureFonts
// ORDINAL: 31
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: remeasureFonts
// SOURCE-LINE: 1413
// DECLARATION-SHA256: 70f1d9bad4dc9e5f7fba33d8393186ef6f41404379758b15540c8db01f041a79
// DECLARATION-TEXT-LENGTH: 39
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaEditorRemeasureFonts() async throws {}

// PATH: editor.registerCommand
// ORDINAL: 32
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: registerCommand
// SOURCE-LINE: 1418
// DECLARATION-SHA256: 836a6757784185b27504031fe8059f840c59ebc468986802db7d30eb5f40ba16
// DECLARATION-TEXT-LENGTH: 107
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaEditorRegisterCommand() async throws {}

// PATH: editor.ILinkOpener
// ORDINAL: 33
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: ILinkOpener
// SOURCE-LINE: 1420
// DECLARATION-SHA256: e2033fb91f9780af65d7b4f69453b22b4b59054a6b586654dcbf7289d09a3c9f
// DECLARATION-TEXT-LENGTH: 84
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorILinkOpener {}

// PATH: editor.registerLinkOpener
// ORDINAL: 34
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: registerLinkOpener
// SOURCE-LINE: 1430
// DECLARATION-SHA256: 1777d38e17d512dc7841346b29243a428effe538e17bb7bc3854b6faf75da8a8
// DECLARATION-TEXT-LENGTH: 69
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaEditorRegisterLinkOpener() async throws {}

// PATH: editor.ICodeEditorOpener
// ORDINAL: 35
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: ICodeEditorOpener
// SOURCE-LINE: 1436
// DECLARATION-SHA256: 99fda3b60dabe4e99486bbd04042c693c1e9bc2c5802bcb5fe8a58048ac15caf
// DECLARATION-TEXT-LENGTH: 685
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorICodeEditorOpener {}

// PATH: editor.registerEditorOpener
// ORDINAL: 36
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: registerEditorOpener
// SOURCE-LINE: 1455
// DECLARATION-SHA256: 53a4ae7464385586bec1be505135f8bc450c3b135af0f6f9ceed67013d030392
// DECLARATION-TEXT-LENGTH: 77
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaEditorRegisterEditorOpener() async throws {}

// PATH: editor.BuiltinTheme
// ORDINAL: 37
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: type
// RESOLVED-KIND: type
// BASELINE: BuiltinTheme
// SOURCE-LINE: 1457
// DECLARATION-SHA256: a8f4cf99b32d91880349448a9e918e93903fde112d4970389ceba69df23fbf6a
// DECLARATION-TEXT-LENGTH: 70
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public struct MonaEditorBuiltinTheme {}

// PATH: editor.IStandaloneThemeData
// ORDINAL: 38
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IStandaloneThemeData
// SOURCE-LINE: 1459
// DECLARATION-SHA256: 378302cf96028e9fd6f462ee752cf01948c3dbd47bad080671bb9b792fc4eb41
// DECLARATION-TEXT-LENGTH: 165
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIStandaloneThemeData {}

// PATH: editor.IColors
// ORDINAL: 39
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: type
// RESOLVED-KIND: type
// BASELINE: IColors
// SOURCE-LINE: 1467
// DECLARATION-SHA256: 21031283dddfb0cbb5cd15258b57e28525855501ca4f39313f7db0070b021e5a
// DECLARATION-TEXT-LENGTH: 56
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public struct MonaEditorIColors {}

// PATH: editor.ITokenThemeRule
// ORDINAL: 40
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: ITokenThemeRule
// SOURCE-LINE: 1471
// DECLARATION-SHA256: 94245fe3232d1fa2440537638fc8d611bb307aa7f76a3eff3a75cb8da3e56189
// DECLARATION-TEXT-LENGTH: 122
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorITokenThemeRule {}

// PATH: editor.MonacoWebWorker
// ORDINAL: 41
// DISPOSITION: cut-webworker-api
// SOURCE-KIND: interface
// BASELINE: MonacoWebWorker
// SOURCE-LINE: 1481
// DECLARATION-SHA256: 295f43d21330a73bf5874c374bbff11fabe6551bde4bb61cea674c7ab19cc162
// DECLARATION-TEXT-LENGTH: 426
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: WebWorker API is cut; the three-interface worker namespace is removed

// PATH: editor.IInternalWebWorkerOptions
// ORDINAL: 42
// DISPOSITION: cut-webworker-api
// SOURCE-KIND: interface
// BASELINE: IInternalWebWorkerOptions
// SOURCE-LINE: 1497
// DECLARATION-SHA256: 4cb29b8a9c04bf91e400846b27aa24b21f970c68d0ec90b83e63d2ce256f28b3
// DECLARATION-TEXT-LENGTH: 397
// WEB-TYPE-REFERENCES: Worker
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: WebWorker API is cut; the three-interface worker namespace is removed

// PATH: editor.IActionDescriptor
// ORDINAL: 43
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IActionDescriptor
// SOURCE-LINE: 1516
// DECLARATION-SHA256: 43102f6df93377995012dfdfbae7f9c14eed85523132519dc69ebbfd61fcb078
// DECLARATION-TEXT-LENGTH: 1394
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIActionDescriptor {}

// PATH: editor.IGlobalEditorOptions
// ORDINAL: 44
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IGlobalEditorOptions
// SOURCE-LINE: 1561
// DECLARATION-SHA256: 5d9456bddce7c80a1b94f8758110cc2daec40db661d6ac1f434707b0f6da19d9
// DECLARATION-TEXT-LENGTH: 2633
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIGlobalEditorOptions {}

// PATH: editor.IStandaloneDiffEditorConstructionOptions
// ORDINAL: 46
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IStandaloneDiffEditorConstructionOptions
// SOURCE-LINE: 1679
// DECLARATION-SHA256: 03b35eaa8f9dc60218baa8eb20a39603775a5bbe23f32f6d7dad3679cf074ae5
// DECLARATION-TEXT-LENGTH: 711
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIStandaloneDiffEditorConstructionOptions {}

// PATH: editor.IStandaloneCodeEditor
// ORDINAL: 47
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IStandaloneCodeEditor
// SOURCE-LINE: 1695
// DECLARATION-SHA256: 8ce1342fce1a616fc131599f1ef2bd468e1ceede8639100d4e2372c3cadd56db
// DECLARATION-TEXT-LENGTH: 398
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIStandaloneCodeEditor {}

// PATH: editor.IStandaloneDiffEditor
// ORDINAL: 48
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IStandaloneDiffEditor
// SOURCE-LINE: 1702
// DECLARATION-SHA256: 6174d25f0f019f63a8c579dceb142e6d773d1812b21737d40e83a043eb83fa66
// DECLARATION-TEXT-LENGTH: 416
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIStandaloneDiffEditor {}

// PATH: editor.ICommandHandler
// ORDINAL: 49
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: ICommandHandler
// SOURCE-LINE: 1709
// DECLARATION-SHA256: 7a8cb7f720e9caa70d0907c88a20a4867b17637f665cbf884c8a638a0ea4d933
// DECLARATION-TEXT-LENGTH: 63
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorICommandHandler {}

// PATH: editor.ILocalizedString
// ORDINAL: 50
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: ILocalizedString
// SOURCE-LINE: 1712
// DECLARATION-SHA256: 4115791599ca6b49f4f994a79cd2726fb839981bae24370e4c74a9de19d3b555
// DECLARATION-TEXT-LENGTH: 75
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorILocalizedString {}

// PATH: editor.ICommandMetadata
// ORDINAL: 51
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: ICommandMetadata
// SOURCE-LINE: 1716
// DECLARATION-SHA256: ee25a516b3a6b592e6b2ac47fc7bbcf4d7aea8dbf7fe0830c3aee828f1575a41
// DECLARATION-TEXT-LENGTH: 89
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorICommandMetadata {}

// PATH: editor.IContextKey
// ORDINAL: 52
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IContextKey
// SOURCE-LINE: 1720
// DECLARATION-SHA256: b310be0ceec0f155d3603828b656d64d5bfed44b13af026681c796ac6b2121d2
// DECLARATION-TEXT-LENGTH: 142
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIContextKey {}

// PATH: editor.ContextKeyValue
// ORDINAL: 53
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: type
// RESOLVED-KIND: type
// BASELINE: ContextKeyValue
// SOURCE-LINE: 1726
// DECLARATION-SHA256: 925301aa90e7f675502dde45916506ccae362e815a2b5ec31e62636be316a109
// DECLARATION-TEXT-LENGTH: 192
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public struct MonaEditorContextKeyValue {}

// PATH: editor.IEditorOverrideServices
// ORDINAL: 54
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IEditorOverrideServices
// SOURCE-LINE: 1728
// DECLARATION-SHA256: 64df9e689a6a074df63fd423270176d4a7443766a08983a39330c63dac985463
// DECLARATION-TEXT-LENGTH: 73
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIEditorOverrideServices {}

// PATH: editor.IMarker
// ORDINAL: 55
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IMarker
// SOURCE-LINE: 1732
// DECLARATION-SHA256: 62c002493e1f4932f2c610329a59ae4ef190d3aa452390deb8825320fb493f20
// DECLARATION-TEXT-LENGTH: 410
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIMarker {}

// PATH: editor.IMarkerData
// ORDINAL: 56
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IMarkerData
// SOURCE-LINE: 1755
// DECLARATION-SHA256: efc29b9939afc7e0fb1a916aa097947ddd1347f35299536af3b7d907fbc3c73d
// DECLARATION-TEXT-LENGTH: 380
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIMarkerData {}

// PATH: editor.IRelatedInformation
// ORDINAL: 57
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IRelatedInformation
// SOURCE-LINE: 1776
// DECLARATION-SHA256: a8db35b43de9eb686c2ec574e2f5edc647fc651496ba140e450d481588703eb8
// DECLARATION-TEXT-LENGTH: 173
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIRelatedInformation {}

// PATH: editor.IColorizerOptions
// ORDINAL: 58
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IColorizerOptions
// SOURCE-LINE: 1785
// DECLARATION-SHA256: 70511f847c0c93d8832ad98c0005bd9e2f0717a029c13a08979f9eb19372839e
// DECLARATION-TEXT-LENGTH: 59
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIColorizerOptions {}

// PATH: editor.IColorizerElementOptions
// ORDINAL: 59
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IColorizerElementOptions
// SOURCE-LINE: 1789
// DECLARATION-SHA256: 38547180dbe3b8ad9571234988047867b356a04f64ca10fc348883caf129eec3
// DECLARATION-TEXT-LENGTH: 111
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIColorizerElementOptions {}

// PATH: editor.ScrollbarVisibility
// ORDINAL: 60
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: ScrollbarVisibility
// SOURCE-LINE: 1794
// DECLARATION-SHA256: 2b51afa12762084bde5cf4480889f277e82d0727c4a52e417a0b0122a18219ed
// DECLARATION-TEXT-LENGTH: 76
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaEditorScrollbarVisibility {}

// PATH: editor.ThemeColor
// ORDINAL: 61
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: ThemeColor
// SOURCE-LINE: 1800
// DECLARATION-SHA256: 5da86bd21c47b48e8ceb82c2946d0161915b76cd4573d460156fc9269f3241a3
// DECLARATION-TEXT-LENGTH: 46
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorThemeColor {}

// PATH: editor.ThemeIcon
// ORDINAL: 62
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: ThemeIcon
// SOURCE-LINE: 1804
// DECLARATION-SHA256: fe7bfd09760fb9e0b7f7f91e58e0869d29a8605c48df646aa823cecef822541a
// DECLARATION-TEXT-LENGTH: 85
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorThemeIcon {}

// PATH: editor.ISingleEditOperation
// ORDINAL: 63
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: ISingleEditOperation
// SOURCE-LINE: 1813
// DECLARATION-SHA256: 122820b9fdc058cda013832ed1520b79437bbb1364620140263da83f43c30b88
// DECLARATION-TEXT-LENGTH: 466
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorISingleEditOperation {}

// PATH: editor.IWordAtPosition
// ORDINAL: 64
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IWordAtPosition
// SOURCE-LINE: 1832
// DECLARATION-SHA256: 6b21cd83a6337e90a3d6d5541f6c7767fc0d3f40f3b1319be5f6b2fb483cf53b
// DECLARATION-TEXT-LENGTH: 251
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIWordAtPosition {}

// PATH: editor.OverviewRulerLane
// ORDINAL: 65
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: OverviewRulerLane
// SOURCE-LINE: 1850
// DECLARATION-SHA256: 5c81fe100d9105151ecce7e34c9d364c51aee5dfc0246d011e4771de605ef590
// DECLARATION-TEXT-LENGTH: 84
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaEditorOverviewRulerLane {}

// PATH: editor.GlyphMarginLane
// ORDINAL: 66
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: GlyphMarginLane
// SOURCE-LINE: 1860
// DECLARATION-SHA256: 88587d1524781b16cd44ed2e527fa9144ef6fa138ee5dca2e45ae268628c1df6
// DECLARATION-TEXT-LENGTH: 70
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaEditorGlyphMarginLane {}

// PATH: editor.IGlyphMarginLanesModel
// ORDINAL: 67
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IGlyphMarginLanesModel
// SOURCE-LINE: 1866
// DECLARATION-SHA256: 9eb89173a859b227a288b22b69f6d2065c73f79aa577fac8ee5a6fc4527c043d
// DECLARATION-TEXT-LENGTH: 718
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIGlyphMarginLanesModel {}

// PATH: editor.MinimapPosition
// ORDINAL: 68
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: MinimapPosition
// SOURCE-LINE: 1890
// DECLARATION-SHA256: 1e48c9ef6a1baa006ef00ef3653ba620fddf4b1bc1b0c2d6878e46490215fa5b
// DECLARATION-TEXT-LENGTH: 59
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaEditorMinimapPosition {}

// PATH: editor.MinimapSectionHeaderStyle
// ORDINAL: 69
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: MinimapSectionHeaderStyle
// SOURCE-LINE: 1898
// DECLARATION-SHA256: 519bf37e020c0521cad6ce488471219bc3f139136af61bb55646c81792ff44ef
// DECLARATION-TEXT-LENGTH: 73
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaEditorMinimapSectionHeaderStyle {}

// PATH: editor.IDecorationOptions
// ORDINAL: 70
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IDecorationOptions
// SOURCE-LINE: 1903
// DECLARATION-SHA256: 65348808f90b8e7dd66b85866650af6d872c7dd36ae07f03befaa2afecee59e7
// DECLARATION-TEXT-LENGTH: 335
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIDecorationOptions {}

// PATH: editor.IModelDecorationGlyphMarginOptions
// ORDINAL: 71
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IModelDecorationGlyphMarginOptions
// SOURCE-LINE: 1916
// DECLARATION-SHA256: 210b101d2597c0011f997be9acd598cf25194f97b7ebd6af92a53e60dca20e85
// DECLARATION-TEXT-LENGTH: 293
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIModelDecorationGlyphMarginOptions {}

// PATH: editor.IModelDecorationOverviewRulerOptions
// ORDINAL: 72
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IModelDecorationOverviewRulerOptions
// SOURCE-LINE: 1931
// DECLARATION-SHA256: 0550c271f01644928aee489abd299c51e1fe24dad119926eed8d6b4635ad3e62
// DECLARATION-TEXT-LENGTH: 169
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIModelDecorationOverviewRulerOptions {}

// PATH: editor.IModelDecorationMinimapOptions
// ORDINAL: 73
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IModelDecorationMinimapOptions
// SOURCE-LINE: 1941
// DECLARATION-SHA256: 3d16337dc60e7538c0f6838f2748eb7cab9bb6b25951e656f62acab933a8642b
// DECLARATION-TEXT-LENGTH: 405
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIModelDecorationMinimapOptions {}

// PATH: editor.IModelDecorationOptions
// ORDINAL: 74
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IModelDecorationOptions
// SOURCE-LINE: 1959
// DECLARATION-SHA256: a058f1a4265e60f9c92f7c694e0640b5ed1dfc66d4d8612b429a31f441fa250b
// DECLARATION-TEXT-LENGTH: 4579
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIModelDecorationOptions {}

// PATH: editor.TextDirection
// ORDINAL: 75
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: TextDirection
// SOURCE-LINE: 2099
// DECLARATION-SHA256: 7b65ac48c1e70b18df6e992cf3bbb4e612c391c9d591c8bd05ea21b768b97297
// DECLARATION-TEXT-LENGTH: 51
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaEditorTextDirection {}

// PATH: editor.InjectedTextOptions
// ORDINAL: 76
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: InjectedTextOptions
// SOURCE-LINE: 2107
// DECLARATION-SHA256: 01d906398ac94f6e122f79a0643d39d4a8db63e0cff9d536b9a99358424b05c9
// DECLARATION-TEXT-LENGTH: 781
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorInjectedTextOptions {}

// PATH: editor.InjectedTextCursorStops
// ORDINAL: 77
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: InjectedTextCursorStops
// SOURCE-LINE: 2132
// DECLARATION-SHA256: df173cc031d239748cd6457d8053e5e17fb5b2178de38ffa99c81709743573ad
// DECLARATION-TEXT-LENGTH: 88
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaEditorInjectedTextCursorStops {}

// PATH: editor.IModelDeltaDecoration
// ORDINAL: 78
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IModelDeltaDecoration
// SOURCE-LINE: 2142
// DECLARATION-SHA256: a3b72aa78f276db3da6624e3c1a1b7bd4c744c43b432353542450a273421c20f
// DECLARATION-TEXT-LENGTH: 206
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIModelDeltaDecoration {}

// PATH: editor.IModelDecoration
// ORDINAL: 79
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IModelDecoration
// SOURCE-LINE: 2156
// DECLARATION-SHA256: d2fe2512ca2f1b640dbaf77b693652a7615fb0127293a870e35ef4b62cd8061b
// DECLARATION-TEXT-LENGTH: 369
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIModelDecoration {}

// PATH: editor.EndOfLinePreference
// ORDINAL: 80
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: EndOfLinePreference
// SOURCE-LINE: 2178
// DECLARATION-SHA256: 765c548a25aeb45b2a4ad240b2f177517f42f07272a758e0202d135dacebe219
// DECLARATION-TEXT-LENGTH: 308
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaEditorEndOfLinePreference {}

// PATH: editor.DefaultEndOfLine
// ORDINAL: 81
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: DefaultEndOfLine
// SOURCE-LINE: 2196
// DECLARATION-SHA256: 446709554ac34e28cfc2100b04938d3a10ee03002cc14319e9c9600e449e4270
// DECLARATION-TEXT-LENGTH: 208
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaEditorDefaultEndOfLine {}

// PATH: editor.EndOfLineSequence
// ORDINAL: 82
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: EndOfLineSequence
// SOURCE-LINE: 2210
// DECLARATION-SHA256: 7375e714966d8a555e434fa2ac8d45980cdef9ab9584ee00e60303f7e60c8f70
// DECLARATION-TEXT-LENGTH: 209
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaEditorEndOfLineSequence {}

// PATH: editor.IIdentifiedSingleEditOperation
// ORDINAL: 83
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IIdentifiedSingleEditOperation
// SOURCE-LINE: 2224
// DECLARATION-SHA256: 5c873e78dfb47363dafd66cbfc82b121212b17c3e35d8a915e2ac4c5457b50fa
// DECLARATION-TEXT-LENGTH: 81
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIIdentifiedSingleEditOperation {}

// PATH: editor.IValidEditOperation
// ORDINAL: 84
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IValidEditOperation
// SOURCE-LINE: 2227
// DECLARATION-SHA256: 7fed82c5b8b7462c0b6aac41fe25fa5591378e4d41bece53be58fc039b2ee171
// DECLARATION-TEXT-LENGTH: 247
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIValidEditOperation {}

// PATH: editor.ICursorStateComputer
// ORDINAL: 85
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: ICursorStateComputer
// SOURCE-LINE: 2241
// DECLARATION-SHA256: 3e76e13cfd6f06b4b5fa0cd99f21d30b67b9e624c187963be3f38d0cb097eed7
// DECLARATION-TEXT-LENGTH: 232
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorICursorStateComputer {}

// PATH: editor.TextModelResolvedOptions
// ORDINAL: 86
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: class
// RESOLVED-KIND: class
// BASELINE: TextModelResolvedOptions
// SOURCE-LINE: 2248
// DECLARATION-SHA256: 7c9bc8783692d3f2dd53d948d05343c2ff28469c98d7d1cd5734ad2a974a4ba3
// DECLARATION-TEXT-LENGTH: 379
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - reference identity: @MainActor final reference type; non-Sendable
public final class MonaEditorTextModelResolvedOptions {}

// PATH: editor.BracketPairColorizationOptions
// ORDINAL: 87
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: BracketPairColorizationOptions
// SOURCE-LINE: 2259
// DECLARATION-SHA256: 983b714992b86bfa53f32b79c2104ecde8dc61c40307899e2d4496d871706c2f
// DECLARATION-TEXT-LENGTH: 119
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorBracketPairColorizationOptions {}

// PATH: editor.ITextModelUpdateOptions
// ORDINAL: 88
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: ITextModelUpdateOptions
// SOURCE-LINE: 2264
// DECLARATION-SHA256: 60d658d587aa0661b353468a1f484bcbc400536bf2015de8766e9b3a74e9978d
// DECLARATION-TEXT-LENGTH: 221
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorITextModelUpdateOptions {}

// PATH: editor.FindMatch
// ORDINAL: 89
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: class
// RESOLVED-KIND: class
// BASELINE: FindMatch
// SOURCE-LINE: 2272
// DECLARATION-SHA256: efaf6e936d682545763118b29f06e136557fbd3fd81d8ab3ca39d6ef594e73d7
// DECLARATION-TEXT-LENGTH: 114
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - reference identity: @MainActor final reference type; non-Sendable
public final class MonaEditorFindMatch {}

// PATH: editor.TrackedRangeStickiness
// ORDINAL: 90
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: TrackedRangeStickiness
// SOURCE-LINE: 2282
// DECLARATION-SHA256: 0c3ae20b515dce5761fa17cd167655087d233c20d6e3c71b5ae7c67ebf0bae43
// DECLARATION-TEXT-LENGTH: 174
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaEditorTrackedRangeStickiness {}

// PATH: editor.ITextSnapshot
// ORDINAL: 91
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: ITextSnapshot
// SOURCE-LINE: 2294
// DECLARATION-SHA256: 5f2756b760718d20e15c1960de00706b299426fd648319780fbf755b97b23170
// DECLARATION-TEXT-LENGTH: 60
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorITextSnapshot {}

// PATH: editor.ITextModel
// ORDINAL: 92
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: ITextModel
// SOURCE-LINE: 2301
// DECLARATION-SHA256: 98c25a7df9f3c90e1de7d2a736e62ebf8519594b650d207270f735ab8b8471d9
// DECLARATION-TEXT-LENGTH: 19084
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorITextModel {}

// PATH: editor.PositionAffinity
// ORDINAL: 93
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: PositionAffinity
// SOURCE-LINE: 2719
// DECLARATION-SHA256: 041fd1385df904cd1e978a209cd5fa7d5167e4af3a66f69f5ed2384a6e1c10ad
// DECLARATION-TEXT-LENGTH: 435
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaEditorPositionAffinity {}

// PATH: editor.IChange
// ORDINAL: 94
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IChange
// SOURCE-LINE: 2745
// DECLARATION-SHA256: f4a8ed97e1fa8e6be59817576065504369cd25099c638685d50729c7b953b517
// DECLARATION-TEXT-LENGTH: 201
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIChange {}

// PATH: editor.ICharChange
// ORDINAL: 95
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: ICharChange
// SOURCE-LINE: 2755
// DECLARATION-SHA256: 30575aad7484043a8be86674204a9a2a581a26fece77de95917fd3f02a29b8a6
// DECLARATION-TEXT-LENGTH: 205
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorICharChange {}

// PATH: editor.ILineChange
// ORDINAL: 96
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: ILineChange
// SOURCE-LINE: 2765
// DECLARATION-SHA256: 08db0fb9305782c1f65972b2e62f3f641cf6d44c7965905043f8c38f2258a450
// DECLARATION-TEXT-LENGTH: 100
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorILineChange {}

// PATH: editor.IDimension
// ORDINAL: 97
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IDimension
// SOURCE-LINE: 2768
// DECLARATION-SHA256: 66452444e6e5f03abe92e3cf6d3d5b61827a604184b7956fef2fbd3d93e72936
// DECLARATION-TEXT-LENGTH: 67
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIDimension {}

// PATH: editor.IEditOperationBuilder
// ORDINAL: 98
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IEditOperationBuilder
// SOURCE-LINE: 2776
// DECLARATION-SHA256: 63735aeef23a4d04ee7f2635af2ff2861e0dfd761fdb478d8945bbd0d2fecdf0
// DECLARATION-TEXT-LENGTH: 1331
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIEditOperationBuilder {}

// PATH: editor.ICursorStateComputerData
// ORDINAL: 99
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: ICursorStateComputerData
// SOURCE-LINE: 2805
// DECLARATION-SHA256: 119d31793566ab7b32d17b97405efb0aa3531bcd1273fe54f932afa8436245c8
// DECLARATION-TEXT-LENGTH: 372
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorICursorStateComputerData {}

// PATH: editor.ICommand
// ORDINAL: 100
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: ICommand
// SOURCE-LINE: 2821
// DECLARATION-SHA256: 551d2f531d6b357185354ae4f68c5dc3be5ea8b331bf36f7b32931e9cdc3ee7c
// DECLARATION-TEXT-LENGTH: 714
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorICommand {}

// PATH: editor.IDiffEditorModel
// ORDINAL: 101
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IDiffEditorModel
// SOURCE-LINE: 2840
// DECLARATION-SHA256: bbc86b1f7cf295f889d7f695d83483b705df91b96e27b3a317c52c9d6411a394
// DECLARATION-TEXT-LENGTH: 152
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIDiffEditorModel {}

// PATH: editor.IDiffEditorViewModel
// ORDINAL: 102
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IDiffEditorViewModel
// SOURCE-LINE: 2851
// DECLARATION-SHA256: 76142807eaf286e542067c4f50ad3837c968d5704343819ffafb87b3d7d305db
// DECLARATION-TEXT-LENGTH: 130
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIDiffEditorViewModel {}

// PATH: editor.IModelChangedEvent
// ORDINAL: 103
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IModelChangedEvent
// SOURCE-LINE: 2859
// DECLARATION-SHA256: 1238688e6267ec82e712d38d95a4a274afea861ba610d9630c275cf3ffe02941
// DECLARATION-TEXT-LENGTH: 223
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIModelChangedEvent {}

// PATH: editor.IContentSizeChangedEvent
// ORDINAL: 104
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IContentSizeChangedEvent
// SOURCE-LINE: 2870
// DECLARATION-SHA256: 26dc83cdb6c24e797a277a6a42e7699d565563597b57f64523eda0262ad5653d
// DECLARATION-TEXT-LENGTH: 196
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIContentSizeChangedEvent {}

// PATH: editor.INewScrollPosition
// ORDINAL: 105
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: INewScrollPosition
// SOURCE-LINE: 2877
// DECLARATION-SHA256: e99eab24278a7d4b58ff1b5f7238d9364543a7740b9c326b59d2dbfc65549143
// DECLARATION-TEXT-LENGTH: 85
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorINewScrollPosition {}

// PATH: editor.IEditorAction
// ORDINAL: 106
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IEditorAction
// SOURCE-LINE: 2882
// DECLARATION-SHA256: 3ce3340a4516cd92e9f091f92aa765a6d65c0272830bd84ff544f61e5a07825d
// DECLARATION-TEXT-LENGTH: 225
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIEditorAction {}

// PATH: editor.IEditorModel
// ORDINAL: 107
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: type
// RESOLVED-KIND: type
// BASELINE: IEditorModel
// SOURCE-LINE: 2891
// DECLARATION-SHA256: 70805798a6f43ed6930a93601076cdd983ba30a8807fa97223d32c464a19cce5
// DECLARATION-TEXT-LENGTH: 80
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public struct MonaEditorIEditorModel {}

// PATH: editor.ICursorState
// ORDINAL: 108
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: ICursorState
// SOURCE-LINE: 2896
// DECLARATION-SHA256: 2979ce34d28579da5732bd864be3c5292db3fca5dede4726b78ff468b5f9aa04
// DECLARATION-TEXT-LENGTH: 114
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorICursorState {}

// PATH: editor.IViewState
// ORDINAL: 109
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IViewState
// SOURCE-LINE: 2905
// DECLARATION-SHA256: 5c19866d85d8db968c0fde9f16539e8012ceaea9f02c93e53d6994b7e9cf3d90
// DECLARATION-TEXT-LENGTH: 251
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIViewState {}

// PATH: editor.ICodeEditorViewState
// ORDINAL: 110
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: ICodeEditorViewState
// SOURCE-LINE: 2918
// DECLARATION-SHA256: 0d037abee9734d2b801b5ae11fed455c193ee3791b86b92d8965ea1f777fe6e7
// DECLARATION-TEXT-LENGTH: 153
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorICodeEditorViewState {}

// PATH: editor.IDiffEditorViewState
// ORDINAL: 111
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IDiffEditorViewState
// SOURCE-LINE: 2929
// DECLARATION-SHA256: 44c8eadba3174bbbb319a4e754375e133fd9a94a22cf0a7644f1f62a5497c582
// DECLARATION-TEXT-LENGTH: 148
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIDiffEditorViewState {}

// PATH: editor.IEditorViewState
// ORDINAL: 112
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: type
// RESOLVED-KIND: type
// BASELINE: IEditorViewState
// SOURCE-LINE: 2938
// DECLARATION-SHA256: 625bb2b607a356708df6cfee7a43f38b6d173441d74e0008155753a077b30c08
// DECLARATION-TEXT-LENGTH: 75
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public struct MonaEditorIEditorViewState {}

// PATH: editor.ScrollType
// ORDINAL: 113
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: ScrollType
// SOURCE-LINE: 2940
// DECLARATION-SHA256: df615295f9d6bb57f527421970dfb479f1b4e87939e9be4e0c986c0fabc18005
// DECLARATION-TEXT-LENGTH: 57
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaEditorScrollType {}

// PATH: editor.IEditor
// ORDINAL: 114
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IEditor
// SOURCE-LINE: 2948
// DECLARATION-SHA256: 07ab6d0eecba7f422a00039c99a11cbbafb97f45ce0e247a60022404548edec8
// DECLARATION-TEXT-LENGTH: 8581
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIEditor {}

// PATH: editor.IEditorDecorationsCollection
// ORDINAL: 115
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IEditorDecorationsCollection
// SOURCE-LINE: 3162
// DECLARATION-SHA256: b1c9b9de01ac4375e82eae367c345b44ab557f2d0fe3ec0fe6f853ac71485b77
// DECLARATION-TEXT-LENGTH: 937
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIEditorDecorationsCollection {}

// PATH: editor.IEditorContribution
// ORDINAL: 116
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IEditorContribution
// SOURCE-LINE: 3201
// DECLARATION-SHA256: 14a6f90eff1dfd114bfd430cb31db17d81f0c1106e9516c73397beb6f3159890
// DECLARATION-TEXT-LENGTH: 248
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIEditorContribution {}

// PATH: editor.EditorType
// ORDINAL: 117
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: const
// RESOLVED-KIND: const
// BASELINE: EditorType
// SOURCE-LINE: 3219
// DECLARATION-SHA256: 213839b0f8abc5b3dcc0eaee05d5076b37421e1f55d0f8da88a5b22c459601f0
// DECLARATION-TEXT-LENGTH: 76
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public enum MonaEditorEditorType {}

// PATH: editor.IModelLanguageChangedEvent
// ORDINAL: 118
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IModelLanguageChangedEvent
// SOURCE-LINE: 3227
// DECLARATION-SHA256: 9030981d9bf593b87ffe916969c5a5b7c62dd50b04512fe2f88ec8dcd6751b0a
// DECLARATION-TEXT-LENGTH: 263
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIModelLanguageChangedEvent {}

// PATH: editor.IModelLanguageConfigurationChangedEvent
// ORDINAL: 119
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IModelLanguageConfigurationChangedEvent
// SOURCE-LINE: 3245
// DECLARATION-SHA256: 0a7ea876dc979828d14995437ef9ddc13791385229007fe4f435f3b5d2235d8f
// DECLARATION-TEXT-LENGTH: 61
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIModelLanguageConfigurationChangedEvent {}

// PATH: editor.IModelContentChangedEvent
// ORDINAL: 120
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IModelContentChangedEvent
// SOURCE-LINE: 3251
// DECLARATION-SHA256: cdacbaddf6df9b70775a2b755af9abcfaa745e2ee9630801b578471387e3ca5d
// DECLARATION-TEXT-LENGTH: 1077
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIModelContentChangedEvent {}

// PATH: editor.ISerializedModelContentChangedEvent
// ORDINAL: 121
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: ISerializedModelContentChangedEvent
// SOURCE-LINE: 3288
// DECLARATION-SHA256: e4a333569ea295f2e9f66af34e10ddda4206cb1cb59af922ca2ffbdaf245f46a
// DECLARATION-TEXT-LENGTH: 900
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorISerializedModelContentChangedEvent {}

// PATH: editor.IModelDecorationsChangedEvent
// ORDINAL: 122
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IModelDecorationsChangedEvent
// SOURCE-LINE: 3323
// DECLARATION-SHA256: cf9b4048d1cf92f750a3101afb244275792c8f31d67ec4dc4ed6c2585efcc5cb
// DECLARATION-TEXT-LENGTH: 208
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIModelDecorationsChangedEvent {}

// PATH: editor.IModelOptionsChangedEvent
// ORDINAL: 123
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IModelOptionsChangedEvent
// SOURCE-LINE: 3330
// DECLARATION-SHA256: af13c9e80f3a2b4b87c96986e36b37b15c6fa6c5d6d2fc1cb488457c18c16e76
// DECLARATION-TEXT-LENGTH: 182
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIModelOptionsChangedEvent {}

// PATH: editor.IModelContentChange
// ORDINAL: 124
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IModelContentChange
// SOURCE-LINE: 3337
// DECLARATION-SHA256: b368c03682e3090f298475668ff2aa6dde28e836459d8fc40eea69c28b7bdedc
// DECLARATION-TEXT-LENGTH: 371
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIModelContentChange {}

// PATH: editor.CursorChangeReason
// ORDINAL: 125
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: CursorChangeReason
// SOURCE-LINE: 3359
// DECLARATION-SHA256: 7aeef6a57b4764879f3ef9624d13d96ad6c1520e623de9e3a502f2a58b10f9f7
// DECLARATION-TEXT-LENGTH: 525
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaEditorCursorChangeReason {}

// PATH: editor.ICursorPositionChangedEvent
// ORDINAL: 126
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: ICursorPositionChangedEvent
// SOURCE-LINE: 3393
// DECLARATION-SHA256: 8eaf742e15ea23b12a0c8576d81b6a95a8b23078595f9670c77c70bfc1f6ec96
// DECLARATION-TEXT-LENGTH: 363
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorICursorPositionChangedEvent {
    var position: MonaPosition { get }
    var secondaryPositions: [MonaPosition]? { get }
}

// PATH: editor.ICursorSelectionChangedEvent
// ORDINAL: 127
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: ICursorSelectionChangedEvent
// SOURCE-LINE: 3415
// DECLARATION-SHA256: 517865aebb249ef3dd34ea8908e479e8b9a45a67bd199f30ef3017b2cb2bc92f
// DECLARATION-TEXT-LENGTH: 629
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorICursorSelectionChangedEvent {
    var selection: MonaSelection { get }
}

// PATH: editor.AccessibilitySupport
// ORDINAL: 128
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: AccessibilitySupport
// SOURCE-LINE: 3446
// DECLARATION-SHA256: ca183f11a14066e7822b05bcabc73a2157ecc958ff27fc09719eaebc9221936b
// DECLARATION-TEXT-LENGTH: 191
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaEditorAccessibilitySupport {}

// PATH: editor.EditorAutoClosingStrategy
// ORDINAL: 129
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: type
// RESOLVED-KIND: type
// BASELINE: EditorAutoClosingStrategy
// SOURCE-LINE: 3458
// DECLARATION-SHA256: 53a329141ef7aeb82f64e5a5bee2a568b62309ce22036249899727e8057434e0
// DECLARATION-TEXT-LENGTH: 100
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public struct MonaEditorEditorAutoClosingStrategy {}

// PATH: editor.EditorAutoSurroundStrategy
// ORDINAL: 130
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: type
// RESOLVED-KIND: type
// BASELINE: EditorAutoSurroundStrategy
// SOURCE-LINE: 3463
// DECLARATION-SHA256: 642b337801b9ad993662e686d60f19be7be68a268f4ef57bfd98b5072ad47139
// DECLARATION-TEXT-LENGTH: 93
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public struct MonaEditorEditorAutoSurroundStrategy {}

// PATH: editor.EditorAutoClosingEditStrategy
// ORDINAL: 131
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: type
// RESOLVED-KIND: type
// BASELINE: EditorAutoClosingEditStrategy
// SOURCE-LINE: 3468
// DECLARATION-SHA256: 99ecf329d618d4646ddb3b7dcf513f78ced2af7cacb7f7e2af5442009834e656
// DECLARATION-TEXT-LENGTH: 72
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public struct MonaEditorEditorAutoClosingEditStrategy {}

// PATH: editor.EditorAutoIndentStrategy
// ORDINAL: 132
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: EditorAutoIndentStrategy
// SOURCE-LINE: 3473
// DECLARATION-SHA256: 1780ffb7ef5eadbca0f9a222652f34f1946d13e1ad6586d59953f41a82bff5af
// DECLARATION-TEXT-LENGTH: 108
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaEditorEditorAutoIndentStrategy {}

// PATH: editor.IEditorOptions
// ORDINAL: 133
// DISPOSITION: retained-with-explicit-member-cuts
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IEditorOptions
// SOURCE-LINE: 3484
// DECLARATION-SHA256: 84b3856d5e22032a9a94be6ccb431f5f89769a08c34610239740385fb0be1038
// DECLARATION-TEXT-LENGTH: 23806
//   - member cuts: accepted member-level cuts inherited from F1-R3 scope
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIEditorOptions {}

// PATH: editor.IDiffEditorBaseOptions
// ORDINAL: 134
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IDiffEditorBaseOptions
// SOURCE-LINE: 4280
// DECLARATION-SHA256: a8fe1e2713f8571eefa61a4442b3bef5e1a33f8ce2108b35fcdc1d5b72f0aa22
// DECLARATION-TEXT-LENGTH: 3072
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIDiffEditorBaseOptions {}

// PATH: editor.IDiffEditorOptions
// ORDINAL: 135
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IDiffEditorOptions
// SOURCE-LINE: 4399
// DECLARATION-SHA256: e49db98166c5003c695ceb58a2d736cb956cf9281e98e8b1e63e047fb0cc8355
// DECLARATION-TEXT-LENGTH: 87
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIDiffEditorOptions {}

// PATH: editor.ConfigurationChangedEvent
// ORDINAL: 136
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: class
// RESOLVED-KIND: class
// BASELINE: ConfigurationChangedEvent
// SOURCE-LINE: 4405
// DECLARATION-SHA256: 571f830649c861cceffc6ac59db1d7ebb35e69c172af4715a3debf9bdda2a596
// DECLARATION-TEXT-LENGTH: 84
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - reference identity: @MainActor final reference type; non-Sendable
public final class MonaEditorConfigurationChangedEvent {}

// PATH: editor.IComputedEditorOptions
// ORDINAL: 137
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IComputedEditorOptions
// SOURCE-LINE: 4412
// DECLARATION-SHA256: ba5ba48b57fbe0a43aa145afbb8b26262141ae75c8dc6591af171c928efac44d
// DECLARATION-TEXT-LENGTH: 120
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIComputedEditorOptions {}

// PATH: editor.IEditorOption
// ORDINAL: 138
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IEditorOption
// SOURCE-LINE: 4416
// DECLARATION-SHA256: 6a8985ba44e64e5008ab83f0ef17adf249eefcd0d6259da3b80750dc835973e2
// DECLARATION-TEXT-LENGTH: 232
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIEditorOption {}

// PATH: editor.ApplyUpdateResult
// ORDINAL: 139
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: class
// RESOLVED-KIND: class
// BASELINE: ApplyUpdateResult
// SOURCE-LINE: 4426
// DECLARATION-SHA256: c7974854ea79de81c1e233a6c50ac28d46548b5d97838cf1f40b67b5c175eae2
// DECLARATION-TEXT-LENGTH: 141
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - reference identity: @MainActor final reference type; non-Sendable
public final class MonaEditorApplyUpdateResult {}

// PATH: editor.IEditorCommentsOptions
// ORDINAL: 140
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IEditorCommentsOptions
// SOURCE-LINE: 4435
// DECLARATION-SHA256: 913f590294e2db127e65df65092b478d1eb93c56ca4e321115727f1638f09d4c
// DECLARATION-TEXT-LENGTH: 310
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIEditorCommentsOptions {}

// PATH: editor.TextEditorCursorBlinkingStyle
// ORDINAL: 141
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: TextEditorCursorBlinkingStyle
// SOURCE-LINE: 4451
// DECLARATION-SHA256: 1a22392c63653c5859d0475b010c879fb93999d414b7300ebd941a55abcab9fd
// DECLARATION-TEXT-LENGTH: 379
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaEditorTextEditorCursorBlinkingStyle {}

// PATH: editor.TextEditorCursorStyle
// ORDINAL: 142
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: TextEditorCursorStyle
// SOURCE-LINE: 4481
// DECLARATION-SHA256: 7637d4e2f7f65f7438ccb5e9cd47ac15a69158002d8f7b47cff48d301da307d0
// DECLARATION-TEXT-LENGTH: 552
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaEditorTextEditorCursorStyle {}

// PATH: editor.IEditorFindOptions
// ORDINAL: 143
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IEditorFindOptions
// SOURCE-LINE: 4511
// DECLARATION-SHA256: f3aa224f7f819706fbd26e4f4cf5d9a1153a23e3b1bbecf4d7feb774c8efaaad
// DECLARATION-TEXT-LENGTH: 911
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIEditorFindOptions {}

// PATH: editor.GoToLocationValues
// ORDINAL: 144
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: type
// RESOLVED-KIND: type
// BASELINE: GoToLocationValues
// SOURCE-LINE: 4539
// DECLARATION-SHA256: 80551e8193763d848854c78bc165d79da8b1bceb8255c7c0c86b55f99ff28d70
// DECLARATION-TEXT-LENGTH: 65
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public struct MonaEditorGoToLocationValues {}

// PATH: editor.IGotoLocationOptions
// ORDINAL: 145
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IGotoLocationOptions
// SOURCE-LINE: 4544
// DECLARATION-SHA256: 6cf014ce2ceddb2e3710d7a63b121295cb663229b43d21c5bd5dcf983c2c6098
// DECLARATION-TEXT-LENGTH: 590
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIGotoLocationOptions {}

// PATH: editor.IEditorHoverOptions
// ORDINAL: 146
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IEditorHoverOptions
// SOURCE-LINE: 4563
// DECLARATION-SHA256: ac93e8e11fdbc9cc540c7ea376a0f038b51d2b6435d0e912c12cdaaac0379c43
// DECLARATION-TEXT-LENGTH: 788
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIEditorHoverOptions {}

// PATH: editor.OverviewRulerPosition
// ORDINAL: 147
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: OverviewRulerPosition
// SOURCE-LINE: 4599
// DECLARATION-SHA256: ac3559c71ddaa1255e45763ce1bff8daa9e29a28eef25c1fd60d14ab67efad03
// DECLARATION-TEXT-LENGTH: 345
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorOverviewRulerPosition {}

// PATH: editor.RenderMinimap
// ORDINAL: 148
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: RenderMinimap
// SOURCE-LINE: 4618
// DECLARATION-SHA256: 8c3cc6ccc8183ddc846e533b26e889388e89aeab70f7df4a53af228bb3e8d41f
// DECLARATION-TEXT-LENGTH: 67
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaEditorRenderMinimap {}

// PATH: editor.EditorLayoutInfo
// ORDINAL: 149
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: EditorLayoutInfo
// SOURCE-LINE: 4627
// DECLARATION-SHA256: 604805a342da08adc9ac24bd9eacdec2354d72f49468790ffd6d676d7ffc5bfc
// DECLARATION-TEXT-LENGTH: 1646
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorEditorLayoutInfo {}

// PATH: editor.EditorMinimapLayoutInfo
// ORDINAL: 150
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: EditorMinimapLayoutInfo
// SOURCE-LINE: 4700
// DECLARATION-SHA256: 00078cab07e28d1d44ee66ea4ebd8723c3403b70e307b1b493a7bdfcf8213d81
// DECLARATION-TEXT-LENGTH: 488
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorEditorMinimapLayoutInfo {}

// PATH: editor.ShowLightbulbIconMode
// ORDINAL: 151
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: ShowLightbulbIconMode
// SOURCE-LINE: 4714
// DECLARATION-SHA256: 813fc585953dbcfa9711eeb16376c87cb76bfc4bf7fb5b134836e56875f2c9b9
// DECLARATION-TEXT-LENGTH: 86
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaEditorShowLightbulbIconMode {}

// PATH: editor.IEditorLightbulbOptions
// ORDINAL: 152
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IEditorLightbulbOptions
// SOURCE-LINE: 4723
// DECLARATION-SHA256: 84f3e5a7f33fad2d6435c5f036b0cf0ad35b824df8ba4b4276ef9dc070c09358
// DECLARATION-TEXT-LENGTH: 382
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIEditorLightbulbOptions {}

// PATH: editor.IEditorStickyScrollOptions
// ORDINAL: 153
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IEditorStickyScrollOptions
// SOURCE-LINE: 4734
// DECLARATION-SHA256: 1b763d3af3ff57bc0758e823f9f83d3a8e3771f66690d77da0e75cbd92df2762
// DECLARATION-TEXT-LENGTH: 452
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIEditorStickyScrollOptions {}

// PATH: editor.IEditorInlayHintsOptions
// ORDINAL: 154
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IEditorInlayHintsOptions
// SOURCE-LINE: 4756
// DECLARATION-SHA256: b46abc3e088bf38737248931986a34c9d171e3f3c8ff545288fbaf26e2abfdcb
// DECLARATION-TEXT-LENGTH: 625
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIEditorInlayHintsOptions {}

// PATH: editor.IEditorMinimapOptions
// ORDINAL: 155
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IEditorMinimapOptions
// SOURCE-LINE: 4787
// DECLARATION-SHA256: f470345e92220df3b0f9dbd8801e82d8a72d42ef615fa7aeebe4ac11acca2dc2
// DECLARATION-TEXT-LENGTH: 1910
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIEditorMinimapOptions {}

// PATH: editor.IEditorPaddingOptions
// ORDINAL: 156
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IEditorPaddingOptions
// SOURCE-LINE: 4858
// DECLARATION-SHA256: 5dfaca2a7c7d55fb43c89ace4404ec4a4bbd65a5b432918f0b200f46fac363d0
// DECLARATION-TEXT-LENGTH: 216
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIEditorPaddingOptions {}

// PATH: editor.IEditorParameterHintOptions
// ORDINAL: 157
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IEditorParameterHintOptions
// SOURCE-LINE: 4872
// DECLARATION-SHA256: ab878cdada9d42999cce7816a7e3f6ca5ff3efb0dbd5b671b2b5b2b30fa67bfa
// DECLARATION-TEXT-LENGTH: 229
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIEditorParameterHintOptions {}

// PATH: editor.QuickSuggestionsValue
// ORDINAL: 158
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: type
// RESOLVED-KIND: type
// BASELINE: QuickSuggestionsValue
// SOURCE-LINE: 4885
// DECLARATION-SHA256: f7f40a39c1043d7a5d7bdc5940ff5ba4361eb32b544d10dad30a31952d7f0003
// DECLARATION-TEXT-LENGTH: 89
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public struct MonaEditorQuickSuggestionsValue {}

// PATH: editor.IQuickSuggestionsOptions
// ORDINAL: 159
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IQuickSuggestionsOptions
// SOURCE-LINE: 4890
// DECLARATION-SHA256: f1f386e23ba39b96356ecbf0134d1bc4f7c6f401274256cd0c6aad83958244f1
// DECLARATION-TEXT-LENGTH: 180
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIQuickSuggestionsOptions {}

// PATH: editor.InternalQuickSuggestionsOptions
// ORDINAL: 160
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: InternalQuickSuggestionsOptions
// SOURCE-LINE: 4896
// DECLARATION-SHA256: a0a39e39f016b56c4c27806e3609190235aedd3dd0ce8b6cb796723cd93fd5fe
// DECLARATION-TEXT-LENGTH: 181
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorInternalQuickSuggestionsOptions {}

// PATH: editor.LineNumbersType
// ORDINAL: 161
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: type
// RESOLVED-KIND: type
// BASELINE: LineNumbersType
// SOURCE-LINE: 4902
// DECLARATION-SHA256: 201bc513f8d9180da9311b5316a3d49da3cda13af18d7894cf21dd1efa35d054
// DECLARATION-TEXT-LENGTH: 104
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public struct MonaEditorLineNumbersType {}

// PATH: editor.RenderLineNumbersType
// ORDINAL: 162
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: RenderLineNumbersType
// SOURCE-LINE: 4904
// DECLARATION-SHA256: 0f2fc3ba561b3c22833b4e26d482742959d666aa4151705e5866163236fc2201
// DECLARATION-TEXT-LENGTH: 104
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaEditorRenderLineNumbersType {}

// PATH: editor.InternalEditorRenderLineNumbersOptions
// ORDINAL: 163
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: InternalEditorRenderLineNumbersOptions
// SOURCE-LINE: 4912
// DECLARATION-SHA256: 37f68dc6fc492ffc89f46b509116f14a1d327e7a15434578a492fc5cde2c6145
// DECLARATION-TEXT-LENGTH: 168
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorInternalEditorRenderLineNumbersOptions {}

// PATH: editor.IRulerOption
// ORDINAL: 164
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IRulerOption
// SOURCE-LINE: 4917
// DECLARATION-SHA256: 45af393ea7489d20633d9bf945514854dade81e56fe21d58d8b46dc3c0fd9a66
// DECLARATION-TEXT-LENGTH: 94
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIRulerOption {}

// PATH: editor.IEditorScrollbarOptions
// ORDINAL: 165
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IEditorScrollbarOptions
// SOURCE-LINE: 4925
// DECLARATION-SHA256: 531154c8ffb12a39838d28bcdcf3062d52c356f0902ea96cf8c42f52ecf83ff6
// DECLARATION-TEXT-LENGTH: 2378
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIEditorScrollbarOptions {}

// PATH: editor.InternalEditorScrollbarOptions
// ORDINAL: 166
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: InternalEditorScrollbarOptions
// SOURCE-LINE: 5005
// DECLARATION-SHA256: 3a6c0d28756cfa9295ba2b00c390b9a1eb243044ed0fbe2716966750a9d7bf29
// DECLARATION-TEXT-LENGTH: 625
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorInternalEditorScrollbarOptions {}

// PATH: editor.InUntrustedWorkspace
// ORDINAL: 167
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: type
// RESOLVED-KIND: type
// BASELINE: InUntrustedWorkspace
// SOURCE-LINE: 5022
// DECLARATION-SHA256: 5187e141aede0d2e43a9c995e8bad69d254a629bed935e1dbe8d8c3870e75c5d
// DECLARATION-TEXT-LENGTH: 58
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public struct MonaEditorInUntrustedWorkspace {}

// PATH: editor.IUnicodeHighlightOptions
// ORDINAL: 168
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IUnicodeHighlightOptions
// SOURCE-LINE: 5027
// DECLARATION-SHA256: d2a76f1ef73c7102e661147c198eb80d2bf51364b6af87594aeae7b27636c409
// DECLARATION-TEXT-LENGTH: 1219
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIUnicodeHighlightOptions {}

// PATH: editor.IInlineSuggestOptions
// ORDINAL: 169
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IInlineSuggestOptions
// SOURCE-LINE: 5058
// DECLARATION-SHA256: d2013e883079891ef803fed854ab278d691a0f045fb197f317f6176736d97856
// DECLARATION-TEXT-LENGTH: 996
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIInlineSuggestOptions {}

// PATH: editor.RequiredRecursive
// ORDINAL: 170
// DISPOSITION: cut-typescript-type-system-helper
// SOURCE-KIND: type
// BASELINE: RequiredRecursive
// SOURCE-LINE: 5086
// DECLARATION-SHA256: b88a54e4fa693b9a01eb47b4a40003f52217face8fe45b9ffa00afda1dbd0096
// DECLARATION-TEXT-LENGTH: 119
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: mapped/conditional/keyof/infer/typeof alias with no independent runtime value

// PATH: editor.IBracketPairColorizationOptions
// ORDINAL: 171
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IBracketPairColorizationOptions
// SOURCE-LINE: 5090
// DECLARATION-SHA256: c78f2b8e8bffe86632a006e68e8091c940f2baae4b57468598ea641c2fe46900
// DECLARATION-TEXT-LENGTH: 244
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIBracketPairColorizationOptions {}

// PATH: editor.IGuidesOptions
// ORDINAL: 172
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IGuidesOptions
// SOURCE-LINE: 5101
// DECLARATION-SHA256: ca5cc8aedaf840f6254997a06ad357ba7a59c1d809e699b21fb81871dfa4870f
// DECLARATION-TEXT-LENGTH: 661
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIGuidesOptions {}

// PATH: editor.ISuggestOptions
// ORDINAL: 173
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: ISuggestOptions
// SOURCE-LINE: 5132
// DECLARATION-SHA256: f78600a6358b83eb7863b99c17fb3f402505794e2244381aee6bffb550a1ac88
// DECLARATION-TEXT-LENGTH: 3303
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorISuggestOptions {}

// PATH: editor.ISmartSelectOptions
// ORDINAL: 174
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: ISmartSelectOptions
// SOURCE-LINE: 5295
// DECLARATION-SHA256: 6eb1bc98a562c08ee1d7574df1acf86c05557597715b7307504973dcdfa13d5c
// DECLARATION-TEXT-LENGTH: 117
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorISmartSelectOptions {}

// PATH: editor.WrappingIndent
// ORDINAL: 175
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: WrappingIndent
// SOURCE-LINE: 5303
// DECLARATION-SHA256: 1722f6a2c62f47f7d44931a04d824cf28dbf66dac0f2dd6a4bdc456959951ceb
// DECLARATION-TEXT-LENGTH: 395
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaEditorWrappingIndent {}

// PATH: editor.EditorWrappingInfo
// ORDINAL: 176
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: EditorWrappingInfo
// SOURCE-LINE: 5322
// DECLARATION-SHA256: a86d51fd7f9df84805050b4926cb22b24aa3e53dada3488e5e1dd58a69eafdad
// DECLARATION-TEXT-LENGTH: 199
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorEditorWrappingInfo {}

// PATH: editor.IDropIntoEditorOptions
// ORDINAL: 177
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IDropIntoEditorOptions
// SOURCE-LINE: 5332
// DECLARATION-SHA256: 6b57d4a391e8537c9b7bb2446b827ce2646b5cdcc562f46291416d0f40bdcae7
// DECLARATION-TEXT-LENGTH: 269
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIDropIntoEditorOptions {}

// PATH: editor.IPasteAsOptions
// ORDINAL: 178
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IPasteAsOptions
// SOURCE-LINE: 5348
// DECLARATION-SHA256: 5b40ab7c17ef15f7ddf11f1c64538e0a6fa673b3e32128e93599d557599923e3
// DECLARATION-TEXT-LENGTH: 278
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIPasteAsOptions {}

// PATH: editor.EditorOption
// ORDINAL: 179
// DISPOSITION: retained-with-explicit-member-cuts
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: EditorOption
// SOURCE-LINE: 5361
// DECLARATION-SHA256: b93025a3ee99cd809bfbe4eb3a85bf65fab3eab61ae513eaf8c8447ca3c8155d
// DECLARATION-TEXT-LENGTH: 4631
//   - member cuts: accepted member-level cuts inherited from F1-R3 scope
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaEditorEditorOption {}

// PATH: editor.EditorOptions
// ORDINAL: 180
// DISPOSITION: retained-with-explicit-member-cuts
// SOURCE-KIND: const
// RESOLVED-KIND: const
// BASELINE: EditorOptions
// SOURCE-LINE: 5538
// DECLARATION-SHA256: a18510d48044c28f54e89e0fd04d0846b1d5deab2ecc4eb7c69a8a46ac1fcb6d
// DECLARATION-TEXT-LENGTH: 15090
//   - member cuts: accepted member-level cuts inherited from F1-R3 scope
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public enum MonaEditorEditorOptions {}

// PATH: editor.EditorOptionsType
// ORDINAL: 181
// DISPOSITION: cut-typescript-type-system-helper
// SOURCE-KIND: type
// BASELINE: EditorOptionsType
// SOURCE-LINE: 5715
// DECLARATION-SHA256: 6d3044a81b075087902e25a5675843ead4f4aad915336ac0db6d553625fa1f22
// DECLARATION-TEXT-LENGTH: 46
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: mapped/conditional/keyof/infer/typeof alias with no independent runtime value

// PATH: editor.FindEditorOptionsKeyById
// ORDINAL: 182
// DISPOSITION: cut-typescript-type-system-helper
// SOURCE-KIND: type
// BASELINE: FindEditorOptionsKeyById
// SOURCE-LINE: 5717
// DECLARATION-SHA256: be3f09935394a47436dbf9d39ce9cd806a08d9d2c8fc8c1e322e508f42b76113
// DECLARATION-TEXT-LENGTH: 170
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: mapped/conditional/keyof/infer/typeof alias with no independent runtime value

// PATH: editor.ComputedEditorOptionValue
// ORDINAL: 183
// DISPOSITION: cut-typescript-type-system-helper
// SOURCE-KIND: type
// BASELINE: ComputedEditorOptionValue
// SOURCE-LINE: 5721
// DECLARATION-SHA256: 254ba9677dcb3d6112119473d3f56190dd7cdabb427bb9cc64c957c2475cb119
// DECLARATION-TEXT-LENGTH: 118
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: mapped/conditional/keyof/infer/typeof alias with no independent runtime value

// PATH: editor.FindComputedEditorOptionValueById
// ORDINAL: 184
// DISPOSITION: cut-typescript-type-system-helper
// SOURCE-KIND: type
// BASELINE: FindComputedEditorOptionValueById
// SOURCE-LINE: 5723
// DECLARATION-SHA256: f0ccffbe243bf4bc3b5de80f85cc3e087cc2466d5429ebc3b38268d7d5660043
// DECLARATION-TEXT-LENGTH: 159
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: mapped/conditional/keyof/infer/typeof alias with no independent runtime value

// PATH: editor.MouseMiddleClickAction
// ORDINAL: 185
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: type
// RESOLVED-KIND: type
// BASELINE: MouseMiddleClickAction
// SOURCE-LINE: 5725
// DECLARATION-SHA256: b044afd69733949ca886d356bc9bfc3a9c1587dfcd9e5f095a456517293c798a
// DECLARATION-TEXT-LENGTH: 78
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public struct MonaEditorMouseMiddleClickAction {}

// PATH: editor.IViewZoneChangeAccessor
// ORDINAL: 188
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IViewZoneChangeAccessor
// SOURCE-LINE: 5812
// DECLARATION-SHA256: eef194ff8e4bb5ca23f2023bd0fbf629ada12622a09ea0daa48a92ce73f87e40
// DECLARATION-TEXT-LENGTH: 526
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIViewZoneChangeAccessor {}

// PATH: editor.ContentWidgetPositionPreference
// ORDINAL: 189
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: ContentWidgetPositionPreference
// SOURCE-LINE: 5834
// DECLARATION-SHA256: 8ae9155ce2c325088bc270827510b073ba4173110bd24879063cf11dcbb8a71a
// DECLARATION-TEXT-LENGTH: 268
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaEditorContentWidgetPositionPreference {}

// PATH: editor.IContentWidgetPosition
// ORDINAL: 190
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IContentWidgetPosition
// SOURCE-LINE: 5852
// DECLARATION-SHA256: 04af3706ad5fcd6f9b1adbfef2cc0b1bb4c681256aae0501b199eadb1c594175
// DECLARATION-TEXT-LENGTH: 1213
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIContentWidgetPosition {}

// PATH: editor.IContentWidgetRenderedCoordinate
// ORDINAL: 192
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IContentWidgetRenderedCoordinate
// SOURCE-LINE: 5930
// DECLARATION-SHA256: d27f61ceae252b390b98938ea1c5e26fb8d00291e30192a701c6389558179432
// DECLARATION-TEXT-LENGTH: 228
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIContentWidgetRenderedCoordinate {}

// PATH: editor.OverlayWidgetPositionPreference
// ORDINAL: 193
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: OverlayWidgetPositionPreference
// SOURCE-LINE: 5944
// DECLARATION-SHA256: 97922045b267875115b08dfb10f52aa08554f58bbe39adddd2d63ea98a1bedc1
// DECLARATION-TEXT-LENGTH: 320
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaEditorOverlayWidgetPositionPreference {}

// PATH: editor.IOverlayWidgetPositionCoordinates
// ORDINAL: 194
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IOverlayWidgetPositionCoordinates
// SOURCE-LINE: 5962
// DECLARATION-SHA256: c0e458484daab2f165aa246ceec28f57287ecd82176898d2c26b6b9e3af4499d
// DECLARATION-TEXT-LENGTH: 251
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIOverlayWidgetPositionCoordinates {}

// PATH: editor.IOverlayWidgetPosition
// ORDINAL: 195
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IOverlayWidgetPosition
// SOURCE-LINE: 5976
// DECLARATION-SHA256: 4ec7d2f3a80104af0dac087d494e8d354832ff0301c4e6ec9154e200fb2478a9
// DECLARATION-TEXT-LENGTH: 361
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIOverlayWidgetPosition {}

// PATH: editor.IGlyphMarginWidgetPosition
// ORDINAL: 198
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IGlyphMarginWidgetPosition
// SOURCE-LINE: 6040
// DECLARATION-SHA256: f1b3d57ef822a072efe0bde706a5ddfc8858116108b510950725c92147686815
// DECLARATION-TEXT-LENGTH: 369
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIGlyphMarginWidgetPosition {}

// PATH: editor.MouseTargetType
// ORDINAL: 199
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: MouseTargetType
// SOURCE-LINE: 6059
// DECLARATION-SHA256: 74eb145cf15680bcd3a9ee462ebfea8ea68cf4c9d7b06929a1f612acb3ca9db8
// DECLARATION-TEXT-LENGTH: 1217
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaEditorMouseTargetType {}

// PATH: editor.IMouseTargetUnknown
// ORDINAL: 201
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IMouseTargetUnknown
// SOURCE-LINE: 6137
// DECLARATION-SHA256: df05008c8788c4427d8b82b386fb993b9a485cacaa4a9a35a7a48be0d0e97b62
// DECLARATION-TEXT-LENGTH: 108
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIMouseTargetUnknown {}

// PATH: editor.IMouseTargetTextarea
// ORDINAL: 202
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IMouseTargetTextarea
// SOURCE-LINE: 6141
// DECLARATION-SHA256: 88446666896a90e714196303dc4809f95acd6b04702cd7775a708fd5f1a90ced
// DECLARATION-TEXT-LENGTH: 161
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIMouseTargetTextarea {}

// PATH: editor.IMouseTargetMarginData
// ORDINAL: 203
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IMouseTargetMarginData
// SOURCE-LINE: 6147
// DECLARATION-SHA256: a023717cd4dbad990e6bdec7f5428be84f6c814cb6d9d9abf0d3c89e8d90214a
// DECLARATION-TEXT-LENGTH: 262
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIMouseTargetMarginData {}

// PATH: editor.IMouseTargetMargin
// ORDINAL: 204
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IMouseTargetMargin
// SOURCE-LINE: 6156
// DECLARATION-SHA256: 9e4bf153e3ff4d719b327843af4e6f4b3e54a0dfb941e5aaacca53e77b9aa4ee
// DECLARATION-TEXT-LENGTH: 298
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIMouseTargetMargin {}

// PATH: editor.IMouseTargetViewZoneData
// ORDINAL: 205
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IMouseTargetViewZoneData
// SOURCE-LINE: 6163
// DECLARATION-SHA256: 72f14ae23e2e56db89f9d2a9cefa534921e5785367c53b49c910f02934b4532e
// DECLARATION-TEXT-LENGTH: 231
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIMouseTargetViewZoneData {}

// PATH: editor.IMouseTargetViewZone
// ORDINAL: 206
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IMouseTargetViewZone
// SOURCE-LINE: 6171
// DECLARATION-SHA256: 089a6ff7846fc28b574c6c74860aee8e93f7efedd4da5f4e83077b9838d51017
// DECLARATION-TEXT-LENGTH: 255
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIMouseTargetViewZone {}

// PATH: editor.IMouseTargetContentTextData
// ORDINAL: 207
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IMouseTargetContentTextData
// SOURCE-LINE: 6178
// DECLARATION-SHA256: f5059b933aeb59b557ec12ee6d528273cfc7cf04778162497f250fef2537ed89
// DECLARATION-TEXT-LENGTH: 92
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIMouseTargetContentTextData {}

// PATH: editor.IMouseTargetContentText
// ORDINAL: 208
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IMouseTargetContentText
// SOURCE-LINE: 6182
// DECLARATION-SHA256: 39a6a0926215c62910d7c8862acfdb0ab8faca4054092fe92d2238245df612a8
// DECLARATION-TEXT-LENGTH: 221
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIMouseTargetContentText {}

// PATH: editor.IMouseTargetContentEmptyData
// ORDINAL: 209
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IMouseTargetContentEmptyData
// SOURCE-LINE: 6189
// DECLARATION-SHA256: e6fdabaab8ccf6263433c0b2fd09cac7e9f2c660bd350a2acb41c23503a5dbaf
// DECLARATION-TEXT-LENGTH: 130
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIMouseTargetContentEmptyData {}

// PATH: editor.IMouseTargetContentEmpty
// ORDINAL: 210
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IMouseTargetContentEmpty
// SOURCE-LINE: 6194
// DECLARATION-SHA256: e7d73feae1c2332226f664bdfd730b3d60095e274aec2fa3c1a00df330963435
// DECLARATION-TEXT-LENGTH: 224
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIMouseTargetContentEmpty {}

// PATH: editor.IMouseTargetContentWidget
// ORDINAL: 211
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IMouseTargetContentWidget
// SOURCE-LINE: 6201
// DECLARATION-SHA256: 6e14037bb17a90833e11c0a93d931c27f632f419a2808beca4262206d23cbf07
// DECLARATION-TEXT-LENGTH: 199
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIMouseTargetContentWidget {}

// PATH: editor.IMouseTargetOverlayWidget
// ORDINAL: 212
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IMouseTargetOverlayWidget
// SOURCE-LINE: 6208
// DECLARATION-SHA256: f6739aada1afd02d28f7e8c2e6ebb98637aa41cb65d4f53a40e44bb49131636b
// DECLARATION-TEXT-LENGTH: 199
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIMouseTargetOverlayWidget {}

// PATH: editor.IMouseTargetScrollbar
// ORDINAL: 213
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IMouseTargetScrollbar
// SOURCE-LINE: 6215
// DECLARATION-SHA256: 39b2987a4690679c3be791f7736f3fa5bc26a0c577a3f9879ba0c9b60936435a
// DECLARATION-TEXT-LENGTH: 168
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIMouseTargetScrollbar {}

// PATH: editor.IMouseTargetOverviewRuler
// ORDINAL: 214
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IMouseTargetOverviewRuler
// SOURCE-LINE: 6221
// DECLARATION-SHA256: c167cc35dde68666c0326ac3b11a583f556770d9bfb937903f0892278e9512db
// DECLARATION-TEXT-LENGTH: 121
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIMouseTargetOverviewRuler {}

// PATH: editor.IMouseTargetOutsideEditor
// ORDINAL: 215
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IMouseTargetOutsideEditor
// SOURCE-LINE: 6225
// DECLARATION-SHA256: 2cffe08311cf48155cb8b344379fb3828c42cf4140c90cf54883d96b6188c3dc
// DECLARATION-TEXT-LENGTH: 223
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIMouseTargetOutsideEditor {}

// PATH: editor.IMouseTarget
// ORDINAL: 216
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: type
// RESOLVED-KIND: type
// BASELINE: IMouseTarget
// SOURCE-LINE: 6234
// DECLARATION-SHA256: bc464bf151f41daf6213c5033f26f1009d3ebff87860ad5141254d806ff07511
// DECLARATION-TEXT-LENGTH: 305
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public struct MonaEditorIMouseTarget {}

// PATH: editor.IEditorMouseEvent
// ORDINAL: 217
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IEditorMouseEvent
// SOURCE-LINE: 6239
// DECLARATION-SHA256: 0b98d9a9013a9172b9469b2c64e2b4ae4d37b684bfa4810cd90144fcad0cd16f
// DECLARATION-TEXT-LENGTH: 103
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIEditorMouseEvent {}

// PATH: editor.IPartialEditorMouseEvent
// ORDINAL: 218
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IPartialEditorMouseEvent
// SOURCE-LINE: 6244
// DECLARATION-SHA256: 32c4f1383fb8b075dc6a39ad79839932950cfa05cbf0e81e76b1baa8bc8799b8
// DECLARATION-TEXT-LENGTH: 117
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIPartialEditorMouseEvent {}

// PATH: editor.IPasteEvent
// ORDINAL: 219
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IPasteEvent
// SOURCE-LINE: 6252
// DECLARATION-SHA256: 68a73f993e272d4ad4e517c4e77e7dd2a030e4fcc8fc6e49ba86a7140d2ff515
// DECLARATION-TEXT-LENGTH: 140
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIPasteEvent {}

// PATH: editor.FontInfo
// ORDINAL: 223
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: class
// RESOLVED-KIND: class
// BASELINE: FontInfo
// SOURCE-LINE: 6794
// DECLARATION-SHA256: 56ba2c2f1d13bfff19b7144ee279baeb80faa1ad9f41eb942d2b29af295ac215
// DECLARATION-TEXT-LENGTH: 462
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - reference identity: @MainActor final reference type; non-Sendable
public final class MonaEditorFontInfo {}

// PATH: editor.BareFontInfo
// ORDINAL: 224
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: class
// RESOLVED-KIND: class
// BASELINE: BareFontInfo
// SOURCE-LINE: 6808
// DECLARATION-SHA256: 712da902b49ba8920bfacaeba730445f60271228fc4e1013b9e3f37788de00da
// DECLARATION-TEXT-LENGTH: 336
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - reference identity: @MainActor final reference type; non-Sendable
public final class MonaEditorBareFontInfo {}

// PATH: editor.EditorZoom
// ORDINAL: 225
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: const
// RESOLVED-KIND: const
// BASELINE: EditorZoom
// SOURCE-LINE: 6820
// DECLARATION-SHA256: 175380c01af5e4b93256d722cc01dce5ad58ea394b4c2e9166f3db8b9b0161f6
// DECLARATION-TEXT-LENGTH: 37
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public enum MonaEditorEditorZoom {}

// PATH: editor.IEditorZoom
// ORDINAL: 226
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IEditorZoom
// SOURCE-LINE: 6822
// DECLARATION-SHA256: cf091ccfc8e0b1f5ecfc6b7fb446ed3e1d451a206f30b97553236d0524dd2207
// DECLARATION-TEXT-LENGTH: 149
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIEditorZoom {}

// PATH: editor.IReadOnlyModel
// ORDINAL: 227
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: type
// RESOLVED-KIND: type
// BASELINE: IReadOnlyModel
// SOURCE-LINE: 6829
// DECLARATION-SHA256: bc62837a189b060748187b0e8caced9ee587c5949eab2c5c655591473d735602
// DECLARATION-TEXT-LENGTH: 40
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public struct MonaEditorIReadOnlyModel {}

// PATH: editor.IModel
// ORDINAL: 228
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: type
// RESOLVED-KIND: type
// BASELINE: IModel
// SOURCE-LINE: 6830
// DECLARATION-SHA256: 13a94711a3f785230cca9db0be253322c881e93ea5c5febec6cb1bc30d0ed257
// DECLARATION-TEXT-LENGTH: 32
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public struct MonaEditorIModel {}

// PATH: languages.EditDeltaInfo
// ORDINAL: 0
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: class
// RESOLVED-KIND: class
// BASELINE: EditDeltaInfo
// SOURCE-LINE: 6835
// DECLARATION-SHA256: c5956063d264271a74cd561f79bff377196d9c91be72d34aa2a81f1a57be4a1b
// DECLARATION-TEXT-LENGTH: 485
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - reference identity: @MainActor final reference type; non-Sendable
public final class MonaLanguagesEditDeltaInfo {}

// PATH: languages.IRelativePattern
// ORDINAL: 1
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IRelativePattern
// SOURCE-LINE: 6844
// DECLARATION-SHA256: 0df1e84b185daae28bbddd4cc92e71fce6a68887856463d2069ee76f05c1c28a
// DECLARATION-TEXT-LENGTH: 461
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesIRelativePattern {}

// PATH: languages.LanguageSelector
// ORDINAL: 2
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: type
// RESOLVED-KIND: type
// BASELINE: LanguageSelector
// SOURCE-LINE: 6859
// DECLARATION-SHA256: 32df54ca09b6e09f40e024329c3005f9f8609da5c4f84d303eaf70375065f5eb
// DECLARATION-TEXT-LENGTH: 96
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public struct MonaLanguagesLanguageSelector {}

// PATH: languages.LanguageFilter
// ORDINAL: 3
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: LanguageFilter
// SOURCE-LINE: 6861
// DECLARATION-SHA256: def2fa6f13a5f329e156270f8bf98178bbb09535da03bf622e04ed01e8c230a9
// DECLARATION-TEXT-LENGTH: 410
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesLanguageFilter {}

// PATH: languages.register
// ORDINAL: 4
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: register
// SOURCE-LINE: 6880
// DECLARATION-SHA256: 840bb1471acfd2f8d7d0bd1c4f66ccc1d7479b325d5dc4dcf9eeca5eab57046f
// DECLARATION-TEXT-LENGTH: 66
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaLanguagesRegister() async throws {}

// PATH: languages.getLanguages
// ORDINAL: 5
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: getLanguages
// SOURCE-LINE: 6885
// DECLARATION-SHA256: 8d8fbcc36e485f93da338fb5f74915b90f2b8690a9606f97075798520a70f655
// DECLARATION-TEXT-LENGTH: 58
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaLanguagesGetLanguages() async throws {}

// PATH: languages.getEncodedLanguageId
// ORDINAL: 6
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: getEncodedLanguageId
// SOURCE-LINE: 6887
// DECLARATION-SHA256: 48c23d216032ae6a846ed6864d32542a0d0d38eb7a089f82cf313c80fd08b4cd
// DECLARATION-TEXT-LENGTH: 65
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaLanguagesGetEncodedLanguageId() async throws {}

// PATH: languages.onLanguage
// ORDINAL: 7
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: onLanguage
// SOURCE-LINE: 6893
// DECLARATION-SHA256: 57a938ae52aa83b9c4e709aae9eb0445b2933f7738b1ffddeb34daaa84626767
// DECLARATION-TEXT-LENGTH: 82
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaLanguagesOnLanguage() async throws {}

// PATH: languages.onLanguageEncountered
// ORDINAL: 8
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: onLanguageEncountered
// SOURCE-LINE: 6900
// DECLARATION-SHA256: bba98df0ab9584a01cad09bbc20336af26792f5fcde5d633643ea8742837a210
// DECLARATION-TEXT-LENGTH: 93
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaLanguagesOnLanguageEncountered() async throws {}

// PATH: languages.setLanguageConfiguration
// ORDINAL: 9
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: setLanguageConfiguration
// SOURCE-LINE: 6905
// DECLARATION-SHA256: 49931ffc1e020da748d94f34dfb0d091f4292ce9a10673d39ffbc6ff4283b28b
// DECLARATION-TEXT-LENGTH: 112
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaLanguagesSetLanguageConfiguration() async throws {}

// PATH: languages.IToken
// ORDINAL: 10
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IToken
// SOURCE-LINE: 6910
// DECLARATION-SHA256: 78d6dcf3eb8bb9363657c5a35864de7af510f0af00ee4fcddd5927c21e811ca7
// DECLARATION-TEXT-LENGTH: 68
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesIToken {}

// PATH: languages.ILineTokens
// ORDINAL: 11
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: ILineTokens
// SOURCE-LINE: 6918
// DECLARATION-SHA256: eea827ebdfd5b6fd1f863f90c3325182a771b7dd2e8aff061f66ab55d671f3fc
// DECLARATION-TEXT-LENGTH: 289
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesILineTokens {}

// PATH: languages.IEncodedLineTokens
// ORDINAL: 12
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IEncodedLineTokens
// SOURCE-LINE: 6933
// DECLARATION-SHA256: 8883ee2f0c8359230e5a7a67e55810de324ffc3de84f8ff785cec6eef53ac84b
// DECLARATION-TEXT-LENGTH: 1436
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesIEncodedLineTokens {}

// PATH: languages.TokensProviderFactory
// ORDINAL: 13
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: TokensProviderFactory
// SOURCE-LINE: 6965
// DECLARATION-SHA256: ca3eeaaba2b7fa4c1ef889b54077e210a6003b5591a9b8ab832738d33ab53bd4
// DECLARATION-TEXT-LENGTH: 130
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesTokensProviderFactory {}

// PATH: languages.TokensProvider
// ORDINAL: 14
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: TokensProvider
// SOURCE-LINE: 6972
// DECLARATION-SHA256: af516b62845bbccde5e96980ec4af0e1bbf4ccf7a381143570227bba67243381
// DECLARATION-TEXT-LENGTH: 304
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesTokensProvider {}

// PATH: languages.EncodedTokensProvider
// ORDINAL: 15
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: EncodedTokensProvider
// SOURCE-LINE: 6986
// DECLARATION-SHA256: 9060b880ae9cfe36124898ac3c0b815c9c177387000549fd5ec41152cedfa491
// DECLARATION-TEXT-LENGTH: 459
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesEncodedTokensProvider {}

// PATH: languages.setColorMap
// ORDINAL: 16
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: setColorMap
// SOURCE-LINE: 7005
// DECLARATION-SHA256: c2624f69aee2a7373ec1fc2c9a3bdb113190e95e80a5bb9e6c64e9afacbb7ab2
// DECLARATION-TEXT-LENGTH: 61
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaLanguagesSetColorMap() async throws {}

// PATH: languages.registerTokensProviderFactory
// ORDINAL: 17
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: registerTokensProviderFactory
// SOURCE-LINE: 7012
// DECLARATION-SHA256: e2902a133007d7b0165bfe84a5f2060ab6b9fb145dcb8ea4029621d9edd21eb9
// DECLARATION-TEXT-LENGTH: 111
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaLanguagesRegisterTokensProviderFactory() async throws {}

// PATH: languages.setTokensProvider
// ORDINAL: 18
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: setTokensProvider
// SOURCE-LINE: 7020
// DECLARATION-SHA256: 8cf4ded6ed5bcafb27e73759b1b8b36ab36a4450b005d4d4d6a31cba819ec2d9
// DECLARATION-TEXT-LENGTH: 168
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaLanguagesSetTokensProvider() async throws {}

// PATH: languages.setMonarchTokensProvider
// ORDINAL: 19
// DISPOSITION: cut-monarch-api-or-type
// SOURCE-KIND: function
// BASELINE: setMonarchTokensProvider
// SOURCE-LINE: 7028
// DECLARATION-SHA256: b1c56a609e1a84382c232cf889ada9cce85f048dbd63da6251643adc0d65fe16
// DECLARATION-TEXT-LENGTH: 134
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: Monarch is an accepted complete language-content cut; retaining it would make a cut type reachable

// PATH: languages.registerReferenceProvider
// ORDINAL: 20
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: registerReferenceProvider
// SOURCE-LINE: 7033
// DECLARATION-SHA256: cd97af25d2973c2c31ffca092ef43e87e46f9814f1384c76ee5eeaaccc054e5d
// DECLARATION-TEXT-LENGTH: 120
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaLanguagesRegisterReferenceProvider() async throws {}

// PATH: languages.registerRenameProvider
// ORDINAL: 21
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: registerRenameProvider
// SOURCE-LINE: 7038
// DECLARATION-SHA256: 038d5315320487a71794c66117a5f608ae90a300993f56b8c4f63e0e5100efb5
// DECLARATION-TEXT-LENGTH: 114
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaLanguagesRegisterRenameProvider() async throws {}

// PATH: languages.registerNewSymbolNameProvider
// ORDINAL: 22
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: registerNewSymbolNameProvider
// SOURCE-LINE: 7043
// DECLARATION-SHA256: 2a616ec34c32f76b3421e365adff3c73ecea595c7742596a2e00a70892963b45
// DECLARATION-TEXT-LENGTH: 129
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaLanguagesRegisterNewSymbolNameProvider() async throws {}

// PATH: languages.registerSignatureHelpProvider
// ORDINAL: 23
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: registerSignatureHelpProvider
// SOURCE-LINE: 7048
// DECLARATION-SHA256: 4cca33a965916af111a3e4e9672627bf49f7e7e68dcb7c142d85e279a33c67da
// DECLARATION-TEXT-LENGTH: 128
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaLanguagesRegisterSignatureHelpProvider() async throws {}

// PATH: languages.registerHoverProvider
// ORDINAL: 24
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: registerHoverProvider
// SOURCE-LINE: 7053
// DECLARATION-SHA256: 2bb4ef3e2e2084a5b7ee341b97489c864f8b7d1e739b55a161e1264aafe5ee31
// DECLARATION-TEXT-LENGTH: 112
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaLanguagesRegisterHoverProvider() async throws {}

// PATH: languages.registerDocumentSymbolProvider
// ORDINAL: 25
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: registerDocumentSymbolProvider
// SOURCE-LINE: 7058
// DECLARATION-SHA256: 8cf04b19fcba0beef4051097cf44df91a846a0bd6154f047f4706d71f9c79fb9
// DECLARATION-TEXT-LENGTH: 130
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaLanguagesRegisterDocumentSymbolProvider() async throws {}

// PATH: languages.registerDocumentHighlightProvider
// ORDINAL: 26
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: registerDocumentHighlightProvider
// SOURCE-LINE: 7063
// DECLARATION-SHA256: f315e32b29540d8a9c6d1091463c9eb7db66078a65e295f84e5d12be7938e958
// DECLARATION-TEXT-LENGTH: 136
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaLanguagesRegisterDocumentHighlightProvider() async throws {}

// PATH: languages.registerLinkedEditingRangeProvider
// ORDINAL: 27
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: registerLinkedEditingRangeProvider
// SOURCE-LINE: 7068
// DECLARATION-SHA256: 58434fbb1acc415bcaeb492142f0e8154cd5aee57fc66cea6970f8f434cf69aa
// DECLARATION-TEXT-LENGTH: 138
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaLanguagesRegisterLinkedEditingRangeProvider() async throws {}

// PATH: languages.registerDefinitionProvider
// ORDINAL: 28
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: registerDefinitionProvider
// SOURCE-LINE: 7073
// DECLARATION-SHA256: 7f389f958f93634f40c4fef6be261f58b26bb3241adf36ffa8e98e6f413d803b
// DECLARATION-TEXT-LENGTH: 122
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaLanguagesRegisterDefinitionProvider() async throws {}

// PATH: languages.registerImplementationProvider
// ORDINAL: 29
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: registerImplementationProvider
// SOURCE-LINE: 7078
// DECLARATION-SHA256: 1c5ba34a91fa9c5ee58edf5c0624d90709a3de5be9bf5331e5aa14225a12925f
// DECLARATION-TEXT-LENGTH: 130
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaLanguagesRegisterImplementationProvider() async throws {}

// PATH: languages.registerTypeDefinitionProvider
// ORDINAL: 30
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: registerTypeDefinitionProvider
// SOURCE-LINE: 7083
// DECLARATION-SHA256: dadaf2f8dd6283ecfa3f6515e717f21bba1c4642212539a56eb632565f747828
// DECLARATION-TEXT-LENGTH: 130
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaLanguagesRegisterTypeDefinitionProvider() async throws {}

// PATH: languages.registerCodeLensProvider
// ORDINAL: 31
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: registerCodeLensProvider
// SOURCE-LINE: 7088
// DECLARATION-SHA256: f58853bbf86ac10eebd3da10ec55fef5e90c8a497af916379a0c39facf6675c3
// DECLARATION-TEXT-LENGTH: 118
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaLanguagesRegisterCodeLensProvider() async throws {}

// PATH: languages.registerCodeActionProvider
// ORDINAL: 32
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: registerCodeActionProvider
// SOURCE-LINE: 7093
// DECLARATION-SHA256: 895690ba6580f14e2c95daab6c7d545a13a94e16188176e1068e4d55751c5868
// DECLARATION-TEXT-LENGTH: 161
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaLanguagesRegisterCodeActionProvider() async throws {}

// PATH: languages.registerDocumentFormattingEditProvider
// ORDINAL: 33
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: registerDocumentFormattingEditProvider
// SOURCE-LINE: 7098
// DECLARATION-SHA256: 915e78aa517f6cfe1212232fd0a2d48b7f1c5c8e317cc731a8d9c6b806736017
// DECLARATION-TEXT-LENGTH: 146
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaLanguagesRegisterDocumentFormattingEditProvider() async throws {}

// PATH: languages.registerDocumentRangeFormattingEditProvider
// ORDINAL: 34
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: registerDocumentRangeFormattingEditProvider
// SOURCE-LINE: 7103
// DECLARATION-SHA256: e7d32ef819d84637dd4df2957bafa1bba939983fa58c0d5e3a3d50e9a1a7713f
// DECLARATION-TEXT-LENGTH: 156
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaLanguagesRegisterDocumentRangeFormattingEditProvider() async throws {}

// PATH: languages.registerOnTypeFormattingEditProvider
// ORDINAL: 35
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: registerOnTypeFormattingEditProvider
// SOURCE-LINE: 7108
// DECLARATION-SHA256: 22f08fdf88537a196d59bf3b88b4f219cb7d21a000a83ac2501cff5f087cfedf
// DECLARATION-TEXT-LENGTH: 142
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaLanguagesRegisterOnTypeFormattingEditProvider() async throws {}

// PATH: languages.registerLinkProvider
// ORDINAL: 36
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: registerLinkProvider
// SOURCE-LINE: 7113
// DECLARATION-SHA256: 6b27c3bc67d3bfbe32ca785bacef6afd12d919d137ce4fb05a0bb2725cedb4b9
// DECLARATION-TEXT-LENGTH: 110
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaLanguagesRegisterLinkProvider() async throws {}

// PATH: languages.registerCompletionItemProvider
// ORDINAL: 37
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: registerCompletionItemProvider
// SOURCE-LINE: 7118
// DECLARATION-SHA256: 3ba4b72616c97131e4e7ee70e0192c6d45b1210b2ef56ecd848f5bb5584dd911
// DECLARATION-TEXT-LENGTH: 130
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaLanguagesRegisterCompletionItemProvider() async throws {}

// PATH: languages.registerColorProvider
// ORDINAL: 38
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: registerColorProvider
// SOURCE-LINE: 7123
// DECLARATION-SHA256: 16430e5552b5370a1c5323182a752630e6f83aa92110b1f5b90b1c4f9f50f4f0
// DECLARATION-TEXT-LENGTH: 120
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaLanguagesRegisterColorProvider() async throws {}

// PATH: languages.registerFoldingRangeProvider
// ORDINAL: 39
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: registerFoldingRangeProvider
// SOURCE-LINE: 7128
// DECLARATION-SHA256: 8bb651c7432d7a81d75e7f04ed15bf72934844d380b8a397b300590c4facd73e
// DECLARATION-TEXT-LENGTH: 126
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaLanguagesRegisterFoldingRangeProvider() async throws {}

// PATH: languages.registerDeclarationProvider
// ORDINAL: 40
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: registerDeclarationProvider
// SOURCE-LINE: 7133
// DECLARATION-SHA256: 24873bef0c01b1cb57b8a8a9412371f6ef20f2cea9a411a60f4a40be39b6764a
// DECLARATION-TEXT-LENGTH: 124
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaLanguagesRegisterDeclarationProvider() async throws {}

// PATH: languages.registerSelectionRangeProvider
// ORDINAL: 41
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: registerSelectionRangeProvider
// SOURCE-LINE: 7138
// DECLARATION-SHA256: 6eccb1a8934ad1db6fa4bb74d96121589351b7afef76da8f6a88a6f372123e49
// DECLARATION-TEXT-LENGTH: 130
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaLanguagesRegisterSelectionRangeProvider() async throws {}

// PATH: languages.registerDocumentSemanticTokensProvider
// ORDINAL: 42
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: registerDocumentSemanticTokensProvider
// SOURCE-LINE: 7147
// DECLARATION-SHA256: 954b463e3ae43e705167092b84c4a31624ab9a83ce64095212953daa6f7a3646
// DECLARATION-TEXT-LENGTH: 146
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaLanguagesRegisterDocumentSemanticTokensProvider() async throws {}

// PATH: languages.registerDocumentRangeSemanticTokensProvider
// ORDINAL: 43
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: registerDocumentRangeSemanticTokensProvider
// SOURCE-LINE: 7156
// DECLARATION-SHA256: 0d6f72035224131195b606f32a20e4e7d368dadfe89dfc5f4d14a0868affe75a
// DECLARATION-TEXT-LENGTH: 156
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaLanguagesRegisterDocumentRangeSemanticTokensProvider() async throws {}

// PATH: languages.registerInlineCompletionsProvider
// ORDINAL: 44
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: registerInlineCompletionsProvider
// SOURCE-LINE: 7161
// DECLARATION-SHA256: 355603a9e933dc8c6ae7283607e16c50dd37c15f4ed205883fe582bb4e4d1526
// DECLARATION-TEXT-LENGTH: 136
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaLanguagesRegisterInlineCompletionsProvider() async throws {}

// PATH: languages.registerInlayHintsProvider
// ORDINAL: 45
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: registerInlayHintsProvider
// SOURCE-LINE: 7166
// DECLARATION-SHA256: b9201bf1e876561181b6fbcbdec27dbe06acd96a70e076d0f363777dcaefc85a
// DECLARATION-TEXT-LENGTH: 122
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaLanguagesRegisterInlayHintsProvider() async throws {}

// PATH: languages.CodeActionContext
// ORDINAL: 46
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: CodeActionContext
// SOURCE-LINE: 7172
// DECLARATION-SHA256: 3a8d75eb7f55a5705303aedd3a5cfc3b3cf834aa2c3582672d1e53709548f378
// DECLARATION-TEXT-LENGTH: 307
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesCodeActionContext {}

// PATH: languages.CodeActionProvider
// ORDINAL: 47
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: CodeActionProvider
// SOURCE-LINE: 7191
// DECLARATION-SHA256: a08c744f7a8e272a8d1c1d7956b4e893276dfd8633bbd82cfbce9fbad2b579b0
// DECLARATION-TEXT-LENGTH: 443
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesCodeActionProvider {}

// PATH: languages.CodeActionProviderMetadata
// ORDINAL: 48
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: CodeActionProviderMetadata
// SOURCE-LINE: 7205
// DECLARATION-SHA256: 3bf838ce6d8c252f4359fc0ff6f96f6092fb14ad659552df6618b5ea71925b25
// DECLARATION-TEXT-LENGTH: 692
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesCodeActionProviderMetadata {}

// PATH: languages.LineCommentConfig
// ORDINAL: 49
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: LineCommentConfig
// SOURCE-LINE: 7224
// DECLARATION-SHA256: a06c4b9466aa4c6f60d243bc79e6710cdd50f7edfcbdd081a3a51dc30b683862
// DECLARATION-TEXT-LENGTH: 253
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesLineCommentConfig {}

// PATH: languages.CommentRule
// ORDINAL: 50
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: CommentRule
// SOURCE-LINE: 7239
// DECLARATION-SHA256: 4f23b6fb5226edbc930e5f0576437356643f4e7d4aebbb733a728f3b974fb5fc
// DECLARATION-TEXT-LENGTH: 356
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesCommentRule {}

// PATH: languages.LanguageConfiguration
// ORDINAL: 51
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: LanguageConfiguration
// SOURCE-LINE: 7255
// DECLARATION-SHA256: 617b861189c4d7d26afdaacce9129ff5c4dc64dfc4cbdd25222b9bf8dd52f835
// DECLARATION-TEXT-LENGTH: 2228
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesLanguageConfiguration {}

// PATH: languages.IndentationRule
// ORDINAL: 52
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IndentationRule
// SOURCE-LINE: 7320
// DECLARATION-SHA256: 358aaae68f2cf9967f8af5f7eacb093fc8ee6000d929d0b30e8af9213be14f26
// DECLARATION-TEXT-LENGTH: 708
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesIndentationRule {}

// PATH: languages.FoldingMarkers
// ORDINAL: 53
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: FoldingMarkers
// SOURCE-LINE: 7344
// DECLARATION-SHA256: bdf5331e21940f8f65c0ea0fb1f74aa0b03194eb73c2546b920e04a82358d592
// DECLARATION-TEXT-LENGTH: 68
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesFoldingMarkers {}

// PATH: languages.FoldingRules
// ORDINAL: 54
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: FoldingRules
// SOURCE-LINE: 7352
// DECLARATION-SHA256: 0653739cfd3f5bda1255530df1ff3b9c05d142f43b3c3f73100ddc946cb4b04f
// DECLARATION-TEXT-LENGTH: 540
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesFoldingRules {}

// PATH: languages.OnEnterRule
// ORDINAL: 55
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: OnEnterRule
// SOURCE-LINE: 7369
// DECLARATION-SHA256: 2708fd99d36645d468d0f8fb83ed1a74fb6d0d4c6520285e3440504672b77774
// DECLARATION-TEXT-LENGTH: 494
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesOnEnterRule {}

// PATH: languages.IDocComment
// ORDINAL: 56
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IDocComment
// SOURCE-LINE: 7391
// DECLARATION-SHA256: 68cb9b6338f9537cd04fc4fe98b7bf6cca9a11f32befc0dc59c2cc04ebf1580b
// DECLARATION-TEXT-LENGTH: 234
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesIDocComment {}

// PATH: languages.CharacterPair
// ORDINAL: 57
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: type
// RESOLVED-KIND: type
// BASELINE: CharacterPair
// SOURCE-LINE: 7406
// DECLARATION-SHA256: 107e472c2cf8a31fddf18dc056af28f386dbb06249315beec4d7f668a4bfa307
// DECLARATION-TEXT-LENGTH: 45
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public struct MonaLanguagesCharacterPair {}

// PATH: languages.IAutoClosingPair
// ORDINAL: 58
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IAutoClosingPair
// SOURCE-LINE: 7408
// DECLARATION-SHA256: aea1e92de22527eff4cce08da49d41fee1abd770e7b32f465c31c6b3800d1904
// DECLARATION-TEXT-LENGTH: 71
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesIAutoClosingPair {}

// PATH: languages.IAutoClosingPairConditional
// ORDINAL: 59
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IAutoClosingPairConditional
// SOURCE-LINE: 7413
// DECLARATION-SHA256: 61a6c81a820409d38df5a236d7c918098f8d2e299d95080c7a3fbca63740e6a3
// DECLARATION-TEXT-LENGTH: 94
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesIAutoClosingPairConditional {}

// PATH: languages.IndentAction
// ORDINAL: 60
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: IndentAction
// SOURCE-LINE: 7420
// DECLARATION-SHA256: e8d6be76b22d47671346534f62b6d34144ec8af83fa5b4cbb27a9f4ae1466a17
// DECLARATION-TEXT-LENGTH: 508
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaLanguagesIndentAction {}

// PATH: languages.EnterAction
// ORDINAL: 61
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: EnterAction
// SOURCE-LINE: 7444
// DECLARATION-SHA256: 7793fc8d815a95c15798acb3a9915dd6e7f07689af00824d16334bc10282ea37
// DECLARATION-TEXT-LENGTH: 356
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesEnterAction {}

// PATH: languages.SyntaxNode
// ORDINAL: 62
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: SyntaxNode
// SOURCE-LINE: 7459
// DECLARATION-SHA256: c5dfd55523fd42770a2924ee370d96a87ff19e82fec50e8b5b7a3034e6b7deea
// DECLARATION-TEXT-LENGTH: 128
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesSyntaxNode {}

// PATH: languages.QueryCapture
// ORDINAL: 63
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: QueryCapture
// SOURCE-LINE: 7466
// DECLARATION-SHA256: 4b687feae1ab1db91c03dec4f4246139fbc9c4ade0e4cf817d0a6a224b4dc971
// DECLARATION-TEXT-LENGTH: 116
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesQueryCapture {}

// PATH: languages.IState
// ORDINAL: 64
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IState
// SOURCE-LINE: 7478
// DECLARATION-SHA256: b62907ab229121f7dee9f15c228f3eaef33247a896f5f41814a040c4e2bdb800
// DECLARATION-TEXT-LENGTH: 81
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesIState {}

// PATH: languages.ProviderResult
// ORDINAL: 65
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: type
// RESOLVED-KIND: type
// BASELINE: ProviderResult
// SOURCE-LINE: 7489
// DECLARATION-SHA256: c377ff4685f46683fa5dcef8861373cc21d771a9a655acbb70d502f08538ffb0
// DECLARATION-TEXT-LENGTH: 86
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public struct MonaLanguagesProviderResult {}

// PATH: languages.Hover
// ORDINAL: 66
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: Hover
// SOURCE-LINE: 7495
// DECLARATION-SHA256: 9dad73ef056cceb580f19850c78700f0fbaa55f3637373556c17227e1d8f68b8
// DECLARATION-TEXT-LENGTH: 469
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesHover {}

// PATH: languages.HoverProvider
// ORDINAL: 67
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: HoverProvider
// SOURCE-LINE: 7520
// DECLARATION-SHA256: 0bb312471dca18205cf5464e29d966ff1c6203d6bc58d7d034e74e2ff7b9cad1
// DECLARATION-TEXT-LENGTH: 439
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesHoverProvider {}

// PATH: languages.HoverContext
// ORDINAL: 68
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: HoverContext
// SOURCE-LINE: 7529
// DECLARATION-SHA256: e761e22f979cc6499277e3f4fbf8558d56a0a877e78420a24a640df0068048ec
// DECLARATION-TEXT-LENGTH: 143
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesHoverContext {}

// PATH: languages.HoverVerbosityRequest
// ORDINAL: 69
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: HoverVerbosityRequest
// SOURCE-LINE: 7536
// DECLARATION-SHA256: 9e18fb237bc7323477335bc80d6c3f4bf41aba2223ea5347c46651e932e5b6d0
// DECLARATION-TEXT-LENGTH: 251
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesHoverVerbosityRequest {}

// PATH: languages.HoverVerbosityAction
// ORDINAL: 70
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: HoverVerbosityAction
// SOURCE-LINE: 7547
// DECLARATION-SHA256: 8d34d6e9d9c162d49f5eb5bf8e389201197921392ed6b7d615ba2ab988d810a0
// DECLARATION-TEXT-LENGTH: 174
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaLanguagesHoverVerbosityAction {}

// PATH: languages.CompletionItemKind
// ORDINAL: 71
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: CompletionItemKind
// SOURCE-LINE: 7558
// DECLARATION-SHA256: da62c19745a3696dbdbad7faa5f891428a494c6bf8858e82a03b3da5a0c5277c
// DECLARATION-TEXT-LENGTH: 480
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaLanguagesCompletionItemKind {}

// PATH: languages.CompletionItemLabel
// ORDINAL: 72
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: CompletionItemLabel
// SOURCE-LINE: 7590
// DECLARATION-SHA256: 6f042d29fe15f5aa2b3df2cc1b04eb1c0c43c6a27a6346f1026d76a08f9fdf11
// DECLARATION-TEXT-LENGTH: 101
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesCompletionItemLabel {}

// PATH: languages.CompletionItemTag
// ORDINAL: 73
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: CompletionItemTag
// SOURCE-LINE: 7596
// DECLARATION-SHA256: 6301b7237fd9cedf2e8ec3911ce8aaa7347cb3001fe498e1d496bd4b8d656edc
// DECLARATION-TEXT-LENGTH: 51
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaLanguagesCompletionItemTag {}

// PATH: languages.CompletionItemInsertTextRule
// ORDINAL: 74
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: CompletionItemInsertTextRule
// SOURCE-LINE: 7600
// DECLARATION-SHA256: 55e022ada928740e7e60e865c5db4c4ec9b0753a886cc9258b0db6301c72a680
// DECLARATION-TEXT-LENGTH: 262
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaLanguagesCompletionItemInsertTextRule {}

// PATH: languages.CompletionItemRanges
// ORDINAL: 75
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: CompletionItemRanges
// SOURCE-LINE: 7613
// DECLARATION-SHA256: 8b78ed4669c04a65e95d86d08ca597f89d6c3815058d31d8f8cd850fce357355
// DECLARATION-TEXT-LENGTH: 79
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesCompletionItemRanges {}

// PATH: languages.CompletionItem
// ORDINAL: 76
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: CompletionItem
// SOURCE-LINE: 7622
// DECLARATION-SHA256: 138de77ceb682ebabf6e9b54475ec300b8d432995c8c6da701c3b4f3a31f2bb2
// DECLARATION-TEXT-LENGTH: 2774
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesCompletionItem {}

// PATH: languages.CompletionList
// ORDINAL: 77
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: CompletionList
// SOURCE-LINE: 7705
// DECLARATION-SHA256: 70100ec10481a00081f6bcc4f8d44cf494673d52613837d93cb7ba29d2150b50
// DECLARATION-TEXT-LENGTH: 113
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesCompletionList {}

// PATH: languages.PartialAcceptInfo
// ORDINAL: 78
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: PartialAcceptInfo
// SOURCE-LINE: 7714
// DECLARATION-SHA256: c99e340a43c2d7db1e317a667520a7e4e62e16d88bebcca2532a4c0aa4b99d9d
// DECLARATION-TEXT-LENGTH: 99
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesPartialAcceptInfo {}

// PATH: languages.PartialAcceptTriggerKind
// ORDINAL: 79
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: PartialAcceptTriggerKind
// SOURCE-LINE: 7722
// DECLARATION-SHA256: 80a95a1c023f99983be90b9f7f3dbee0c9dfeccb4b45bfc02d5c3ced540a56bd
// DECLARATION-TEXT-LENGTH: 79
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaLanguagesPartialAcceptTriggerKind {}

// PATH: languages.CompletionTriggerKind
// ORDINAL: 80
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: CompletionTriggerKind
// SOURCE-LINE: 7731
// DECLARATION-SHA256: f98eec7c9f660c3e832e7fd8721e9f6410ee05bb8226edff6b6a2941725c0be1
// DECLARATION-TEXT-LENGTH: 114
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaLanguagesCompletionTriggerKind {}

// PATH: languages.CompletionContext
// ORDINAL: 81
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: CompletionContext
// SOURCE-LINE: 7741
// DECLARATION-SHA256: 6854b53f1ca4518203286dfae6397fa9738b8fb488bd340fabd1ca39b2101db2
// DECLARATION-TEXT-LENGTH: 297
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesCompletionContext {}

// PATH: languages.CompletionItemProvider
// ORDINAL: 82
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: CompletionItemProvider
// SOURCE-LINE: 7765
// DECLARATION-SHA256: c30e390d420d625f974f238707583c56a6a1d8d27eda7ba79ead2e29de65c8bc
// DECLARATION-TEXT-LENGTH: 643
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesCompletionItemProvider {}

// PATH: languages.InlineCompletionTriggerKind
// ORDINAL: 83
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: InlineCompletionTriggerKind
// SOURCE-LINE: 7783
// DECLARATION-SHA256: 84b5153d3fd50b56620e1c51da6187ac373cb7684b658ceacc0cbd99f26ece78
// DECLARATION-TEXT-LENGTH: 360
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaLanguagesInlineCompletionTriggerKind {}

// PATH: languages.IInlineCompletionChangeHint
// ORDINAL: 84
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IInlineCompletionChangeHint
// SOURCE-LINE: 7800
// DECLARATION-SHA256: f9b91cf9724e3590052403f4ae7a81983871b6675692ecdcd1a33f13a5e46f67
// DECLARATION-TEXT-LENGTH: 215
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesIInlineCompletionChangeHint {}

// PATH: languages.InlineCompletionContext
// ORDINAL: 85
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: InlineCompletionContext
// SOURCE-LINE: 7808
// DECLARATION-SHA256: e538bdc0d984bb880fe1d2154e8072a9bbeaa8243708afcc0bf3e5a1d6e37cfd
// DECLARATION-TEXT-LENGTH: 621
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesInlineCompletionContext {}

// PATH: languages.IInlineCompletionModelInfo
// ORDINAL: 86
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IInlineCompletionModelInfo
// SOURCE-LINE: 7825
// DECLARATION-SHA256: 929a618d8d2a8e03fb3c178900a76460817a4fde295ab8eafbf56a8445ccdccc
// DECLARATION-TEXT-LENGTH: 110
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesIInlineCompletionModelInfo {}

// PATH: languages.IInlineCompletionModel
// ORDINAL: 87
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IInlineCompletionModel
// SOURCE-LINE: 7830
// DECLARATION-SHA256: c12abf819d0b3b558eecfd278d2064fbb430af9cf772df477d22c21fa927630d
// DECLARATION-TEXT-LENGTH: 74
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesIInlineCompletionModel {}

// PATH: languages.IInlineCompletionProviderOption
// ORDINAL: 88
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IInlineCompletionProviderOption
// SOURCE-LINE: 7835
// DECLARATION-SHA256: ad64748132f8c0fbc96947e96292a6b101e4623e195992a3b8018e782a379c22
// DECLARATION-TEXT-LENGTH: 205
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesIInlineCompletionProviderOption {}

// PATH: languages.IInlineCompletionProviderOptionValue
// ORDINAL: 89
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IInlineCompletionProviderOptionValue
// SOURCE-LINE: 7842
// DECLARATION-SHA256: 6971fb559ad3e8f9a9890ac12a3d6465200c7e5708fb14e93decf0faf963537d
// DECLARATION-TEXT-LENGTH: 107
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesIInlineCompletionProviderOptionValue {}

// PATH: languages.SelectedSuggestionInfo
// ORDINAL: 90
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: class
// RESOLVED-KIND: class
// BASELINE: SelectedSuggestionInfo
// SOURCE-LINE: 7847
// DECLARATION-SHA256: b16f4bc978a763260d2485f8e64be842e524293bf4ceb5de70b3e4796f62e146
// DECLARATION-TEXT-LENGTH: 327
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - reference identity: @MainActor final reference type; non-Sendable
public final class MonaLanguagesSelectedSuggestionInfo {}

// PATH: languages.InlineCompletion
// ORDINAL: 91
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: InlineCompletion
// SOURCE-LINE: 7856
// DECLARATION-SHA256: 5c9503964cef5a17635bd52fc14306494865ac49281867e63dc388bf60d6d5d3
// DECLARATION-TEXT-LENGTH: 2002
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesInlineCompletion {}

// PATH: languages.InlineCompletionWarning
// ORDINAL: 92
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: InlineCompletionWarning
// SOURCE-LINE: 7915
// DECLARATION-SHA256: b8fc43ddd5a3b2a88546b1fc3405bec1257c40a294507eba67602706a17a5e76
// DECLARATION-TEXT-LENGTH: 101
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesInlineCompletionWarning {}

// PATH: languages.InlineCompletionHintStyle
// ORDINAL: 93
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: InlineCompletionHintStyle
// SOURCE-LINE: 7920
// DECLARATION-SHA256: 275081b81c143fe9b4309aff0ee1b5fe19b14cb4820dd1e629cc6eed4707c25b
// DECLARATION-TEXT-LENGTH: 66
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaLanguagesInlineCompletionHintStyle {}

// PATH: languages.IInlineCompletionHint
// ORDINAL: 94
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IInlineCompletionHint
// SOURCE-LINE: 7925
// DECLARATION-SHA256: dc3edd18eefb73673beccd56c7e52dfea403480c86a2a8b6aa5334ab2e07ec31
// DECLARATION-TEXT-LENGTH: 156
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesIInlineCompletionHint {}

// PATH: languages.IconPath
// ORDINAL: 95
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: type
// RESOLVED-KIND: type
// BASELINE: IconPath
// SOURCE-LINE: 7932
// DECLARATION-SHA256: aa3bf7de1a6e966748f3f063e8df759d8a264cf68beff7828510155030df0295
// DECLARATION-TEXT-LENGTH: 40
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public struct MonaLanguagesIconPath {}

// PATH: languages.InlineCompletions
// ORDINAL: 96
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: InlineCompletions
// SOURCE-LINE: 7934
// DECLARATION-SHA256: 883ee9cd134b93cc2a926d4ff5fc40f39ed757d494b799e602f5f1cd1d126870
// DECLARATION-TEXT-LENGTH: 499
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesInlineCompletions {}

// PATH: languages.InlineCompletionCommand
// ORDINAL: 97
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: type
// RESOLVED-KIND: type
// BASELINE: InlineCompletionCommand
// SOURCE-LINE: 7947
// DECLARATION-SHA256: 983772ce8b43680488bdecd8e1d2c83f362ba90a11905f88c23e94431730cefb
// DECLARATION-TEXT-LENGTH: 90
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public struct MonaLanguagesInlineCompletionCommand {}

// PATH: languages.InlineCompletionProviderGroupId
// ORDINAL: 98
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: type
// RESOLVED-KIND: type
// BASELINE: InlineCompletionProviderGroupId
// SOURCE-LINE: 7952
// DECLARATION-SHA256: dd622aced39848c82811c82f921107760ca80cc220e1434ca8bf40224f367db1
// DECLARATION-TEXT-LENGTH: 53
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public struct MonaLanguagesInlineCompletionProviderGroupId {}

// PATH: languages.InlineCompletionsProvider
// ORDINAL: 99
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: InlineCompletionsProvider
// SOURCE-LINE: 7954
// DECLARATION-SHA256: 8e0708d5ec52e265a87ea33f06c67ce77e53eaaf5d0ba6af8e9a73912e5238ba
// DECLARATION-TEXT-LENGTH: 2607
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesInlineCompletionsProvider {}

// PATH: languages.InlineCompletionsDisposeReason
// ORDINAL: 100
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: type
// RESOLVED-KIND: type
// BASELINE: InlineCompletionsDisposeReason
// SOURCE-LINE: 8007
// DECLARATION-SHA256: 68a643a2ac7db26e0f25558311da5a03c15a7b0518f5aac4d78d2346007e25ca
// DECLARATION-TEXT-LENGTH: 125
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public struct MonaLanguagesInlineCompletionsDisposeReason {}

// PATH: languages.InlineCompletionEndOfLifeReasonKind
// ORDINAL: 101
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: InlineCompletionEndOfLifeReasonKind
// SOURCE-LINE: 8011
// DECLARATION-SHA256: e59891df9c74f472e897c701e8d054d957b771ee33f77a6d06a1407a3ca18f20
// DECLARATION-TEXT-LENGTH: 98
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaLanguagesInlineCompletionEndOfLifeReasonKind {}

// PATH: languages.InlineCompletionEndOfLifeReason
// ORDINAL: 102
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: type
// RESOLVED-KIND: type
// BASELINE: InlineCompletionEndOfLifeReason
// SOURCE-LINE: 8017
// DECLARATION-SHA256: 40d71a00b2bc6c0c0038629677769a20f9eeb5ce41b201e5d3fa50f661129f0d
// DECLARATION-TEXT-LENGTH: 362
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public struct MonaLanguagesInlineCompletionEndOfLifeReason {}

// PATH: languages.LifetimeSummary
// ORDINAL: 103
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: type
// RESOLVED-KIND: type
// BASELINE: LifetimeSummary
// SOURCE-LINE: 8028
// DECLARATION-SHA256: e9ed3fe6a07dc914eef293b42db4b2963ab030c2bc261f9aa9fcf8aa8ca5de74
// DECLARATION-TEXT-LENGTH: 1469
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public struct MonaLanguagesLifetimeSummary {}

// PATH: languages.CodeAction
// ORDINAL: 104
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: CodeAction
// SOURCE-LINE: 8073
// DECLARATION-SHA256: c6c9fee63493a8fba05a4d6db0845caf3ae91fe35b1a1e1fd0616606c2c7a41d
// DECLARATION-TEXT-LENGTH: 234
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesCodeAction {}

// PATH: languages.CodeActionTriggerType
// ORDINAL: 105
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: CodeActionTriggerType
// SOURCE-LINE: 8085
// DECLARATION-SHA256: bcea3286c3953351a793099b59613ec5ff8c084b7afe8f22d608f7240ff8449d
// DECLARATION-TEXT-LENGTH: 63
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaLanguagesCodeActionTriggerType {}

// PATH: languages.CodeActionList
// ORDINAL: 106
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: CodeActionList
// SOURCE-LINE: 8090
// DECLARATION-SHA256: e4bfc99027d94a16797ceffb6ea1b14c3f720403c50323b1302f171e45fc3579
// DECLARATION-TEXT-LENGTH: 103
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesCodeActionList {}

// PATH: languages.ParameterInformation
// ORDINAL: 107
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: ParameterInformation
// SOURCE-LINE: 8098
// DECLARATION-SHA256: 343be0b838d70238b71acfc90e706256260282ee617e44924077e47e75f79fd8
// DECLARATION-TEXT-LENGTH: 314
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesParameterInformation {}

// PATH: languages.SignatureInformation
// ORDINAL: 108
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: SignatureInformation
// SOURCE-LINE: 8116
// DECLARATION-SHA256: 260b3179fdc894590f132b64f112adff3b0c92c55c2903eab96a7ed66622bbdd
// DECLARATION-TEXT-LENGTH: 541
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesSignatureInformation {}

// PATH: languages.SignatureHelp
// ORDINAL: 109
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: SignatureHelp
// SOURCE-LINE: 8144
// DECLARATION-SHA256: ba43af7b5ba9c8ccbcc716262e756aa8c1b060882acf726222cf1a7931ee0841
// DECLARATION-TEXT-LENGTH: 270
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesSignatureHelp {}

// PATH: languages.SignatureHelpResult
// ORDINAL: 110
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: SignatureHelpResult
// SOURCE-LINE: 8159
// DECLARATION-SHA256: 32ae885565e8d998049f3ed26708c6a4a88ee370555f4f2618a10df57a1f5d0d
// DECLARATION-TEXT-LENGTH: 85
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesSignatureHelpResult {}

// PATH: languages.SignatureHelpTriggerKind
// ORDINAL: 111
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: SignatureHelpTriggerKind
// SOURCE-LINE: 8163
// DECLARATION-SHA256: 8ba15c56d174eaa08a77eafc912bb16d5d3b6ea07a9da86aa48629fd6f10e62f
// DECLARATION-TEXT-LENGTH: 99
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaLanguagesSignatureHelpTriggerKind {}

// PATH: languages.SignatureHelpContext
// ORDINAL: 112
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: SignatureHelpContext
// SOURCE-LINE: 8169
// DECLARATION-SHA256: 08d5235289e0c511321caee8664f3b07160561fc465f3b5fc209ac8997949a2f
// DECLARATION-TEXT-LENGTH: 211
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesSignatureHelpContext {}

// PATH: languages.SignatureHelpProvider
// ORDINAL: 113
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: SignatureHelpProvider
// SOURCE-LINE: 8180
// DECLARATION-SHA256: 3df083bd2d62b6f2c9561851d37dab8bbd07be8e4bb8d26115791b7bf13533a9
// DECLARATION-TEXT-LENGTH: 427
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesSignatureHelpProvider {}

// PATH: languages.DocumentHighlightKind
// ORDINAL: 114
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: DocumentHighlightKind
// SOURCE-LINE: 8192
// DECLARATION-SHA256: ce0053442333f3a09b50fd263ee07f4114f8a73ef6bae374328be4af6e44f480
// DECLARATION-TEXT-LENGTH: 251
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaLanguagesDocumentHighlightKind {}

// PATH: languages.DocumentHighlight
// ORDINAL: 115
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: DocumentHighlight
// SOURCE-LINE: 8212
// DECLARATION-SHA256: fd8e6b9cb52bacc40cb0f81296b391dcc05c00e0ff5c314fa742f44c6b622b1c
// DECLARATION-TEXT-LENGTH: 231
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesDocumentHighlight {}

// PATH: languages.MultiDocumentHighlight
// ORDINAL: 116
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: MultiDocumentHighlight
// SOURCE-LINE: 8226
// DECLARATION-SHA256: 9a9d3b7b69b7cc2b9735164982aa7971f196017f8b54f7ea7842f54c05869080
// DECLARATION-TEXT-LENGTH: 220
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesMultiDocumentHighlight {}

// PATH: languages.DocumentHighlightProvider
// ORDINAL: 117
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: DocumentHighlightProvider
// SOURCE-LINE: 8241
// DECLARATION-SHA256: ff698319a41357130739aaf272b663ee58c064b7160d65b6fb45015b5d989c01
// DECLARATION-TEXT-LENGTH: 314
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesDocumentHighlightProvider {}

// PATH: languages.MultiDocumentHighlightProvider
// ORDINAL: 118
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: MultiDocumentHighlightProvider
// SOURCE-LINE: 8252
// DECLARATION-SHA256: f1171ae13030afce415aabfb608144d4b78e4cfe2e638390025d16fe169fe9d8
// DECLARATION-TEXT-LENGTH: 847
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesMultiDocumentHighlightProvider {}

// PATH: languages.LinkedEditingRangeProvider
// ORDINAL: 119
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: LinkedEditingRangeProvider
// SOURCE-LINE: 8274
// DECLARATION-SHA256: 28864e2290a3bf8c052cf3940546f03693dabcec8b75fd027b8a7bbf8d09f940
// DECLARATION-TEXT-LENGTH: 258
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesLinkedEditingRangeProvider {}

// PATH: languages.LinkedEditingRanges
// ORDINAL: 120
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: LinkedEditingRanges
// SOURCE-LINE: 8284
// DECLARATION-SHA256: a5c08c604f46533f49ec34b20f70b94ac586f264a7b29a49039928eddfb555eb
// DECLARATION-TEXT-LENGTH: 417
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesLinkedEditingRanges {}

// PATH: languages.ReferenceContext
// ORDINAL: 121
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: ReferenceContext
// SOURCE-LINE: 8301
// DECLARATION-SHA256: de06bcd9a793bba2ee9ed8dbac2f40ba704e8cf783e2d8352b33639d8e922f4c
// DECLARATION-TEXT-LENGTH: 133
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesReferenceContext {}

// PATH: languages.ReferenceProvider
// ORDINAL: 122
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: ReferenceProvider
// SOURCE-LINE: 8312
// DECLARATION-SHA256: 726f91ba7aec5c7e423d8de9d9e45e4d064cea13956fdee582f567a69282082a
// DECLARATION-TEXT-LENGTH: 282
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesReferenceProvider {}

// PATH: languages.Location
// ORDINAL: 123
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: Location
// SOURCE-LINE: 8323
// DECLARATION-SHA256: 8bcb4c0b9662557d1e2ab88baec65d55a51637267f73f8f4dde71832be6fb6f7
// DECLARATION-TEXT-LENGTH: 173
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesLocation {}

// PATH: languages.LocationLink
// ORDINAL: 124
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: LocationLink
// SOURCE-LINE: 8334
// DECLARATION-SHA256: 99da7b930c3525102700db0adb14c7df2d5a4af96b2899d4a4219c08bca8574e
// DECLARATION-TEXT-LENGTH: 407
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesLocationLink {}

// PATH: languages.Definition
// ORDINAL: 125
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: type
// RESOLVED-KIND: type
// BASELINE: Definition
// SOURCE-LINE: 8354
// DECLARATION-SHA256: 7eebefd06feb705f5f4b37f9d694603f45bbf99cf4c4f7e4fceaaae177635639
// DECLARATION-TEXT-LENGTH: 64
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public struct MonaLanguagesDefinition {}

// PATH: languages.DefinitionProvider
// ORDINAL: 126
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: DefinitionProvider
// SOURCE-LINE: 8361
// DECLARATION-SHA256: 75b4f8f61070c2423888f43c82a94368b318595c8554eea4da8b83c5ef303fe2
// DECLARATION-TEXT-LENGTH: 268
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesDefinitionProvider {}

// PATH: languages.DeclarationProvider
// ORDINAL: 127
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: DeclarationProvider
// SOURCE-LINE: 8373
// DECLARATION-SHA256: da742018392aefcf82a43569855b9b29e713ec319cbd11a7ee2e05ceb7879599
// DECLARATION-TEXT-LENGTH: 271
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesDeclarationProvider {}

// PATH: languages.ImplementationProvider
// ORDINAL: 128
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: ImplementationProvider
// SOURCE-LINE: 8384
// DECLARATION-SHA256: a9c2d28e0fbf774baa509b909d4f3b965bf7352d97b09b548d2983920b093940
// DECLARATION-TEXT-LENGTH: 280
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesImplementationProvider {}

// PATH: languages.TypeDefinitionProvider
// ORDINAL: 129
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: TypeDefinitionProvider
// SOURCE-LINE: 8395
// DECLARATION-SHA256: 09e86e4239bfe9ffae7be5d158b21f72fde01ea48c47e46456797833a6d82a9d
// DECLARATION-TEXT-LENGTH: 281
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesTypeDefinitionProvider {}

// PATH: languages.SymbolKind
// ORDINAL: 130
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: SymbolKind
// SOURCE-LINE: 8405
// DECLARATION-SHA256: cabda06a623df62a3fd364b2074a590f9fb336c38f03aa40d023f75b93f9ca20
// DECLARATION-TEXT-LENGTH: 427
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaLanguagesSymbolKind {}

// PATH: languages.SymbolTag
// ORDINAL: 131
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: SymbolTag
// SOURCE-LINE: 8434
// DECLARATION-SHA256: c25adf6e69ade67b2538da596d768ee6f145ae905873988fc1e1df96c52416d2
// DECLARATION-TEXT-LENGTH: 43
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaLanguagesSymbolTag {}

// PATH: languages.DocumentSymbol
// ORDINAL: 132
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: DocumentSymbol
// SOURCE-LINE: 8438
// DECLARATION-SHA256: fa459c29c1e2a4666a64badab9ce65dcc4384c18e26777ef0dd390e3ba1cd4ea
// DECLARATION-TEXT-LENGTH: 224
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesDocumentSymbol {}

// PATH: languages.DocumentSymbolProvider
// ORDINAL: 133
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: DocumentSymbolProvider
// SOURCE-LINE: 8453
// DECLARATION-SHA256: 96441a1880ca32d516edc057d538700206b654b9edb9bde10051d37c41e01623
// DECLARATION-TEXT-LENGTH: 248
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesDocumentSymbolProvider {}

// PATH: languages.TextEdit
// ORDINAL: 134
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: TextEdit
// SOURCE-LINE: 8461
// DECLARATION-SHA256: 2120d67d44705e3f43c5b1f55c704a14516993c1b3ae676b8641a1e3688b9241
// DECLARATION-TEXT-LENGTH: 97
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesTextEdit {}

// PATH: languages.FormattingOptions
// ORDINAL: 135
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: FormattingOptions
// SOURCE-LINE: 8470
// DECLARATION-SHA256: ce4ba19ed9fd6195162bb155957eee752168c2a9fcb180eab77cf090bee04e13
// DECLARATION-TEXT-LENGTH: 167
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesFormattingOptions {}

// PATH: languages.DocumentFormattingEditProvider
// ORDINAL: 136
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: DocumentFormattingEditProvider
// SOURCE-LINE: 8485
// DECLARATION-SHA256: 3adab024bfaa82129fb5b40e113a2b88d01808ccfd18465a89fb399b1c9df1d8
// DECLARATION-TEXT-LENGTH: 291
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesDocumentFormattingEditProvider {}

// PATH: languages.DocumentRangeFormattingEditProvider
// ORDINAL: 137
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: DocumentRangeFormattingEditProvider
// SOURCE-LINE: 8497
// DECLARATION-SHA256: fa47b9720ff253c24754af6c0baa3b6c656e5a8e5885d2535da7725654fa8f96
// DECLARATION-TEXT-LENGTH: 679
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesDocumentRangeFormattingEditProvider {}

// PATH: languages.OnTypeFormattingEditProvider
// ORDINAL: 138
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: OnTypeFormattingEditProvider
// SOURCE-LINE: 8514
// DECLARATION-SHA256: ba399c6704cec24231b790b49ace4155255ff859beee307488c4182b2a0b1188
// DECLARATION-TEXT-LENGTH: 512
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesOnTypeFormattingEditProvider {}

// PATH: languages.ILink
// ORDINAL: 139
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: ILink
// SOURCE-LINE: 8529
// DECLARATION-SHA256: 943f7d2d74bdd2c494061a480eb5ba97938dbcd21a886d4dda27266d87e2f79c
// DECLARATION-TEXT-LENGTH: 86
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesILink {}

// PATH: languages.ILinksList
// ORDINAL: 140
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: ILinksList
// SOURCE-LINE: 8535
// DECLARATION-SHA256: c5408ec53894b69b52b3be1d43ac37f479af98e25b9fd21a877f39b716b2eacb
// DECLARATION-TEXT-LENGTH: 70
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesILinksList {}

// PATH: languages.LinkProvider
// ORDINAL: 141
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: LinkProvider
// SOURCE-LINE: 8543
// DECLARATION-SHA256: d029cc1dadd5c18e1b7151e119f309ec8c2f4c92300bad459df134ae95bc7ee7
// DECLARATION-TEXT-LENGTH: 212
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesLinkProvider {}

// PATH: languages.IColor
// ORDINAL: 142
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IColor
// SOURCE-LINE: 8551
// DECLARATION-SHA256: ddff0b1705f5d76e460b9bd63bae2b7f4c8a995c1721f46be1ab81d24ab4da08
// DECLARATION-TEXT-LENGTH: 354
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesIColor {}

// PATH: languages.IColorPresentation
// ORDINAL: 143
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IColorPresentation
// SOURCE-LINE: 8573
// DECLARATION-SHA256: 2b7110e08ea4ac3f81cc0328cb2441c2b42dafda3ad3a2b3db6925402dbbd491
// DECLARATION-TEXT-LENGTH: 581
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesIColorPresentation {}

// PATH: languages.IColorInformation
// ORDINAL: 144
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IColorInformation
// SOURCE-LINE: 8595
// DECLARATION-SHA256: ac4b7f7e808620352f4caa9501cd21af5cbb89b99cce8bcbf97f6bab5498358a
// DECLARATION-TEXT-LENGTH: 172
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesIColorInformation {}

// PATH: languages.DocumentColorProvider
// ORDINAL: 145
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: DocumentColorProvider
// SOURCE-LINE: 8609
// DECLARATION-SHA256: 2e30cb7b2fc91fe83472fadf86e77af230549dfb3c1f1709ebafb70a65ccf498
// DECLARATION-TEXT-LENGTH: 436
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesDocumentColorProvider {}

// PATH: languages.SelectionRange
// ORDINAL: 146
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: SelectionRange
// SOURCE-LINE: 8620
// DECLARATION-SHA256: 26a3f56bd908243c885bf8c0f105d8433e1224371793df23a11d2ac910b4f0ae
// DECLARATION-TEXT-LENGTH: 53
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesSelectionRange {}

// PATH: languages.SelectionRangeProvider
// ORDINAL: 147
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: SelectionRangeProvider
// SOURCE-LINE: 8624
// DECLARATION-SHA256: aff8aa0d44ceab7c6e71495a2c2c3e42f8fe1fb8c9eccdfd2f6b48fba69ee285
// DECLARATION-TEXT-LENGTH: 262
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesSelectionRangeProvider {}

// PATH: languages.FoldingContext
// ORDINAL: 148
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: FoldingContext
// SOURCE-LINE: 8631
// DECLARATION-SHA256: c319a2f75f457f4371865b2a6ea622ad00021f7f25154daf336516bc7bebb6c1
// DECLARATION-TEXT-LENGTH: 36
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesFoldingContext {}

// PATH: languages.FoldingRangeProvider
// ORDINAL: 149
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: FoldingRangeProvider
// SOURCE-LINE: 8637
// DECLARATION-SHA256: 9c591002eeb264291930bc1d6f6b026966ae0b3952dd43afed1630ef94401f45
// DECLARATION-TEXT-LENGTH: 374
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesFoldingRangeProvider {}

// PATH: languages.FoldingRange
// ORDINAL: 150
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: FoldingRange
// SOURCE-LINE: 8648
// DECLARATION-SHA256: 37862565ecc799f951908d5b72ce71eecab3822fdd9f462149a1cf03e930562d
// DECLARATION-TEXT-LENGTH: 681
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesFoldingRange {}

// PATH: languages.FoldingRangeKind
// ORDINAL: 151
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: class
// RESOLVED-KIND: class
// BASELINE: FoldingRangeKind
// SOURCE-LINE: 8666
// DECLARATION-SHA256: 34cfd6533a527ecf6a74baba838b7068614e9e94dc38c7a3a7aeccff9c016a04
// DECLARATION-TEXT-LENGTH: 819
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - reference identity: @MainActor final reference type; non-Sendable
public final class MonaLanguagesFoldingRangeKind {}

// PATH: languages.WorkspaceEditMetadata
// ORDINAL: 152
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: WorkspaceEditMetadata
// SOURCE-LINE: 8695
// DECLARATION-SHA256: d37168304f8ab48867abea6890aa392645b9df66186b7678c8e1feff95bf54e6
// DECLARATION-TEXT-LENGTH: 114
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesWorkspaceEditMetadata {}

// PATH: languages.WorkspaceFileEditOptions
// ORDINAL: 153
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: WorkspaceFileEditOptions
// SOURCE-LINE: 8701
// DECLARATION-SHA256: 43025a7257a37689e1e572602d2c195769c4c22dec4999bb68b1b5d224ec5349
// DECLARATION-TEXT-LENGTH: 235
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesWorkspaceFileEditOptions {}

// PATH: languages.IWorkspaceFileEdit
// ORDINAL: 154
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IWorkspaceFileEdit
// SOURCE-LINE: 8712
// DECLARATION-SHA256: a5925ee5b125bd90af88a1e851248ac213aaf5ddc373c7391d788930e2726e31
// DECLARATION-TEXT-LENGTH: 156
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesIWorkspaceFileEdit {}

// PATH: languages.IWorkspaceTextEdit
// ORDINAL: 155
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IWorkspaceTextEdit
// SOURCE-LINE: 8719
// DECLARATION-SHA256: 97b84b55ba23f879ed3f33be1b7cc22c909467b6d69e2db42b900b9cb6d6e6b9
// DECLARATION-TEXT-LENGTH: 215
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesIWorkspaceTextEdit {}

// PATH: languages.WorkspaceEdit
// ORDINAL: 156
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: WorkspaceEdit
// SOURCE-LINE: 8729
// DECLARATION-SHA256: a9a1159eb3f4c1b5ca76d6ca12a2afdc8885c437719eb047cc63acece070cb31
// DECLARATION-TEXT-LENGTH: 106
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesWorkspaceEdit {}

// PATH: languages.ICustomEdit
// ORDINAL: 157
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: ICustomEdit
// SOURCE-LINE: 8733
// DECLARATION-SHA256: 52a47b75d362186bf77f91e309404a7b4404880857121138ab632e684d799ccc
// DECLARATION-TEXT-LENGTH: 168
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesICustomEdit {}

// PATH: languages.Rejection
// ORDINAL: 158
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: Rejection
// SOURCE-LINE: 8740
// DECLARATION-SHA256: 3fcce82d1927e13c625828a32b9d1deb067bc3e85cd277c5ebaba20d26eae959
// DECLARATION-TEXT-LENGTH: 56
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesRejection {}

// PATH: languages.RenameLocation
// ORDINAL: 159
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: RenameLocation
// SOURCE-LINE: 8744
// DECLARATION-SHA256: 8843e84be7efcc1b0d8fc9b2af08142225e1de4f44ee3e06c1d477a0704eb1b9
// DECLARATION-TEXT-LENGTH: 69
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesRenameLocation {}

// PATH: languages.RenameProvider
// ORDINAL: 160
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: RenameProvider
// SOURCE-LINE: 8749
// DECLARATION-SHA256: fc74ce4e2961479a38b3ee87c206329016c415589db3209f7757123f05cf404c
// DECLARATION-TEXT-LENGTH: 332
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesRenameProvider {}

// PATH: languages.NewSymbolNameTag
// ORDINAL: 161
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: NewSymbolNameTag
// SOURCE-LINE: 8754
// DECLARATION-SHA256: 018ed64a31eb55139e6074a73ba443cda6d8d06fde087299364a82012bf3a831
// DECLARATION-TEXT-LENGTH: 51
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaLanguagesNewSymbolNameTag {}

// PATH: languages.NewSymbolNameTriggerKind
// ORDINAL: 162
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: NewSymbolNameTriggerKind
// SOURCE-LINE: 8758
// DECLARATION-SHA256: 0458821771a50e97eed19543a226a721a9df6c4be2e205d787f7e669b6d66837
// DECLARATION-TEXT-LENGTH: 71
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaLanguagesNewSymbolNameTriggerKind {}

// PATH: languages.NewSymbolName
// ORDINAL: 163
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: NewSymbolName
// SOURCE-LINE: 8763
// DECLARATION-SHA256: 4585a7e8f6d6579c5837d91531721d83691516e3f9f2a83dc63447f695c27eb2
// DECLARATION-TEXT-LENGTH: 116
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesNewSymbolName {}

// PATH: languages.NewSymbolNamesProvider
// ORDINAL: 164
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: NewSymbolNamesProvider
// SOURCE-LINE: 8768
// DECLARATION-SHA256: fe98e2671498ac25ae1052d69d133ae3a541951ebc9aea87e9769a610f6df514
// DECLARATION-TEXT-LENGTH: 285
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesNewSymbolNamesProvider {}

// PATH: languages.Command
// ORDINAL: 165
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: Command
// SOURCE-LINE: 8773
// DECLARATION-SHA256: 45550b5e1bb734558fedd1fcb12080a565c65efc001a9900076037a39e7e3e33
// DECLARATION-TEXT-LENGTH: 105
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesCommand {}

// PATH: languages.CommentThreadRevealOptions
// ORDINAL: 166
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: CommentThreadRevealOptions
// SOURCE-LINE: 8780
// DECLARATION-SHA256: 0f6727b80d913dc69af581b25e5934f1304aa6dac97d0ce8d1864f2602939cea
// DECLARATION-TEXT-LENGTH: 97
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesCommentThreadRevealOptions {}

// PATH: languages.CommentAuthorInformation
// ORDINAL: 167
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: CommentAuthorInformation
// SOURCE-LINE: 8785
// DECLARATION-SHA256: 41ffc3d5db0bf116d18e328a4e6bfbc2fcc60c58fe2d00a03042e5407dc7d1bb
// DECLARATION-TEXT-LENGTH: 90
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesCommentAuthorInformation {}

// PATH: languages.PendingCommentThread
// ORDINAL: 168
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: PendingCommentThread
// SOURCE-LINE: 8790
// DECLARATION-SHA256: e0c2d5eda7596f310b74464c73f535e536552e5a957f56430fb883160b3d7533
// DECLARATION-TEXT-LENGTH: 153
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesPendingCommentThread {}

// PATH: languages.PendingComment
// ORDINAL: 169
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: PendingComment
// SOURCE-LINE: 8798
// DECLARATION-SHA256: 93b079ec5444f5ddf5f0e5c9169ed2e5b0c7f51065af586acfe43b99a1b60c3f
// DECLARATION-TEXT-LENGTH: 73
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesPendingComment {}

// PATH: languages.CodeLens
// ORDINAL: 170
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: CodeLens
// SOURCE-LINE: 8803
// DECLARATION-SHA256: 55064e37ec653b7c497113fe5859b2e68059b3916c59df06beef0bf7ee8d733f
// DECLARATION-TEXT-LENGTH: 83
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesCodeLens {}

// PATH: languages.CodeLensList
// ORDINAL: 171
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: CodeLensList
// SOURCE-LINE: 8809
// DECLARATION-SHA256: 33fb935beaf60b7f94c6541e122eec26860289dee401cf2d3396b2ac5aa619f9
// DECLARATION-TEXT-LENGTH: 94
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesCodeLensList {}

// PATH: languages.CodeLensProvider
// ORDINAL: 172
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: CodeLensProvider
// SOURCE-LINE: 8814
// DECLARATION-SHA256: 7ced2179d446a462ed08ac45f7fee07a8115916d8d71e0b8e2e7016d93ad40a0
// DECLARATION-TEXT-LENGTH: 289
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesCodeLensProvider {}

// PATH: languages.InlayHintKind
// ORDINAL: 173
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: enum
// RESOLVED-KIND: enum
// BASELINE: InlayHintKind
// SOURCE-LINE: 8820
// DECLARATION-SHA256: e41c4054a916ef05b0d8549c380bc921383fe8e372946a94944bda59ffc9d1f5
// DECLARATION-TEXT-LENGTH: 58
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - extensible raw value: future cases append without reordering
public enum MonaLanguagesInlayHintKind {}

// PATH: languages.InlayHintLabelPart
// ORDINAL: 174
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: InlayHintLabelPart
// SOURCE-LINE: 8825
// DECLARATION-SHA256: ec04625ee3aa351895020b5410cdf33d131ed39ac86e177f05554ae5729a96d9
// DECLARATION-TEXT-LENGTH: 139
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesInlayHintLabelPart {}

// PATH: languages.InlayHint
// ORDINAL: 175
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: InlayHint
// SOURCE-LINE: 8832
// DECLARATION-SHA256: 4d88a676a358ad9ab08f39a7f7c1470adcfa74ca7187cac313f61053f72e5386
// DECLARATION-TEXT-LENGTH: 233
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesInlayHint {}

// PATH: languages.InlayHintList
// ORDINAL: 176
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: InlayHintList
// SOURCE-LINE: 8842
// DECLARATION-SHA256: eb0806e9a7b27554214ba5ca2302dc62dee0eac69eabd40b869214675161dcae
// DECLARATION-TEXT-LENGTH: 76
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesInlayHintList {}

// PATH: languages.InlayHintsProvider
// ORDINAL: 177
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: InlayHintsProvider
// SOURCE-LINE: 8847
// DECLARATION-SHA256: c8bde97e520671005d88eb5fdc32665d4cacda8cd03b2e3af39186f53ee2aa41
// DECLARATION-TEXT-LENGTH: 313
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesInlayHintsProvider {}

// PATH: languages.SemanticTokensLegend
// ORDINAL: 178
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: SemanticTokensLegend
// SOURCE-LINE: 8854
// DECLARATION-SHA256: b3d3c50c99861794f29b0a341d353c8117f44656787b8b23b767bc1190acd093
// DECLARATION-TEXT-LENGTH: 112
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesSemanticTokensLegend {}

// PATH: languages.SemanticTokens
// ORDINAL: 179
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: SemanticTokens
// SOURCE-LINE: 8859
// DECLARATION-SHA256: 006b9f3ee8d4198539f727c4ffdd6b90f143cbf8d6d86a16174ccb3c749499f3
// DECLARATION-TEXT-LENGTH: 96
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesSemanticTokens {}

// PATH: languages.SemanticTokensEdit
// ORDINAL: 180
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: SemanticTokensEdit
// SOURCE-LINE: 8864
// DECLARATION-SHA256: 331c4e985e24ebb1678fcadd7a787a051712416c99c78a80f0f780781787e309
// DECLARATION-TEXT-LENGTH: 129
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesSemanticTokensEdit {}

// PATH: languages.SemanticTokensEdits
// ORDINAL: 181
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: SemanticTokensEdits
// SOURCE-LINE: 8870
// DECLARATION-SHA256: f0d69e6a0fa67ae7aeaec6dad2505e23975843b8459837506c6e839ffa46d9ce
// DECLARATION-TEXT-LENGTH: 111
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesSemanticTokensEdits {}

// PATH: languages.DocumentSemanticTokensProvider
// ORDINAL: 182
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: DocumentSemanticTokensProvider
// SOURCE-LINE: 8875
// DECLARATION-SHA256: bc4baedcdb1ff4db2dd70a6707db19bd77468c2b4185c59a951521f7641a3caf
// DECLARATION-TEXT-LENGTH: 365
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesDocumentSemanticTokensProvider {}

// PATH: languages.DocumentRangeSemanticTokensProvider
// ORDINAL: 183
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: DocumentRangeSemanticTokensProvider
// SOURCE-LINE: 8882
// DECLARATION-SHA256: 487325d2442440fec2a1b6cb2eb91c154df6c26629839f4c637b9d289bb1b466
// DECLARATION-TEXT-LENGTH: 269
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesDocumentRangeSemanticTokensProvider {}

// PATH: languages.ILanguageExtensionPoint
// ORDINAL: 184
// DISPOSITION: retained-native-mapping
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: ILanguageExtensionPoint
// SOURCE-LINE: 8888
// DECLARATION-SHA256: d7f8473eac9d64a5748b995ed8fad0a98c2352c03bcf18ebee4b71e99c01b34d
// DECLARATION-TEXT-LENGTH: 230
//   - native mapping: one-to-one Swift symbol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaLanguagesILanguageExtensionPoint {}

// PATH: languages.IMonarchLanguage
// ORDINAL: 185
// DISPOSITION: cut-monarch-api-or-type
// SOURCE-KIND: interface
// BASELINE: IMonarchLanguage
// SOURCE-LINE: 8901
// DECLARATION-SHA256: 8c42c7d4ac241849dc26132e91175a0846996e9a93056ddde5820fc75f2373ce
// DECLARATION-TEXT-LENGTH: 957
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: Monarch is an accepted complete language-content cut; retaining it would make a cut type reachable

// PATH: languages.IShortMonarchLanguageRule1
// ORDINAL: 186
// DISPOSITION: cut-monarch-api-or-type
// SOURCE-KIND: type
// BASELINE: IShortMonarchLanguageRule1
// SOURCE-LINE: 8948
// DECLARATION-SHA256: 847d516dff9abd1645b9945291804db3422d0673f270a179a115b0c81d594307
// DECLARATION-TEXT-LENGTH: 83
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: Monarch is an accepted complete language-content cut; retaining it would make a cut type reachable

// PATH: languages.IShortMonarchLanguageRule2
// ORDINAL: 187
// DISPOSITION: cut-monarch-api-or-type
// SOURCE-KIND: type
// BASELINE: IShortMonarchLanguageRule2
// SOURCE-LINE: 8950
// DECLARATION-SHA256: 7e64127f7cbe6151d779f6a97df4d3230ad4b6533dd96b1b7636b1703effe670
// DECLARATION-TEXT-LENGTH: 91
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: Monarch is an accepted complete language-content cut; retaining it would make a cut type reachable

// PATH: languages.IExpandedMonarchLanguageRule
// ORDINAL: 188
// DISPOSITION: cut-monarch-api-or-type
// SOURCE-KIND: interface
// BASELINE: IExpandedMonarchLanguageRule
// SOURCE-LINE: 8952
// DECLARATION-SHA256: b8dc1eece18030ee3a7b1626dd9a9137f1ddbbff8b0523b9aeb162f49623de1c
// DECLARATION-TEXT-LENGTH: 282
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: Monarch is an accepted complete language-content cut; retaining it would make a cut type reachable

// PATH: languages.IMonarchLanguageRule
// ORDINAL: 189
// DISPOSITION: cut-monarch-api-or-type
// SOURCE-KIND: type
// BASELINE: IMonarchLanguageRule
// SOURCE-LINE: 8967
// DECLARATION-SHA256: 500ae57a63221a7c547c85e60a554d14db58d02042d19b70bbc5efd966234ea0
// DECLARATION-TEXT-LENGTH: 122
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: Monarch is an accepted complete language-content cut; retaining it would make a cut type reachable

// PATH: languages.IShortMonarchLanguageAction
// ORDINAL: 190
// DISPOSITION: cut-monarch-api-or-type
// SOURCE-KIND: type
// BASELINE: IShortMonarchLanguageAction
// SOURCE-LINE: 8974
// DECLARATION-SHA256: 33e91a251db35edb0293f85ecdb040cef5a91956c97993181d5f55d7bb5f2199
// DECLARATION-TEXT-LENGTH: 49
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: Monarch is an accepted complete language-content cut; retaining it would make a cut type reachable

// PATH: languages.IExpandedMonarchLanguageAction
// ORDINAL: 191
// DISPOSITION: cut-monarch-api-or-type
// SOURCE-KIND: interface
// BASELINE: IExpandedMonarchLanguageAction
// SOURCE-LINE: 8976
// DECLARATION-SHA256: 9f932b97811e94b679488f073403a200fa962da0b43cc02a0f0a7b4a6ec339b9
// DECLARATION-TEXT-LENGTH: 784
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: Monarch is an accepted complete language-content cut; retaining it would make a cut type reachable

// PATH: languages.IMonarchLanguageAction
// ORDINAL: 192
// DISPOSITION: cut-monarch-api-or-type
// SOURCE-KIND: type
// BASELINE: IMonarchLanguageAction
// SOURCE-LINE: 9015
// DECLARATION-SHA256: 75626e38a660dfd7a23c64b4f8f533465ed5ba7695e7ac7333eab64b44bacb73
// DECLARATION-TEXT-LENGTH: 165
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: Monarch is an accepted complete language-content cut; retaining it would make a cut type reachable

// PATH: languages.IMonarchLanguageBracket
// ORDINAL: 193
// DISPOSITION: cut-monarch-api-or-type
// SOURCE-KIND: interface
// BASELINE: IMonarchLanguageBracket
// SOURCE-LINE: 9020
// DECLARATION-SHA256: 2e520c9d7782ffc060acf2425f2427df03265b6c8707419eb5479d5433f27464
// DECLARATION-TEXT-LENGTH: 187
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: Monarch is an accepted complete language-content cut; retaining it would make a cut type reachable

// PATH: languages.css
// ORDINAL: 194
// DISPOSITION: cut-deprecated-builtin-pack-alias
// SOURCE-KIND: const
// BASELINE: css
// SOURCE-LINE: 10227
// DECLARATION-SHA256: f10e9a5c976ffc9c063dc510b7c19363c82092688d3987cf92ff8cf33a4d1246
// DECLARATION-TEXT-LENGTH: 39
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: deprecated d.ts-only alias of a cut builtin language pack

// PATH: languages.html
// ORDINAL: 195
// DISPOSITION: cut-deprecated-builtin-pack-alias
// SOURCE-KIND: const
// BASELINE: html
// SOURCE-LINE: 10230
// DECLARATION-SHA256: 6083e3d0a9c93c771537f740629eac9a7ccc8ba04833b273eb06a5e9774119db
// DECLARATION-TEXT-LENGTH: 40
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: deprecated d.ts-only alias of a cut builtin language pack

// PATH: languages.json
// ORDINAL: 196
// DISPOSITION: cut-deprecated-builtin-pack-alias
// SOURCE-KIND: const
// BASELINE: json
// SOURCE-LINE: 10233
// DECLARATION-SHA256: b605423de6546ca40419b2b8a6ee48c1fe386b5c263ca6f8cb3a5d644b1e775f
// DECLARATION-TEXT-LENGTH: 40
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: deprecated d.ts-only alias of a cut builtin language pack

// PATH: languages.typescript
// ORDINAL: 197
// DISPOSITION: cut-deprecated-builtin-pack-alias
// SOURCE-KIND: const
// BASELINE: typescript
// SOURCE-LINE: 10236
// DECLARATION-SHA256: f0a6199410a43ef09631decb561bfd0629cf04e03bdd5e48f366ec4a4a89bca7
// DECLARATION-TEXT-LENGTH: 46
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: deprecated d.ts-only alias of a cut builtin language pack

// PATH: worker.IMirrorTextModel
// ORDINAL: 0
// DISPOSITION: cut-webworker-namespace
// SOURCE-KIND: interface
// BASELINE: IMirrorTextModel
// SOURCE-LINE: 9039
// DECLARATION-SHA256: 907a96e9ebd09bee3fb2113747f7f0b81cd8481bc23879c126e878ba168bdd4d
// DECLARATION-TEXT-LENGTH: 66
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: WebWorker namespace is absent from the runtime scope and cut wholesale

// PATH: worker.IMirrorModel
// ORDINAL: 1
// DISPOSITION: cut-webworker-namespace
// SOURCE-KIND: interface
// BASELINE: IMirrorModel
// SOURCE-LINE: 9043
// DECLARATION-SHA256: 42d4eaba1f7c22493a32244e7f4d3c9fe7f413c63faf46a2514e7e9535fba182
// DECLARATION-TEXT-LENGTH: 130
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: WebWorker namespace is absent from the runtime scope and cut wholesale

// PATH: worker.IWorkerContext
// ORDINAL: 2
// DISPOSITION: cut-webworker-namespace
// SOURCE-KIND: interface
// BASELINE: IWorkerContext
// SOURCE-LINE: 9049
// DECLARATION-SHA256: c37adffb9fff86591bec6a57ab81bc2cc707f0124b10cf94a33209f908c52bd1
// DECLARATION-TEXT-LENGTH: 214
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: WebWorker namespace is absent from the runtime scope and cut wholesale

// PATH: lsp.MonacoLspClient
// ORDINAL: 0
// DISPOSITION: retained-and-extended-native-lsp-client
// SOURCE-KIND: value-export
// RESOLVED-KIND: class
// BASELINE: MonacoLspClient
// BASELINE-LOCAL: index_d_MonacoLspClient
// SOURCE-LINE: 270
// DECLARATION-SHA256: e21158998f52e913bfbe923614bc4134e593a10c134b9371128839dab02d2667
// DECLARATION-TEXT-LENGTH: 243
// RESOLVED-ALIAS-GRAPH-SHA256: b6c18cbc11dc030a24d3ea24f87d7edee9d0badf1f60bfd739cf4d39bc1932a3
// RESOLVED-ALIAS-PARTS: type:index_d_MonacoLspClient@263, const:index_d_MonacoLspClient@264, class:MonacoLspClient@205
//   - LSP client extension: MonaMessageTransport boundary
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - reference identity: @MainActor final reference type; non-Sendable
public final class MonaLspMonacoLspClient {}

// PATH: css.cssDefaults
// ORDINAL: 0
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: value-export
// BASELINE: cssDefaults
// BASELINE-LOCAL: register$3_cssDefaults
// SOURCE-LINE: 9263
// DECLARATION-SHA256: 848fba4523242c78ac5bf87217d7a1ba605cf5573b0e0cd3ee04262d81dcff40
// DECLARATION-TEXT-LENGTH: 131
// RESOLVED-ALIAS-GRAPH-SHA256: 2ac30c3eacab8c524cb491eddf8a443328a9d78aaba12ec1cccbb1b9c5d975ef
// RESOLVED-ALIAS-PARTS: const:register$3_cssDefaults@9259, const:cssDefaults@9175, interface:LanguageServiceDefaults$3@9161
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: css.lessDefaults
// ORDINAL: 1
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: value-export
// BASELINE: lessDefaults
// BASELINE-LOCAL: register$3_lessDefaults
// SOURCE-LINE: 9263
// DECLARATION-SHA256: 848fba4523242c78ac5bf87217d7a1ba605cf5573b0e0cd3ee04262d81dcff40
// DECLARATION-TEXT-LENGTH: 131
// RESOLVED-ALIAS-GRAPH-SHA256: d840d33813d2c7f8ce05335ddc2c92c0bda19b1128a33685cead5557c9f75452
// RESOLVED-ALIAS-PARTS: const:register$3_lessDefaults@9260, const:lessDefaults@9177, interface:LanguageServiceDefaults$3@9161
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: css.scssDefaults
// ORDINAL: 2
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: value-export
// BASELINE: scssDefaults
// BASELINE-LOCAL: register$3_scssDefaults
// SOURCE-LINE: 9263
// DECLARATION-SHA256: 848fba4523242c78ac5bf87217d7a1ba605cf5573b0e0cd3ee04262d81dcff40
// DECLARATION-TEXT-LENGTH: 131
// RESOLVED-ALIAS-GRAPH-SHA256: 210a37cf0357a5c03f75778c9d9baa2310cf28d37424d7a07f3d22734c3be382
// RESOLVED-ALIAS-PARTS: const:register$3_scssDefaults@9261, const:scssDefaults@9176, interface:LanguageServiceDefaults$3@9161
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: css.CSSDataConfiguration
// ORDINAL: 3
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: CSSDataConfiguration
// BASELINE-LOCAL: register$3_CSSDataConfiguration
// SOURCE-LINE: 9264
// DECLARATION-SHA256: 438c76d8e48bad6f616d5cb17b3144e6c171b84f8c9f0ed2696b2071ee6583b9
// DECLARATION-TEXT-LENGTH: 681
// RESOLVED-ALIAS-GRAPH-SHA256: 5d6e31fcb1493d21e5a2afc3dcea35d3886276f66384e7f944380049259c9863
// RESOLVED-ALIAS-PARTS: type:register$3_CSSDataConfiguration@9251, interface:CSSDataConfiguration@9178
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: css.CSSDataV1
// ORDINAL: 4
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: CSSDataV1
// BASELINE-LOCAL: register$3_CSSDataV1
// SOURCE-LINE: 9264
// DECLARATION-SHA256: 438c76d8e48bad6f616d5cb17b3144e6c171b84f8c9f0ed2696b2071ee6583b9
// DECLARATION-TEXT-LENGTH: 681
// RESOLVED-ALIAS-GRAPH-SHA256: b28b143442c43976088e0a54277f7faed553de74f3a0eb3f8896522559007131
// RESOLVED-ALIAS-PARTS: type:register$3_CSSDataV1@9252, interface:CSSDataV1@9194
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: css.CSSFormatConfiguration
// ORDINAL: 5
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: CSSFormatConfiguration
// BASELINE-LOCAL: register$3_CSSFormatConfiguration
// SOURCE-LINE: 9264
// DECLARATION-SHA256: 438c76d8e48bad6f616d5cb17b3144e6c171b84f8c9f0ed2696b2071ee6583b9
// DECLARATION-TEXT-LENGTH: 681
// RESOLVED-ALIAS-GRAPH-SHA256: f7b66100fac4c67089d9a7cc2a9dd03c75f6f4a6149fcd23a08cb914212f9ac6
// RESOLVED-ALIAS-PARTS: type:register$3_CSSFormatConfiguration@9253, interface:CSSFormatConfiguration@9062
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: css.DiagnosticsOptions
// ORDINAL: 6
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: DiagnosticsOptions
// BASELINE-LOCAL: DiagnosticsOptions$2
// SOURCE-LINE: 9264
// DECLARATION-SHA256: 438c76d8e48bad6f616d5cb17b3144e6c171b84f8c9f0ed2696b2071ee6583b9
// DECLARATION-TEXT-LENGTH: 681
// RESOLVED-ALIAS-GRAPH-SHA256: ef2cfa02d848dfc61d21e196f2f21a7f9a2fdbdbc20c0846c1670b42bddc23da
// RESOLVED-ALIAS-PARTS: type:DiagnosticsOptions$2@9174, interface:Options$1@9076
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: css.EntryStatus
// ORDINAL: 7
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: EntryStatus
// BASELINE-LOCAL: register$3_EntryStatus
// SOURCE-LINE: 9264
// DECLARATION-SHA256: 438c76d8e48bad6f616d5cb17b3144e6c171b84f8c9f0ed2696b2071ee6583b9
// DECLARATION-TEXT-LENGTH: 681
// RESOLVED-ALIAS-GRAPH-SHA256: 123b78407bb063346601f721160fcca7b606d6095e9ce40d47579c8067fff4ec
// RESOLVED-ALIAS-PARTS: type:register$3_EntryStatus@9254, type:EntryStatus@9201
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: css.IAtDirectiveData
// ORDINAL: 8
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: IAtDirectiveData
// BASELINE-LOCAL: register$3_IAtDirectiveData
// SOURCE-LINE: 9264
// DECLARATION-SHA256: 438c76d8e48bad6f616d5cb17b3144e6c171b84f8c9f0ed2696b2071ee6583b9
// DECLARATION-TEXT-LENGTH: 681
// RESOLVED-ALIAS-GRAPH-SHA256: 2b82bb8efda28f2fe7fcac135f9eb2b68903e30495f13406eeb39c62fb5b7aa2
// RESOLVED-ALIAS-PARTS: type:register$3_IAtDirectiveData@9255, interface:IAtDirectiveData@9217
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: css.IPropertyData
// ORDINAL: 9
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: IPropertyData
// BASELINE-LOCAL: register$3_IPropertyData
// SOURCE-LINE: 9264
// DECLARATION-SHA256: 438c76d8e48bad6f616d5cb17b3144e6c171b84f8c9f0ed2696b2071ee6583b9
// DECLARATION-TEXT-LENGTH: 681
// RESOLVED-ALIAS-GRAPH-SHA256: 8b82e4b0d069575fd435f7022ff14e7ee44b3235b91c9761f8a62b256158bcf8
// RESOLVED-ALIAS-PARTS: type:register$3_IPropertyData@9256, interface:IPropertyData@9206
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: css.IPseudoClassData
// ORDINAL: 10
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: IPseudoClassData
// BASELINE-LOCAL: register$3_IPseudoClassData
// SOURCE-LINE: 9264
// DECLARATION-SHA256: 438c76d8e48bad6f616d5cb17b3144e6c171b84f8c9f0ed2696b2071ee6583b9
// DECLARATION-TEXT-LENGTH: 681
// RESOLVED-ALIAS-GRAPH-SHA256: d20ef0f3487361b55eda205101944e1aaf678daf214de4ab318985f58b673aea
// RESOLVED-ALIAS-PARTS: type:register$3_IPseudoClassData@9257, interface:IPseudoClassData@9224
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: css.IPseudoElementData
// ORDINAL: 11
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: IPseudoElementData
// BASELINE-LOCAL: register$3_IPseudoElementData
// SOURCE-LINE: 9264
// DECLARATION-SHA256: 438c76d8e48bad6f616d5cb17b3144e6c171b84f8c9f0ed2696b2071ee6583b9
// DECLARATION-TEXT-LENGTH: 681
// RESOLVED-ALIAS-GRAPH-SHA256: c1224fb9e490528fcaf08438ed93f166f1da99bd1de165f0ce617055e9f14e87
// RESOLVED-ALIAS-PARTS: type:register$3_IPseudoElementData@9258, interface:IPseudoElementData@9231
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: css.IReference
// ORDINAL: 12
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: IReference
// BASELINE-LOCAL: IReference$1
// SOURCE-LINE: 9264
// DECLARATION-SHA256: 438c76d8e48bad6f616d5cb17b3144e6c171b84f8c9f0ed2696b2071ee6583b9
// DECLARATION-TEXT-LENGTH: 681
// RESOLVED-ALIAS-GRAPH-SHA256: f62fb4240b853655a9a92bf1b8f4930f1d19aaf725b95042b8ed6b9205fc16c1
// RESOLVED-ALIAS-PARTS: interface:IReference$1@9202
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: css.IValueData
// ORDINAL: 13
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: IValueData
// BASELINE-LOCAL: IValueData$1
// SOURCE-LINE: 9264
// DECLARATION-SHA256: 438c76d8e48bad6f616d5cb17b3144e6c171b84f8c9f0ed2696b2071ee6583b9
// DECLARATION-TEXT-LENGTH: 681
// RESOLVED-ALIAS-GRAPH-SHA256: 2525ab34c5abe60bf3311ee28fe5621ea8dee588aa4935fee22ebebfa764ab7a
// RESOLVED-ALIAS-PARTS: interface:IValueData$1@9238
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: css.LanguageServiceDefaults
// ORDINAL: 14
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: LanguageServiceDefaults
// BASELINE-LOCAL: LanguageServiceDefaults$3
// SOURCE-LINE: 9264
// DECLARATION-SHA256: 438c76d8e48bad6f616d5cb17b3144e6c171b84f8c9f0ed2696b2071ee6583b9
// DECLARATION-TEXT-LENGTH: 681
// RESOLVED-ALIAS-GRAPH-SHA256: 8f4554b6ed724e887568e3f17254773e973bc16d71649872f0aa74b7bf151b66
// RESOLVED-ALIAS-PARTS: interface:LanguageServiceDefaults$3@9161
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: css.MarkupContent
// ORDINAL: 15
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: MarkupContent
// BASELINE-LOCAL: MarkupContent$1
// SOURCE-LINE: 9264
// DECLARATION-SHA256: 438c76d8e48bad6f616d5cb17b3144e6c171b84f8c9f0ed2696b2071ee6583b9
// DECLARATION-TEXT-LENGTH: 681
// RESOLVED-ALIAS-GRAPH-SHA256: 9fabd07735e294c52fc30eba826392d8999a19a8905090cc36de61e1b13a9539
// RESOLVED-ALIAS-PARTS: interface:MarkupContent$1@9245
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: css.MarkupKind
// ORDINAL: 16
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: MarkupKind
// BASELINE-LOCAL: MarkupKind$1
// SOURCE-LINE: 9264
// DECLARATION-SHA256: 438c76d8e48bad6f616d5cb17b3144e6c171b84f8c9f0ed2696b2071ee6583b9
// DECLARATION-TEXT-LENGTH: 681
// RESOLVED-ALIAS-GRAPH-SHA256: cc6565f20416c223334d38a8526805cc658e5011d8a19a8f2730357189bdce73
// RESOLVED-ALIAS-PARTS: type:MarkupKind$1@9249
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: css.ModeConfiguration
// ORDINAL: 17
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: ModeConfiguration
// BASELINE-LOCAL: ModeConfiguration$3
// SOURCE-LINE: 9264
// DECLARATION-SHA256: 438c76d8e48bad6f616d5cb17b3144e6c171b84f8c9f0ed2696b2071ee6583b9
// DECLARATION-TEXT-LENGTH: 681
// RESOLVED-ALIAS-GRAPH-SHA256: 9cc76d56df42bcf8da1372884255ce9c2f07be6dca1bbc869d1d43378c202fb3
// RESOLVED-ALIAS-PARTS: interface:ModeConfiguration$3@9107
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: css.Options
// ORDINAL: 18
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: Options
// BASELINE-LOCAL: Options$1
// SOURCE-LINE: 9264
// DECLARATION-SHA256: 438c76d8e48bad6f616d5cb17b3144e6c171b84f8c9f0ed2696b2071ee6583b9
// DECLARATION-TEXT-LENGTH: 681
// RESOLVED-ALIAS-GRAPH-SHA256: b70168c7a7be5ff7a17603c76646db09481c2b188bf48fd63635f84380757a7e
// RESOLVED-ALIAS-PARTS: interface:Options$1@9076
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: html.handlebarDefaults
// ORDINAL: 0
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: value-export
// BASELINE: handlebarDefaults
// BASELINE-LOCAL: register$2_handlebarDefaults
// SOURCE-LINE: 9448
// DECLARATION-SHA256: 9082317576c03a8dbfeccc05bdd6ca50f7a53fd63b8e262c9831d5d0689c73bd
// DECLARATION-TEXT-LENGTH: 393
// RESOLVED-ALIAS-GRAPH-SHA256: eef7f2522401ad6a6c98ce9ba432e9578aafb610e4af3b8870c5c313019856aa
// RESOLVED-ALIAS-PARTS: const:register$2_handlebarDefaults@9440, const:handlebarDefaults@9359, interface:LanguageServiceDefaults$2@9348
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: html.handlebarLanguageService
// ORDINAL: 1
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: value-export
// BASELINE: handlebarLanguageService
// BASELINE-LOCAL: register$2_handlebarLanguageService
// SOURCE-LINE: 9448
// DECLARATION-SHA256: 9082317576c03a8dbfeccc05bdd6ca50f7a53fd63b8e262c9831d5d0689c73bd
// DECLARATION-TEXT-LENGTH: 393
// RESOLVED-ALIAS-GRAPH-SHA256: 977e92a536556d0abacca86594d928edb6ea92edb308431ebd49016228b2614d
// RESOLVED-ALIAS-PARTS: const:register$2_handlebarLanguageService@9441, const:handlebarLanguageService@9358, interface:LanguageServiceRegistration@9362
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: html.htmlDefaults
// ORDINAL: 2
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: value-export
// BASELINE: htmlDefaults
// BASELINE-LOCAL: register$2_htmlDefaults
// SOURCE-LINE: 9448
// DECLARATION-SHA256: 9082317576c03a8dbfeccc05bdd6ca50f7a53fd63b8e262c9831d5d0689c73bd
// DECLARATION-TEXT-LENGTH: 393
// RESOLVED-ALIAS-GRAPH-SHA256: fdec0b0728ff3f7d8c52481f87b36b1f43cf3123e22b671a3defba9326303196
// RESOLVED-ALIAS-PARTS: const:register$2_htmlDefaults@9442, const:htmlDefaults@9357, interface:LanguageServiceDefaults$2@9348
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: html.htmlLanguageService
// ORDINAL: 3
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: value-export
// BASELINE: htmlLanguageService
// BASELINE-LOCAL: register$2_htmlLanguageService
// SOURCE-LINE: 9448
// DECLARATION-SHA256: 9082317576c03a8dbfeccc05bdd6ca50f7a53fd63b8e262c9831d5d0689c73bd
// DECLARATION-TEXT-LENGTH: 393
// RESOLVED-ALIAS-GRAPH-SHA256: 037fc9f53ec005cbef6abdbecfd68a54c3cd08c526bf66457d79b7327740f589
// RESOLVED-ALIAS-PARTS: const:register$2_htmlLanguageService@9443, const:htmlLanguageService@9356, interface:LanguageServiceRegistration@9362
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: html.razorDefaults
// ORDINAL: 4
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: value-export
// BASELINE: razorDefaults
// BASELINE-LOCAL: register$2_razorDefaults
// SOURCE-LINE: 9448
// DECLARATION-SHA256: 9082317576c03a8dbfeccc05bdd6ca50f7a53fd63b8e262c9831d5d0689c73bd
// DECLARATION-TEXT-LENGTH: 393
// RESOLVED-ALIAS-GRAPH-SHA256: 542252f0feebf30bead4857324ec990d097409e5ab14d92cd71759fac5893419
// RESOLVED-ALIAS-PARTS: const:register$2_razorDefaults@9444, const:razorDefaults@9361, interface:LanguageServiceDefaults$2@9348
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: html.razorLanguageService
// ORDINAL: 5
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: value-export
// BASELINE: razorLanguageService
// BASELINE-LOCAL: register$2_razorLanguageService
// SOURCE-LINE: 9448
// DECLARATION-SHA256: 9082317576c03a8dbfeccc05bdd6ca50f7a53fd63b8e262c9831d5d0689c73bd
// DECLARATION-TEXT-LENGTH: 393
// RESOLVED-ALIAS-GRAPH-SHA256: 2ee6f81252e3179b52156d2ec2bef37f4af40253258920629846230ae07e4518
// RESOLVED-ALIAS-PARTS: const:register$2_razorLanguageService@9445, const:razorLanguageService@9360, interface:LanguageServiceRegistration@9362
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: html.registerHTMLLanguageService
// ORDINAL: 6
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: value-export
// BASELINE: registerHTMLLanguageService
// BASELINE-LOCAL: register$2_registerHTMLLanguageService
// SOURCE-LINE: 9448
// DECLARATION-SHA256: 9082317576c03a8dbfeccc05bdd6ca50f7a53fd63b8e262c9831d5d0689c73bd
// DECLARATION-TEXT-LENGTH: 393
// RESOLVED-ALIAS-GRAPH-SHA256: efb9bbcc9c0cc1cc13c538233e33297a1c1c1f695b763474868f7f89ee953a0e
// RESOLVED-ALIAS-PARTS: const:register$2_registerHTMLLanguageService@9446, function:registerHTMLLanguageService@9372
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: html.CompletionConfiguration
// ORDINAL: 7
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: CompletionConfiguration
// BASELINE-LOCAL: register$2_CompletionConfiguration
// SOURCE-LINE: 9449
// DECLARATION-SHA256: 13c4153185e700d2488bd2cfa8436443f5cd9626370a0859e096c3d7c5ac66f6
// DECLARATION-TEXT-LENGTH: 702
// RESOLVED-ALIAS-GRAPH-SHA256: af3a6367ac4619ff42dbbb28360913e3555cac500896227300fb140916c9326d
// RESOLVED-ALIAS-PARTS: type:register$2_CompletionConfiguration@9427, interface:CompletionConfiguration@9281
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: html.HTMLDataConfiguration
// ORDINAL: 8
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: HTMLDataConfiguration
// BASELINE-LOCAL: register$2_HTMLDataConfiguration
// SOURCE-LINE: 9449
// DECLARATION-SHA256: 13c4153185e700d2488bd2cfa8436443f5cd9626370a0859e096c3d7c5ac66f6
// DECLARATION-TEXT-LENGTH: 702
// RESOLVED-ALIAS-GRAPH-SHA256: a993c6134781c1c3522a3ee551daf0e2a5a34529bf0e5962426eb7135e4203e3
// RESOLVED-ALIAS-PARTS: type:register$2_HTMLDataConfiguration@9428, interface:HTMLDataConfiguration@9373
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: html.HTMLDataV1
// ORDINAL: 9
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: HTMLDataV1
// BASELINE-LOCAL: register$2_HTMLDataV1
// SOURCE-LINE: 9449
// DECLARATION-SHA256: 13c4153185e700d2488bd2cfa8436443f5cd9626370a0859e096c3d7c5ac66f6
// DECLARATION-TEXT-LENGTH: 702
// RESOLVED-ALIAS-GRAPH-SHA256: e9ca6b51c4cfaa3c8716b764d2dc277558e334d97824df1cac92a304000bba73
// RESOLVED-ALIAS-PARTS: type:register$2_HTMLDataV1@9429, interface:HTMLDataV1@9389
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: html.HTMLFormatConfiguration
// ORDINAL: 10
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: HTMLFormatConfiguration
// BASELINE-LOCAL: register$2_HTMLFormatConfiguration
// SOURCE-LINE: 9449
// DECLARATION-SHA256: 13c4153185e700d2488bd2cfa8436443f5cd9626370a0859e096c3d7c5ac66f6
// DECLARATION-TEXT-LENGTH: 702
// RESOLVED-ALIAS-GRAPH-SHA256: 5892f26fd398f085af2302d0fdb831f341d29d3095a4951b2873c7b87cd2c297
// RESOLVED-ALIAS-PARTS: type:register$2_HTMLFormatConfiguration@9430, interface:HTMLFormatConfiguration@9267
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: html.IAttributeData
// ORDINAL: 11
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: IAttributeData
// BASELINE-LOCAL: register$2_IAttributeData
// SOURCE-LINE: 9449
// DECLARATION-SHA256: 13c4153185e700d2488bd2cfa8436443f5cd9626370a0859e096c3d7c5ac66f6
// DECLARATION-TEXT-LENGTH: 702
// RESOLVED-ALIAS-GRAPH-SHA256: fde127cc1121fd3f37a540e3e1e83448cab4c68ffe52e45b1615fa49324fe1cd
// RESOLVED-ALIAS-PARTS: type:register$2_IAttributeData@9431, interface:IAttributeData@9405
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: html.IReference
// ORDINAL: 12
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: IReference
// BASELINE-LOCAL: register$2_IReference
// SOURCE-LINE: 9449
// DECLARATION-SHA256: 13c4153185e700d2488bd2cfa8436443f5cd9626370a0859e096c3d7c5ac66f6
// DECLARATION-TEXT-LENGTH: 702
// RESOLVED-ALIAS-GRAPH-SHA256: a29952b2c61b5dcc8a5787a849d3c81dd09d1a31eea55ad8de4f00cfdd02f34d
// RESOLVED-ALIAS-PARTS: type:register$2_IReference@9432, interface:IReference@9395
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: html.ITagData
// ORDINAL: 13
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: ITagData
// BASELINE-LOCAL: register$2_ITagData
// SOURCE-LINE: 9449
// DECLARATION-SHA256: 13c4153185e700d2488bd2cfa8436443f5cd9626370a0859e096c3d7c5ac66f6
// DECLARATION-TEXT-LENGTH: 702
// RESOLVED-ALIAS-GRAPH-SHA256: 6de118c9019059b173cbc112a2535114ceff22bfb56decf9a570cdcb0e43e69e
// RESOLVED-ALIAS-PARTS: type:register$2_ITagData@9433, interface:ITagData@9399
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: html.IValueData
// ORDINAL: 14
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: IValueData
// BASELINE-LOCAL: register$2_IValueData
// SOURCE-LINE: 9449
// DECLARATION-SHA256: 13c4153185e700d2488bd2cfa8436443f5cd9626370a0859e096c3d7c5ac66f6
// DECLARATION-TEXT-LENGTH: 702
// RESOLVED-ALIAS-GRAPH-SHA256: 92f48f7e04972a996cb673bb79cff573ce8e543896367f102505fa81c7308b42
// RESOLVED-ALIAS-PARTS: type:register$2_IValueData@9434, interface:IValueData@9412
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: html.IValueSet
// ORDINAL: 15
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: IValueSet
// BASELINE-LOCAL: register$2_IValueSet
// SOURCE-LINE: 9449
// DECLARATION-SHA256: 13c4153185e700d2488bd2cfa8436443f5cd9626370a0859e096c3d7c5ac66f6
// DECLARATION-TEXT-LENGTH: 702
// RESOLVED-ALIAS-GRAPH-SHA256: 1d226395f171057e436ee4caf8695a03d20a736479f87d2f365a25be69e320f3
// RESOLVED-ALIAS-PARTS: type:register$2_IValueSet@9435, interface:IValueSet@9417
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: html.LanguageServiceDefaults
// ORDINAL: 16
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: LanguageServiceDefaults
// BASELINE-LOCAL: LanguageServiceDefaults$2
// SOURCE-LINE: 9449
// DECLARATION-SHA256: 13c4153185e700d2488bd2cfa8436443f5cd9626370a0859e096c3d7c5ac66f6
// DECLARATION-TEXT-LENGTH: 702
// RESOLVED-ALIAS-GRAPH-SHA256: 78cf971f37da7027c5c7be59abc9752fe4cad6dcf5914796d0353dabe313c204
// RESOLVED-ALIAS-PARTS: interface:LanguageServiceDefaults$2@9348
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: html.LanguageServiceRegistration
// ORDINAL: 17
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: LanguageServiceRegistration
// BASELINE-LOCAL: register$2_LanguageServiceRegistration
// SOURCE-LINE: 9449
// DECLARATION-SHA256: 13c4153185e700d2488bd2cfa8436443f5cd9626370a0859e096c3d7c5ac66f6
// DECLARATION-TEXT-LENGTH: 702
// RESOLVED-ALIAS-GRAPH-SHA256: 3fc47d7197a7b8d4dff2c9bcc958c7be9d5cd8745e26af15dc22f4aca209c7f1
// RESOLVED-ALIAS-PARTS: type:register$2_LanguageServiceRegistration@9436, interface:LanguageServiceRegistration@9362
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: html.MarkupContent
// ORDINAL: 18
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: MarkupContent
// BASELINE-LOCAL: register$2_MarkupContent
// SOURCE-LINE: 9449
// DECLARATION-SHA256: 13c4153185e700d2488bd2cfa8436443f5cd9626370a0859e096c3d7c5ac66f6
// DECLARATION-TEXT-LENGTH: 702
// RESOLVED-ALIAS-GRAPH-SHA256: 6e664a37ead77862c70db16008e83bbe4bc90180efeff4a122d98839043816c5
// RESOLVED-ALIAS-PARTS: type:register$2_MarkupContent@9437, interface:MarkupContent@9421
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: html.MarkupKind
// ORDINAL: 19
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: MarkupKind
// BASELINE-LOCAL: register$2_MarkupKind
// SOURCE-LINE: 9449
// DECLARATION-SHA256: 13c4153185e700d2488bd2cfa8436443f5cd9626370a0859e096c3d7c5ac66f6
// DECLARATION-TEXT-LENGTH: 702
// RESOLVED-ALIAS-GRAPH-SHA256: 22f6725791733f5ff7b5b8a908cd2b9cb3b8665aacbbde7e08b4e50f86edfe7c
// RESOLVED-ALIAS-PARTS: type:register$2_MarkupKind@9438, type:MarkupKind@9425
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: html.ModeConfiguration
// ORDINAL: 20
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: ModeConfiguration
// BASELINE-LOCAL: ModeConfiguration$2
// SOURCE-LINE: 9449
// DECLARATION-SHA256: 13c4153185e700d2488bd2cfa8436443f5cd9626370a0859e096c3d7c5ac66f6
// DECLARATION-TEXT-LENGTH: 702
// RESOLVED-ALIAS-GRAPH-SHA256: 3e0e4f11aef016e1825973c476ddbae58fab2b343e855c3b6f41e99779558e8d
// RESOLVED-ALIAS-PARTS: interface:ModeConfiguration$2@9298
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: html.Options
// ORDINAL: 21
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: Options
// BASELINE-LOCAL: register$2_Options
// SOURCE-LINE: 9449
// DECLARATION-SHA256: 13c4153185e700d2488bd2cfa8436443f5cd9626370a0859e096c3d7c5ac66f6
// DECLARATION-TEXT-LENGTH: 702
// RESOLVED-ALIAS-GRAPH-SHA256: 7873757e4a0666a26ed312fb0755f4f52e10211b947e765c2f48c54e4af6974e
// RESOLVED-ALIAS-PARTS: type:register$2_Options@9439, interface:Options@9284
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: json.getWorker
// ORDINAL: 0
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: value-export
// BASELINE: getWorker
// BASELINE-LOCAL: register$1_getWorker
// SOURCE-LINE: 9702
// DECLARATION-SHA256: 2a0b2654d9d617573c8aae107540c24de2bbf1b44313a268ead6cf735dacc013
// DECLARATION-TEXT-LENGTH: 86
// RESOLVED-ALIAS-GRAPH-SHA256: 28dbab79b61bcf36ee0bb44db607628ff811010c6b3d2715609db56dbe817ac3
// RESOLVED-ALIAS-PARTS: const:register$1_getWorker@9699, const:getWorker@9681
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: json.jsonDefaults
// ORDINAL: 1
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: value-export
// BASELINE: jsonDefaults
// BASELINE-LOCAL: register$1_jsonDefaults
// SOURCE-LINE: 9702
// DECLARATION-SHA256: 2a0b2654d9d617573c8aae107540c24de2bbf1b44313a268ead6cf735dacc013
// DECLARATION-TEXT-LENGTH: 86
// RESOLVED-ALIAS-GRAPH-SHA256: 037afb5279ef32f9e910b53803a27a3575a1dd95c745ce7458e2a5ea93cceaec
// RESOLVED-ALIAS-PARTS: const:register$1_jsonDefaults@9700, const:jsonDefaults@9676, interface:LanguageServiceDefaults$1@9668
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: json.ASTNode
// ORDINAL: 2
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: ASTNode
// BASELINE-LOCAL: register$1_ASTNode
// SOURCE-LINE: 9703
// DECLARATION-SHA256: 0f1ae3d8b2ab098ea9f7033cd179c6d4dff13c6eac8e7d370813869ed681924c
// DECLARATION-TEXT-LENGTH: 817
// RESOLVED-ALIAS-GRAPH-SHA256: 7bf553e1ce4e9f1b7a0491bb6b2d58805172a7f42aa8fa8f01e85ef569aab889
// RESOLVED-ALIAS-PARTS: type:register$1_ASTNode@9683, type:ASTNode@9494
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: json.ArrayASTNode
// ORDINAL: 3
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: ArrayASTNode
// BASELINE-LOCAL: register$1_ArrayASTNode
// SOURCE-LINE: 9703
// DECLARATION-SHA256: 0f1ae3d8b2ab098ea9f7033cd179c6d4dff13c6eac8e7d370813869ed681924c
// DECLARATION-TEXT-LENGTH: 817
// RESOLVED-ALIAS-GRAPH-SHA256: caff0b31b59dd276b3b3a40a2dbd96328e3b94396eeae9d74689ffe2aa6e3827
// RESOLVED-ALIAS-PARTS: type:register$1_ArrayASTNode@9684, interface:ArrayASTNode@9472
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: json.BaseASTNode
// ORDINAL: 4
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: BaseASTNode
// BASELINE-LOCAL: register$1_BaseASTNode
// SOURCE-LINE: 9703
// DECLARATION-SHA256: 0f1ae3d8b2ab098ea9f7033cd179c6d4dff13c6eac8e7d370813869ed681924c
// DECLARATION-TEXT-LENGTH: 817
// RESOLVED-ALIAS-GRAPH-SHA256: dbde334beec0c43a5190795a8e2d752a7d71cb840abd9ca68bb8834f79c0a584
// RESOLVED-ALIAS-PARTS: type:register$1_BaseASTNode@9685, interface:BaseASTNode@9452
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: json.BooleanASTNode
// ORDINAL: 5
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: BooleanASTNode
// BASELINE-LOCAL: register$1_BooleanASTNode
// SOURCE-LINE: 9703
// DECLARATION-SHA256: 0f1ae3d8b2ab098ea9f7033cd179c6d4dff13c6eac8e7d370813869ed681924c
// DECLARATION-TEXT-LENGTH: 817
// RESOLVED-ALIAS-GRAPH-SHA256: e7d3f1a67e2020213700eede1dc13a5a53e4525b4c39761793cebde014a92ee4
// RESOLVED-ALIAS-PARTS: type:register$1_BooleanASTNode@9686, interface:BooleanASTNode@9486
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: json.DiagnosticsOptions
// ORDINAL: 6
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: DiagnosticsOptions
// BASELINE-LOCAL: DiagnosticsOptions$1
// SOURCE-LINE: 9703
// DECLARATION-SHA256: 0f1ae3d8b2ab098ea9f7033cd179c6d4dff13c6eac8e7d370813869ed681924c
// DECLARATION-TEXT-LENGTH: 817
// RESOLVED-ALIAS-GRAPH-SHA256: 48e8781dda7cddeb6cdb313ff997bd620370e9bcad03d2158d76813285e400c2
// RESOLVED-ALIAS-PARTS: interface:DiagnosticsOptions$1@9573
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: json.IJSONWorker
// ORDINAL: 7
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: IJSONWorker
// BASELINE-LOCAL: register$1_IJSONWorker
// SOURCE-LINE: 9703
// DECLARATION-SHA256: 0f1ae3d8b2ab098ea9f7033cd179c6d4dff13c6eac8e7d370813869ed681924c
// DECLARATION-TEXT-LENGTH: 817
// RESOLVED-ALIAS-GRAPH-SHA256: 545fe4b99b25bb8d5ee424ed6c28df5488ebf02952659eaf3f12ac4f1c5981c4
// RESOLVED-ALIAS-PARTS: type:register$1_IJSONWorker@9687, interface:IJSONWorker@9677
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: json.JSONDocument
// ORDINAL: 8
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: JSONDocument
// BASELINE-LOCAL: register$1_JSONDocument
// SOURCE-LINE: 9703
// DECLARATION-SHA256: 0f1ae3d8b2ab098ea9f7033cd179c6d4dff13c6eac8e7d370813869ed681924c
// DECLARATION-TEXT-LENGTH: 817
// RESOLVED-ALIAS-GRAPH-SHA256: ed4f2d1f8ce529292324699506c18ec633b0af935560cf2d83a1c50afbf4a1b1
// RESOLVED-ALIAS-PARTS: type:register$1_JSONDocument@9688, type:JSONDocument@9495
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: json.JSONSchema
// ORDINAL: 9
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: JSONSchema
// BASELINE-LOCAL: register$1_JSONSchema
// SOURCE-LINE: 9703
// DECLARATION-SHA256: 0f1ae3d8b2ab098ea9f7033cd179c6d4dff13c6eac8e7d370813869ed681924c
// DECLARATION-TEXT-LENGTH: 817
// RESOLVED-ALIAS-GRAPH-SHA256: 6dd03f0f64906535e65692a1d19a5bab08f43248f1a301bb0f8c2b6d5d1e74bb
// RESOLVED-ALIAS-PARTS: type:register$1_JSONSchema@9689, interface:JSONSchema@9503
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: json.JSONSchemaMap
// ORDINAL: 10
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: JSONSchemaMap
// BASELINE-LOCAL: register$1_JSONSchemaMap
// SOURCE-LINE: 9703
// DECLARATION-SHA256: 0f1ae3d8b2ab098ea9f7033cd179c6d4dff13c6eac8e7d370813869ed681924c
// DECLARATION-TEXT-LENGTH: 817
// RESOLVED-ALIAS-GRAPH-SHA256: 18885229391c5e937c955bb60cc72935bbe093a01203cee5b8193b6f56054e2d
// RESOLVED-ALIAS-PARTS: type:register$1_JSONSchemaMap@9690, interface:JSONSchemaMap@9500
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: json.JSONSchemaRef
// ORDINAL: 11
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: JSONSchemaRef
// BASELINE-LOCAL: register$1_JSONSchemaRef
// SOURCE-LINE: 9703
// DECLARATION-SHA256: 0f1ae3d8b2ab098ea9f7033cd179c6d4dff13c6eac8e7d370813869ed681924c
// DECLARATION-TEXT-LENGTH: 817
// RESOLVED-ALIAS-GRAPH-SHA256: c0152250f0fbc076a9dbae692e7f450fb97c64db160310f5b9d4823840437210
// RESOLVED-ALIAS-PARTS: type:register$1_JSONSchemaRef@9691, type:JSONSchemaRef@9499
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: json.LanguageServiceDefaults
// ORDINAL: 12
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: LanguageServiceDefaults
// BASELINE-LOCAL: LanguageServiceDefaults$1
// SOURCE-LINE: 9703
// DECLARATION-SHA256: 0f1ae3d8b2ab098ea9f7033cd179c6d4dff13c6eac8e7d370813869ed681924c
// DECLARATION-TEXT-LENGTH: 817
// RESOLVED-ALIAS-GRAPH-SHA256: 4340dc948cdfaf534a19952cc606a9f60bac60f8074416fd6298e8102c38c144
// RESOLVED-ALIAS-PARTS: interface:LanguageServiceDefaults$1@9668
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: json.MatchingSchema
// ORDINAL: 13
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: MatchingSchema
// BASELINE-LOCAL: register$1_MatchingSchema
// SOURCE-LINE: 9703
// DECLARATION-SHA256: 0f1ae3d8b2ab098ea9f7033cd179c6d4dff13c6eac8e7d370813869ed681924c
// DECLARATION-TEXT-LENGTH: 817
// RESOLVED-ALIAS-GRAPH-SHA256: fde0fc2a90b77bb140b29e44b7be5e3981c44f85a5ca5f63d115ab44798cce22
// RESOLVED-ALIAS-PARTS: type:register$1_MatchingSchema@9692, interface:MatchingSchema@9569
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: json.ModeConfiguration
// ORDINAL: 14
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: ModeConfiguration
// BASELINE-LOCAL: ModeConfiguration$1
// SOURCE-LINE: 9703
// DECLARATION-SHA256: 0f1ae3d8b2ab098ea9f7033cd179c6d4dff13c6eac8e7d370813869ed681924c
// DECLARATION-TEXT-LENGTH: 817
// RESOLVED-ALIAS-GRAPH-SHA256: c387730a0a9cf06d1f6f9f5b67a56510207523f4101a64f28cb8e8d347319a82
// RESOLVED-ALIAS-PARTS: interface:ModeConfiguration$1@9626
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: json.NullASTNode
// ORDINAL: 15
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: NullASTNode
// BASELINE-LOCAL: register$1_NullASTNode
// SOURCE-LINE: 9703
// DECLARATION-SHA256: 0f1ae3d8b2ab098ea9f7033cd179c6d4dff13c6eac8e7d370813869ed681924c
// DECLARATION-TEXT-LENGTH: 817
// RESOLVED-ALIAS-GRAPH-SHA256: f166dd362ad0b2bd3ce4b31061211815a5027cfbf68a5a32c6e06516076cdeb9
// RESOLVED-ALIAS-PARTS: type:register$1_NullASTNode@9693, interface:NullASTNode@9490
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: json.NumberASTNode
// ORDINAL: 16
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: NumberASTNode
// BASELINE-LOCAL: register$1_NumberASTNode
// SOURCE-LINE: 9703
// DECLARATION-SHA256: 0f1ae3d8b2ab098ea9f7033cd179c6d4dff13c6eac8e7d370813869ed681924c
// DECLARATION-TEXT-LENGTH: 817
// RESOLVED-ALIAS-GRAPH-SHA256: 9c694a057f1739076a98a9fd602a20b496dd5d49fd2f06e65eea6a2bc3953078
// RESOLVED-ALIAS-PARTS: type:register$1_NumberASTNode@9694, interface:NumberASTNode@9481
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: json.ObjectASTNode
// ORDINAL: 17
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: ObjectASTNode
// BASELINE-LOCAL: register$1_ObjectASTNode
// SOURCE-LINE: 9703
// DECLARATION-SHA256: 0f1ae3d8b2ab098ea9f7033cd179c6d4dff13c6eac8e7d370813869ed681924c
// DECLARATION-TEXT-LENGTH: 817
// RESOLVED-ALIAS-GRAPH-SHA256: 9e190a55d530068e6505b4a42fa7d29e60b6a94723165e9085364021af304c4a
// RESOLVED-ALIAS-PARTS: type:register$1_ObjectASTNode@9695, interface:ObjectASTNode@9460
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: json.PropertyASTNode
// ORDINAL: 18
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: PropertyASTNode
// BASELINE-LOCAL: register$1_PropertyASTNode
// SOURCE-LINE: 9703
// DECLARATION-SHA256: 0f1ae3d8b2ab098ea9f7033cd179c6d4dff13c6eac8e7d370813869ed681924c
// DECLARATION-TEXT-LENGTH: 817
// RESOLVED-ALIAS-GRAPH-SHA256: 8550d03993b67928f8b4f7f5256c31f014a3886d9d261d89ea33dfb7aef2c50a
// RESOLVED-ALIAS-PARTS: type:register$1_PropertyASTNode@9696, interface:PropertyASTNode@9465
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: json.SeverityLevel
// ORDINAL: 19
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: SeverityLevel
// BASELINE-LOCAL: register$1_SeverityLevel
// SOURCE-LINE: 9703
// DECLARATION-SHA256: 0f1ae3d8b2ab098ea9f7033cd179c6d4dff13c6eac8e7d370813869ed681924c
// DECLARATION-TEXT-LENGTH: 817
// RESOLVED-ALIAS-GRAPH-SHA256: 8282b5738d5f4e968c3370293d710df5a015b7b874244e53bcc28d87353599a8
// RESOLVED-ALIAS-PARTS: type:register$1_SeverityLevel@9697, type:SeverityLevel@9625
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: json.StringASTNode
// ORDINAL: 20
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: StringASTNode
// BASELINE-LOCAL: register$1_StringASTNode
// SOURCE-LINE: 9703
// DECLARATION-SHA256: 0f1ae3d8b2ab098ea9f7033cd179c6d4dff13c6eac8e7d370813869ed681924c
// DECLARATION-TEXT-LENGTH: 817
// RESOLVED-ALIAS-GRAPH-SHA256: c7d79c2f6233e84ba85e735a12440bb1f9cd7aeda5b84485013f797643eeade4
// RESOLVED-ALIAS-PARTS: type:register$1_StringASTNode@9698, interface:StringASTNode@9477
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: typescript.JsxEmit
// ORDINAL: 0
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: value-export
// BASELINE: JsxEmit
// BASELINE-LOCAL: register_JsxEmit
// SOURCE-LINE: 10171
// DECLARATION-SHA256: 11f3129ffd4d488df145c6429880ba32280ed0879b4aee983fc25711947b415c
// DECLARATION-TEXT-LENGTH: 462
// RESOLVED-ALIAS-GRAPH-SHA256: 3f34bf57d45e2845038ce04fb0f99b9819b151db5ae0a1205d234bcd7a3a5332
// RESOLVED-ALIAS-PARTS: type:register_JsxEmit@10151, const:register_JsxEmit@10152, enum:JsxEmit@9715
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: typescript.ModuleKind
// ORDINAL: 1
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: value-export
// BASELINE: ModuleKind
// BASELINE-LOCAL: register_ModuleKind
// SOURCE-LINE: 10171
// DECLARATION-SHA256: 11f3129ffd4d488df145c6429880ba32280ed0879b4aee983fc25711947b415c
// DECLARATION-TEXT-LENGTH: 462
// RESOLVED-ALIAS-GRAPH-SHA256: 9e93110a851f42814778e4f68473e7540e891883342e10478e5a0ae88c3b9f58
// RESOLVED-ALIAS-PARTS: type:register_ModuleKind@10155, const:register_ModuleKind@10156, enum:ModuleKind@9706
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: typescript.ModuleResolutionKind
// ORDINAL: 2
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: value-export
// BASELINE: ModuleResolutionKind
// BASELINE-LOCAL: register_ModuleResolutionKind
// SOURCE-LINE: 10171
// DECLARATION-SHA256: 11f3129ffd4d488df145c6429880ba32280ed0879b4aee983fc25711947b415c
// DECLARATION-TEXT-LENGTH: 462
// RESOLVED-ALIAS-GRAPH-SHA256: a918c50ad373d08883711f7ab4d4dfb4fa787547e0dbfdea1b7b30f0e6007536
// RESOLVED-ALIAS-PARTS: type:register_ModuleResolutionKind@10157, const:register_ModuleResolutionKind@10158, enum:ModuleResolutionKind@9740
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: typescript.NewLineKind
// ORDINAL: 3
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: value-export
// BASELINE: NewLineKind
// BASELINE-LOCAL: register_NewLineKind
// SOURCE-LINE: 10171
// DECLARATION-SHA256: 11f3129ffd4d488df145c6429880ba32280ed0879b4aee983fc25711947b415c
// DECLARATION-TEXT-LENGTH: 462
// RESOLVED-ALIAS-GRAPH-SHA256: 8312c7e130d2d7a497d4a949ba23fd344de93b3c1b1cdefbd15010396a4c8989
// RESOLVED-ALIAS-PARTS: type:register_NewLineKind@10159, const:register_NewLineKind@10160, enum:NewLineKind@9723
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: typescript.ScriptTarget
// ORDINAL: 4
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: value-export
// BASELINE: ScriptTarget
// BASELINE-LOCAL: register_ScriptTarget
// SOURCE-LINE: 10171
// DECLARATION-SHA256: 11f3129ffd4d488df145c6429880ba32280ed0879b4aee983fc25711947b415c
// DECLARATION-TEXT-LENGTH: 462
// RESOLVED-ALIAS-GRAPH-SHA256: 6f0280f2590e171b5919dd65fd16e3f1f77888cc3f17dc2fc3eda52d87b1aa27
// RESOLVED-ALIAS-PARTS: type:register_ScriptTarget@10161, const:register_ScriptTarget@10162, enum:ScriptTarget@9727
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: typescript.getJavaScriptWorker
// ORDINAL: 5
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: value-export
// BASELINE: getJavaScriptWorker
// BASELINE-LOCAL: register_getJavaScriptWorker
// SOURCE-LINE: 10171
// DECLARATION-SHA256: 11f3129ffd4d488df145c6429880ba32280ed0879b4aee983fc25711947b415c
// DECLARATION-TEXT-LENGTH: 462
// RESOLVED-ALIAS-GRAPH-SHA256: 8f1fcb9f00053b9e5bc942451dd51bf525f2896f5bc2857ce8657f1c6de19472
// RESOLVED-ALIAS-PARTS: const:register_getJavaScriptWorker@10165, const:getJavaScriptWorker@10143
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: typescript.getTypeScriptWorker
// ORDINAL: 6
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: value-export
// BASELINE: getTypeScriptWorker
// BASELINE-LOCAL: register_getTypeScriptWorker
// SOURCE-LINE: 10171
// DECLARATION-SHA256: 11f3129ffd4d488df145c6429880ba32280ed0879b4aee983fc25711947b415c
// DECLARATION-TEXT-LENGTH: 462
// RESOLVED-ALIAS-GRAPH-SHA256: d01b7872e05a54b25394d91a1e47055263f9770f1da0da714c1c0d19eccc2236
// RESOLVED-ALIAS-PARTS: const:register_getTypeScriptWorker@10166, const:getTypeScriptWorker@10142
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: typescript.javascriptDefaults
// ORDINAL: 7
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: value-export
// BASELINE: javascriptDefaults
// BASELINE-LOCAL: register_javascriptDefaults
// SOURCE-LINE: 10171
// DECLARATION-SHA256: 11f3129ffd4d488df145c6429880ba32280ed0879b4aee983fc25711947b415c
// DECLARATION-TEXT-LENGTH: 462
// RESOLVED-ALIAS-GRAPH-SHA256: c1ba17a0445cba6355daaf03e5bd770ebec90d40936730c33211a57f61d561be
// RESOLVED-ALIAS-PARTS: const:register_javascriptDefaults@10167, const:javascriptDefaults@10141, interface:LanguageServiceDefaults@9956
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: typescript.typescriptDefaults
// ORDINAL: 8
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: value-export
// BASELINE: typescriptDefaults
// BASELINE-LOCAL: register_typescriptDefaults
// SOURCE-LINE: 10171
// DECLARATION-SHA256: 11f3129ffd4d488df145c6429880ba32280ed0879b4aee983fc25711947b415c
// DECLARATION-TEXT-LENGTH: 462
// RESOLVED-ALIAS-GRAPH-SHA256: 949682d4e52eb8bb7747a0197ceda8c6f552a81a5cd51dfefdbc79dce0304222
// RESOLVED-ALIAS-PARTS: const:register_typescriptDefaults@10168, const:typescriptDefaults@10140, interface:LanguageServiceDefaults@9956
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: typescript.typescriptVersion
// ORDINAL: 9
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: value-export
// BASELINE: typescriptVersion
// BASELINE-LOCAL: register_typescriptVersion
// SOURCE-LINE: 10171
// DECLARATION-SHA256: 11f3129ffd4d488df145c6429880ba32280ed0879b4aee983fc25711947b415c
// DECLARATION-TEXT-LENGTH: 462
// RESOLVED-ALIAS-GRAPH-SHA256: 68896953cbd27f1d31c60d0318d21f479a5806854c80ddd2427b82d06ff5ea66
// RESOLVED-ALIAS-PARTS: const:register_typescriptVersion@10169, const:typescriptVersion@10139
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: typescript.CompilerOptions
// ORDINAL: 10
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: CompilerOptions
// BASELINE-LOCAL: register_CompilerOptions
// SOURCE-LINE: 10172
// DECLARATION-SHA256: e1d9e4d484b9cea59dc5159da55649474e831976665956639857b2dae421311d
// DECLARATION-TEXT-LENGTH: 485
// RESOLVED-ALIAS-GRAPH-SHA256: 0b006025beb94ff8e0d012b9a443d4d896fb7b25b4536778b73d4abfef19f5c6
// RESOLVED-ALIAS-PARTS: type:register_CompilerOptions@10145, interface:CompilerOptions@9748
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: typescript.Diagnostic
// ORDINAL: 11
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: Diagnostic
// BASELINE-LOCAL: register_Diagnostic
// SOURCE-LINE: 10172
// DECLARATION-SHA256: e1d9e4d484b9cea59dc5159da55649474e831976665956639857b2dae421311d
// DECLARATION-TEXT-LENGTH: 485
// RESOLVED-ALIAS-GRAPH-SHA256: c9cd290448f521adbe06a58fa3f9ffa6cd5077bbc0bfef6fe911f80ab76192bf
// RESOLVED-ALIAS-PARTS: type:register_Diagnostic@10146, interface:Diagnostic@9873
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: typescript.DiagnosticRelatedInformation
// ORDINAL: 12
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: DiagnosticRelatedInformation
// BASELINE-LOCAL: register_DiagnosticRelatedInformation
// SOURCE-LINE: 10172
// DECLARATION-SHA256: e1d9e4d484b9cea59dc5159da55649474e831976665956639857b2dae421311d
// DECLARATION-TEXT-LENGTH: 485
// RESOLVED-ALIAS-GRAPH-SHA256: ef8fa8bb3cd8acc3d29513ff3f4ded36f10ca53c151b9ccad9c897dd78f5ae95
// RESOLVED-ALIAS-PARTS: type:register_DiagnosticRelatedInformation@10147, interface:DiagnosticRelatedInformation@9880
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: typescript.DiagnosticsOptions
// ORDINAL: 13
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: DiagnosticsOptions
// BASELINE-LOCAL: register_DiagnosticsOptions
// SOURCE-LINE: 10172
// DECLARATION-SHA256: e1d9e4d484b9cea59dc5159da55649474e831976665956639857b2dae421311d
// DECLARATION-TEXT-LENGTH: 485
// RESOLVED-ALIAS-GRAPH-SHA256: 4a06d4f208e36de21bde2c5c9c7d05595f232fb2b6f9a9ed3c1561461c15ed43
// RESOLVED-ALIAS-PARTS: type:register_DiagnosticsOptions@10148, interface:DiagnosticsOptions@9831
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: typescript.EmitOutput
// ORDINAL: 14
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: EmitOutput
// BASELINE-LOCAL: register_EmitOutput
// SOURCE-LINE: 10172
// DECLARATION-SHA256: e1d9e4d484b9cea59dc5159da55649474e831976665956639857b2dae421311d
// DECLARATION-TEXT-LENGTH: 485
// RESOLVED-ALIAS-GRAPH-SHA256: 87e7e62feaad7153de57698e6a22e66707efa3dc23c2869524e17ff58ffae924
// RESOLVED-ALIAS-PARTS: type:register_EmitOutput@10149, interface:EmitOutput@9892
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: typescript.IExtraLibs
// ORDINAL: 15
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: IExtraLibs
// BASELINE-LOCAL: register_IExtraLibs
// SOURCE-LINE: 10172
// DECLARATION-SHA256: e1d9e4d484b9cea59dc5159da55649474e831976665956639857b2dae421311d
// DECLARATION-TEXT-LENGTH: 485
// RESOLVED-ALIAS-GRAPH-SHA256: 2028270555a5564bf6ba97eb2d857ff07239d3deb36a2bd6852efabdac9333c3
// RESOLVED-ALIAS-PARTS: type:register_IExtraLibs@10150, interface:IExtraLibs@9859
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: typescript.LanguageServiceDefaults
// ORDINAL: 16
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: LanguageServiceDefaults
// BASELINE-LOCAL: register_LanguageServiceDefaults
// SOURCE-LINE: 10172
// DECLARATION-SHA256: e1d9e4d484b9cea59dc5159da55649474e831976665956639857b2dae421311d
// DECLARATION-TEXT-LENGTH: 485
// RESOLVED-ALIAS-GRAPH-SHA256: 450310dcdf794d4790ebe9c75f7ec98b4cb55ef3008fb491e66d91b5f14ca668
// RESOLVED-ALIAS-PARTS: type:register_LanguageServiceDefaults@10153, interface:LanguageServiceDefaults@9956
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: typescript.ModeConfiguration
// ORDINAL: 17
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: ModeConfiguration
// BASELINE-LOCAL: register_ModeConfiguration
// SOURCE-LINE: 10172
// DECLARATION-SHA256: e1d9e4d484b9cea59dc5159da55649474e831976665956639857b2dae421311d
// DECLARATION-TEXT-LENGTH: 485
// RESOLVED-ALIAS-GRAPH-SHA256: 3fa3bc65bd4c2a20157bd2cacd75080112ba1e7a74e4b8a97270c327ae9ea1ce
// RESOLVED-ALIAS-PARTS: type:register_ModeConfiguration@10154, interface:ModeConfiguration@9902
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: typescript.TypeScriptWorker
// ORDINAL: 18
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: TypeScriptWorker
// BASELINE-LOCAL: register_TypeScriptWorker
// SOURCE-LINE: 10172
// DECLARATION-SHA256: e1d9e4d484b9cea59dc5159da55649474e831976665956639857b2dae421311d
// DECLARATION-TEXT-LENGTH: 485
// RESOLVED-ALIAS-GRAPH-SHA256: 564976433993086600350f5d8429662e59987933a7a5250b17aa3050dbc40f21
// RESOLVED-ALIAS-PARTS: type:register_TypeScriptWorker@10163, interface:TypeScriptWorker@10034
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed

// PATH: typescript.WorkerOptions
// ORDINAL: 19
// DISPOSITION: cut-builtin-language-pack-member
// SOURCE-KIND: type-export
// BASELINE: WorkerOptions
// BASELINE-LOCAL: register_WorkerOptions
// SOURCE-LINE: 10172
// DECLARATION-SHA256: e1d9e4d484b9cea59dc5159da55649474e831976665956639857b2dae421311d
// DECLARATION-TEXT-LENGTH: 485
// RESOLVED-ALIAS-GRAPH-SHA256: 79237b252b34b6e6f1cd48cf119c654180cfb8857f5d87a6829a56fd0636c313
// RESOLVED-ALIAS-PARTS: type:register_WorkerOptions@10164, interface:WorkerOptions@9842
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: member of a cut builtin language pack namespace; the entire pack is removed
