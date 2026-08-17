// MonaAppKitPublicAPI.swift
//
// P05-T001 — Generate the exact 555-path native public declaration graph.
//
// GENERATED FILE — do not edit by hand. Regenerate with:
//
//   /opt/homebrew/Cellar/node/26.7.0/bin/node \
//       Tools/Generators/generate-contract-registries.mjs
//
// This file is the MonaCodeAppKit public declaration graph. It is the AppKit product: the retained-appkit-type-adaptation declarations (DOM HTMLElement/widget positions and editor construction options become typed AppKit NSView protocols) plus the cut-javascript-global-augmentation dispositions (DOM globals have no native Swift host).
// It records 12 retained native Swift declarations
// and 3 explicit UNAVAILABLE cut dispositions (no production
// symbol emitted for cut paths). 15 of the 555 F1-R4 paths live here.
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

import AppKit
import Foundation
// PATH: editor.create
// ORDINAL: 0
// DISPOSITION: retained-appkit-type-adaptation
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: create
// SOURCE-LINE: 1227
// DECLARATION-SHA256: 7596d0e004b4fbed25d4f0b7dfa91d7781dd82ccf734be867789661e22ff91f1
// DECLARATION-TEXT-LENGTH: 155
// WEB-TYPE-REFERENCES: HTMLElement
//   - AppKit adaptation: DOM HTMLElement/widget position -> typed NSView protocol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaEditorCreate() async throws {}

// PATH: editor.createDiffEditor
// ORDINAL: 5
// DISPOSITION: retained-appkit-type-adaptation
// SOURCE-KIND: function
// RESOLVED-KIND: function
// BASELINE: createDiffEditor
// SOURCE-LINE: 1257
// DECLARATION-SHA256: 82e7028bad31158f3bc4af5a4ae7c05a5902294e44ddc55a57b3dca7bc8594ab
// DECLARATION-TEXT-LENGTH: 169
// WEB-TYPE-REFERENCES: HTMLElement
//   - AppKit adaptation: DOM HTMLElement/widget position -> typed NSView protocol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
public func monaEditorCreateDiffEditor() async throws {}

// PATH: editor.IStandaloneEditorConstructionOptions
// ORDINAL: 45
// DISPOSITION: retained-appkit-type-adaptation
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IStandaloneEditorConstructionOptions
// SOURCE-LINE: 1634
// DECLARATION-SHA256: f70cd2183113209a952ec13fdbe293b40918d98e79728f1cae4f9de2a87e38b1
// DECLARATION-TEXT-LENGTH: 1517
// WEB-TYPE-REFERENCES: HTMLElement
//   - AppKit adaptation: DOM HTMLElement/widget position -> typed NSView protocol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIStandaloneEditorConstructionOptions {}

// PATH: editor.IEditorConstructionOptions
// ORDINAL: 186
// DISPOSITION: retained-appkit-type-adaptation
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IEditorConstructionOptions
// SOURCE-LINE: 5727
// DECLARATION-SHA256: 997a25ac499f06a4ad8e1419621c2403b31578f4698ce875098be47712eddd8f
// DECLARATION-TEXT-LENGTH: 327
// WEB-TYPE-REFERENCES: HTMLElement
//   - AppKit adaptation: DOM HTMLElement/widget position -> typed NSView protocol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIEditorConstructionOptions {}

// PATH: editor.IViewZone
// ORDINAL: 187
// DISPOSITION: retained-appkit-type-adaptation
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IViewZone
// SOURCE-LINE: 5743
// DECLARATION-SHA256: b89ec9ff406a8185eaec829510c5ef4171426e3d22c61b6d39336ba92acbc0f4
// DECLARATION-TEXT-LENGTH: 2215
// WEB-TYPE-REFERENCES: HTMLElement
//   - AppKit adaptation: DOM HTMLElement/widget position -> typed NSView protocol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIViewZone {}

// PATH: editor.IContentWidget
// ORDINAL: 191
// DISPOSITION: retained-appkit-type-adaptation
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IContentWidget
// SOURCE-LINE: 5886
// DECLARATION-SHA256: b608e22d6dcf0a9faddfc4960e8dc5b3bad78dc63d7388009a29f122a7c5d382
// DECLARATION-TEXT-LENGTH: 1303
// WEB-TYPE-REFERENCES: HTMLElement
//   - AppKit adaptation: DOM HTMLElement/widget position -> typed NSView protocol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIContentWidget {}

// PATH: editor.IOverlayWidget
// ORDINAL: 196
// DISPOSITION: retained-appkit-type-adaptation
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IOverlayWidget
// SOURCE-LINE: 5991
// DECLARATION-SHA256: 74bf5a2c3f79253ac7038bff260c438833aad6966217d0b5a7714b299eed4cd2
// DECLARATION-TEXT-LENGTH: 753
// WEB-TYPE-REFERENCES: HTMLElement
//   - AppKit adaptation: DOM HTMLElement/widget position -> typed NSView protocol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIOverlayWidget {}

