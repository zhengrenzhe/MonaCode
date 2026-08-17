// MonaSwiftUIPublicAPI.swift
//
// P05-T001 — Generate the exact 555-path native public declaration graph.
//
// GENERATED FILE — do not edit by hand. Regenerate with:
//
//   /opt/homebrew/Cellar/node/26.7.0/bin/node \
//       Tools/Generators/generate-contract-registries.mjs
//
// This file is the MonaCodeSwiftUI public declaration graph. It is the SwiftUI product: the cut-web-transport-constructor dispositions record that WebSocket, iframe and Worker transport constructors are cut at the SwiftUI/host embedding boundary (H1-R host-injection transport ownership).
// It records 0 retained native Swift declarations
// and 3 explicit UNAVAILABLE cut dispositions (no production
// symbol emitted for cut paths). 3 of the 555 F1-R4 paths live here.
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

import SwiftUI
import Foundation
// PATH: lsp.WebSocketTransport
// ORDINAL: 1
// DISPOSITION: cut-web-transport-constructor
// SOURCE-KIND: value-export
// BASELINE: WebSocketTransport
// BASELINE-LOCAL: index_d_WebSocketTransport
// SOURCE-LINE: 270
// DECLARATION-SHA256: e21158998f52e913bfbe923614bc4134e593a10c134b9371128839dab02d2667
// DECLARATION-TEXT-LENGTH: 243
// RESOLVED-ALIAS-GRAPH-SHA256: 10f509fc667f11252172209aa7e991f3f3037121a3e0a0224221428b7b7ee8d5
// RESOLVED-ALIAS-PARTS: type:index_d_WebSocketTransport@265, const:index_d_WebSocketTransport@266, class:WebSocketTransport@228
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: WebSocket/iframe/Worker transport constructor conflicts with H1-R host-injection transport ownership

// PATH: lsp.createTransportToIFrame
// ORDINAL: 2
// DISPOSITION: cut-web-transport-constructor
// SOURCE-KIND: value-export
// BASELINE: createTransportToIFrame
// BASELINE-LOCAL: index_d_createTransportToIFrame
// SOURCE-LINE: 270
// DECLARATION-SHA256: e21158998f52e913bfbe923614bc4134e593a10c134b9371128839dab02d2667
// DECLARATION-TEXT-LENGTH: 243
// RESOLVED-ALIAS-GRAPH-SHA256: fc695d3f97a702f36c5cfc614922b1228f22bd3ed0650d6ba8e97717770b916a
// RESOLVED-ALIAS-PARTS: const:index_d_createTransportToIFrame@267, function:createTransportToIFrame@261
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: WebSocket/iframe/Worker transport constructor conflicts with H1-R host-injection transport ownership

// PATH: lsp.createTransportToWorker
// ORDINAL: 3
// DISPOSITION: cut-web-transport-constructor
// SOURCE-KIND: value-export
// BASELINE: createTransportToWorker
// BASELINE-LOCAL: index_d_createTransportToWorker
// SOURCE-LINE: 270
// DECLARATION-SHA256: e21158998f52e913bfbe923614bc4134e593a10c134b9371128839dab02d2667
// DECLARATION-TEXT-LENGTH: 243
// RESOLVED-ALIAS-GRAPH-SHA256: 11d8c98866bbc0d0ddbad2e5ee142146ffac357c4a14cce34183f23bd98d6992
// RESOLVED-ALIAS-PARTS: const:index_d_createTransportToWorker@268, function:createTransportToWorker@254
// UNAVAILABLE: this F1-R4 path is cut and emits no production Swift symbol.
//   The disposition records why the baseline identity is absent from the
//   native public declaration graph. It is not a no-op: the path is
//   intentionally removed and may not silently reappear.
// CUT-REASON: WebSocket/iframe/Worker transport constructor conflicts with H1-R host-injection transport ownership
// MARK: - SwiftUI boundary anchor
// The cut-web-transport-constructor dispositions record that WebSocket,
// iframe and Worker transports are cut at the SwiftUI/host embedding
// boundary (H1-R host-injection transport ownership). This internal anchor
// exercises the SwiftUI import; it is not part of the 55-path public
// declaration graph.
@MainActor internal enum _MonaSwiftUIBoundary {
    internal typealias HostSurface = AnyView
}