// PATH: editor.IGlyphMarginWidget
// ORDINAL: 197
// DISPOSITION: retained-appkit-type-adaptation
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IGlyphMarginWidget
// SOURCE-LINE: 6022
// DECLARATION-SHA256: 390a36857ec9021280e1acc4700fb162dd3bcac5ddb53d81939124c95cc1e4c2
// DECLARATION-TEXT-LENGTH: 306
// WEB-TYPE-REFERENCES: HTMLElement
//   - AppKit adaptation: DOM HTMLElement/widget position -> typed NSView protocol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIGlyphMarginWidget {}

// PATH: editor.IBaseMouseTarget
// ORDINAL: 200
// DISPOSITION: retained-appkit-type-adaptation
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IBaseMouseTarget
// SOURCE-LINE: 6118
// DECLARATION-SHA256: ce696cf1256d62144ca46f6228975d84b685cf41b6469d6eedb29e459f811501
// DECLARATION-TEXT-LENGTH: 443
// WEB-TYPE-REFERENCES: HTMLElement
//   - AppKit adaptation: DOM HTMLElement/widget position -> typed NSView protocol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIBaseMouseTarget {}

// PATH: editor.IDiffEditorConstructionOptions
// ORDINAL: 220
// DISPOSITION: retained-appkit-type-adaptation
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IDiffEditorConstructionOptions
// SOURCE-LINE: 6258
// DECLARATION-SHA256: eaf39c2128dab8132bfcfb59389b61114763cb1dbb79ca6eaf7e48f30f5f98af
// DECLARATION-TEXT-LENGTH: 413
// WEB-TYPE-REFERENCES: HTMLElement
//   - AppKit adaptation: DOM HTMLElement/widget position -> typed NSView protocol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIDiffEditorConstructionOptions {}

// PATH: editor.ICodeEditor
// ORDINAL: 221
// DISPOSITION: retained-appkit-type-adaptation
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: ICodeEditor
// SOURCE-LINE: 6277
// DECLARATION-SHA256: 3ec44e9de2ca428f23848ab6567b941204d1227d67fc814f3b864a96f74b7bb0
// DECLARATION-TEXT-LENGTH: 15490
// WEB-TYPE-REFERENCES: HTMLElement
//   - AppKit adaptation: DOM HTMLElement/widget position -> typed NSView protocol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorICodeEditor {}

// PATH: editor.IDiffEditor
// ORDINAL: 222
// DISPOSITION: retained-appkit-type-adaptation
// SOURCE-KIND: interface
// RESOLVED-KIND: interface
// BASELINE: IDiffEditor
// SOURCE-LINE: 6727
// DECLARATION-SHA256: 9a156606686a898a4324e8e0266d8c4082b5bf7cef3d145b092024a237c463cb
// DECLARATION-TEXT-LENGTH: 2157
// WEB-TYPE-REFERENCES: HTMLElement
//   - AppKit adaptation: DOM HTMLElement/widget position -> typed NSView protocol
//   - optionality: MonaPresence<T> / MonaNullable<T> / MonaNullish<T> per F1-R5
//   - overloads: preserved per pinned declaration SHA; no coalescing
//   - value identity: struct/protocol shape
public protocol MonaEditorIDiffEditor {}

// PATH: global.JsonRpcSerializerMapper
// ORDINAL: 0
// DISPOSITION: cut-javascript-global-augmentation
// SOURCE-KIND: interface
// BASELINE: JsonRpcSerializerMapper
// SOURCE-LINE: 196
// DECLARATION-SHA256: 6d30441290e11898b20736b072d7586494a7092b39c859f059afd37ec8c39652
// DECLARATION-TEXT-LENGTH: 39
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: JavaScript global augmentation has no native Swift host; DOM globals become typed AppKit NSView protocols

// PATH: global.MonacoEnvironment
// ORDINAL: 1
// DISPOSITION: cut-javascript-global-augmentation
// SOURCE-KIND: const
// BASELINE: MonacoEnvironment
// SOURCE-LINE: 285
// DECLARATION-SHA256: 3d1fd0b9c09a2ed3fc0dea1558f1383bf18b4da79a03550a38aa2889209242cb
// DECLARATION-TEXT-LENGTH: 47
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: JavaScript global augmentation has no native Swift host; DOM globals become typed AppKit NSView protocols

// PATH: global.monaco
// ORDINAL: 2
// DISPOSITION: cut-javascript-global-augmentation
// SOURCE-KIND: import-equals
// BASELINE: monaco
// SOURCE-LINE: 10240
// DECLARATION-SHA256: 839ddaa50ae6f30d8a26f2089546fa82c930ad727f7be775be4375e8b17fd248
// DECLARATION-TEXT-LENGTH: 35
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: JavaScript global augmentation has no native Swift host; DOM globals become typed AppKit NSView protocols
// MARK: - AppKit boundary anchor
// The retained-appkit-type-adaptation declarations map DOM HTMLElement
// and widget positions to typed AppKit NSView protocols (F1-R4 domAndEvents
// rule). This internal anchor exercises the AppKit import; it is not part
// of the 555-path public declaration graph.
@MainActor internal enum _MonaAppKitBoundary {
    internal typealias View = NSView
}
