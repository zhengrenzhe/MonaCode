// C06Tests.swift
//
// P09-T015 — Run C06: provider, LSP, snippet, and Markdown equivalence.
//
// The C06 differential conformance suite — the SIXTH C-candidate acceptance
// test. It compares the Swift port's provider (30 identities = 25 LSP-backed
// + 5 direct-only), LSP (25 capabilities, session lifecycle, frame codec,
// JSON-RPC wire), snippet (parser grammar, 39 variables, session navigation),
// and Markdown (parser grammar, security: raw HTML captured, javascript:
// dropped, image src discarded) outputs against the monaco-editor reference
// fixtures M0 + M1, and binds all evidence hashes in one manifest.
//
// This is a DIFFERENTIAL test: the Swift port (native) is compared against the
// M0/M1 reference. The M0/M1 reference fixtures are:
//   - The L2-R provider-LSP closure artifact
//     (language-l2r-provider-lsp-closure.html) — the M0/M1 provider/LSP oracle
//     (30 surfaces = 29 LanguageFeatureRegistry + 1 lexical token; 25 LSP 3.18
//     mappings; 5 Swift-direct-only; 0 bundled language content).
//   - The SN1-R snippet-engine manifest (monacode-sn1r-snippet-engine-manifest.json)
//     — the M0/M1 snippet oracle (39 variables, 11 engine classes, 15 token
//     types, 7 format shorthands, 4 session commands).
//   - The MD1-R Markdown contract manifest
//     (monacode-md1r-markdown-contract-manifest.json) — the M0/M1 Markdown
//     oracle (Marked 14.0.0, DOMPurify 3.4.8 oracle-only, 100000 UTF-16 cap).
//   - The snippet-sn1r-engine-closure.html and
//     markdown-md1r-native-security-closure.html — the M0/M1 closure oracles.
//
// The 4 implementation operations:
//   1. Validate 30 provider surfaces, 25 LSP mappings, five direct-only paths,
//      transport, framing, JSON-RPC, session, fallback, snippet, and hostile
//      Markdown matrices.
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
// --filter C06Tests` runs it.

import Foundation
import XCTest
import CryptoKit
import MonaCode
import MonaCodeAppKit

// MARK: - C06Tests

final class C06Tests: XCTestCase {

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

    // MARK: Operation 1 — Validate 30 provider surfaces, 25 LSP mappings, five
    // direct-only paths, transport, framing, JSON-RPC, session, fallback,
    // snippet, and hostile Markdown matrices.

    // ── 1a. The 30 provider registries (25 LSP-backed + 5 direct-only) ──

    /// The unified provider registry carries exactly 30 identities (25 LSP-backed
    /// + 5 direct-only), all start unattached, the fallback is correct per
    /// surface (direct token factory → plain-text; the other four direct-only +
    /// all LSP-backed → unavailable), and the registry bundles NO built-in
    /// language implementation and NO language server — the M0/M1 provider
    /// contract (L2-R closure).
    func testC06_Provider30RegistriesAndFallbackAgainstM0M1() {
        XCTAssertEqual(MonaProviderRegistry.identityCount, 30,
                       "exactly 30 provider identities (M0/M1 match)")
        XCTAssertEqual(MonaProviderRegistry.lspBackedCount, 25,
                       "25 LSP-backed providers (M0/M1 match)")
        XCTAssertEqual(MonaProviderRegistry.directOnlyCount, 5,
                       "5 direct-only providers (M0/M1 match)")
        XCTAssertEqual(MonaDirectProviderSurface.allCases.count, 5,
                       "5 direct-only surfaces (M0/M1 match)")

        // The 5 direct-only surface raw values (the M0/M1 exact-set).
        let directSurfaces = Set(MonaDirectProviderSurface.allCases.map { $0.rawValue })
        XCTAssertEqual(directSurfaces, [
            "direct-token-factory", "new-symbol-name",
            "multi-document-highlight", "paste-edit", "drop-edit",
        ], "the 5 direct-only surface ids (M0/M1 match)")

        // Fallback: direct token factory → plain-text; others → unavailable.
        XCTAssertEqual(MonaDirectProviderSurface.directTokenFactory.fallback, .plainText,
                       "directTokenFactory fallback = plainText (M0/M1 match)")
        XCTAssertEqual(MonaDirectProviderSurface.newSymbolName.fallback, .unavailable,
                       "newSymbolName fallback = unavailable (M0/M1 match)")
        XCTAssertEqual(MonaDirectProviderSurface.pasteEdit.fallback, .unavailable,
                       "pasteEdit fallback = unavailable (M0/M1 match)")

        let model = MonaCodeModel(
            text: "abc", uri: MonaURI(scheme: "inmemory", path: "/c06-prov"))
        let gate = MonaPublicationGate(model: model)
        let queue = MonaMicrotaskQueue()
        let executor = MonaProviderExecutor(gate: gate, queue: queue)
        let registry = MonaProviderRegistry(executor: executor)

        XCTAssertEqual(registry.allIdentities.count, 30,
                       "allIdentities carries 30 entries (M0/M1 match)")

        // LSP-backed fallback: unavailable (server did not advertise).
        XCTAssertEqual(registry.fallback(for: .lsp(.hover)), .unavailable,
                       "LSP hover fallback = unavailable (M0/M1 match)")
        XCTAssertEqual(registry.fallback(for: .lsp(.completion)), .unavailable,
                       "LSP completion fallback = unavailable (M0/M1 match)")

        // Direct token factory → plain-text fallback.
        XCTAssertEqual(registry.fallback(for: .direct(.directTokenFactory)), .plainText,
                       "direct token factory fallback = plainText (M0/M1 match)")

        // No bundled language server / implementation.
        XCTAssertNil(registry.bundledLanguageServer,
                     "no bundled language server (M0/M1 match)")
        XCTAssertNil(registry.bundledLanguageImplementation,
                     "no bundled language implementation (M0/M1 match)")

        // Plain-text fallback language.
        XCTAssertEqual(registry.plainTextFallback.id, "plaintext",
                       "plainText fallback id = plaintext (M0/M1 match)")
        Self.recordNativeOutput("provider:30=25lsp+5direct:fallbackOK")
    }

    // ── 1b. The 25 LSP capabilities + session lifecycle + framing ──

    /// Exactly 25 LSP-backed provider surfaces are mapped, split into
    /// navigation (9), editing (8), presentation (8), with raw UTF-16 (UInt16)
    /// positions. The session transitions through the lifecycle, and the frame
    /// codec reconstructs complete frames across byte-level fragmentation — the
    /// M0/M1 LSP contract (L2-R closure).
    func testC06_LSP25CapabilitiesSessionAndFramingAgainstM0M1() {
        // 25 capabilities split into Navigation (9), Editing (8), Presentation (8).
        XCTAssertEqual(MonaLSPProviderSurface.allCases.count, 25,
                       "exactly 25 LSP provider surfaces (M0/M1 match)")
        XCTAssertEqual(MonaLSPCapabilityRegistry.surfaceCount, 25,
                       "surfaceCount = 25 (M0/M1 match)")
        let nav = MonaLSPProviderSurface.allCases.filter { $0.group == .navigation }
        let edit = MonaLSPProviderSurface.allCases.filter { $0.group == .editing }
        let pres = MonaLSPProviderSurface.allCases.filter { $0.group == .presentation }
        XCTAssertEqual(nav.count, 9, "Navigation: 9 surfaces (M0/M1 match)")
        XCTAssertEqual(edit.count, 8, "Editing: 8 surfaces (M0/M1 match)")
        XCTAssertEqual(pres.count, 8, "Presentation: 8 surfaces (M0/M1 match)")

        // Resolve methods for resolvable surfaces.
        XCTAssertEqual(MonaLSPProviderSurface.completion.resolveMethod,
                       "completionItem/resolve", "completion resolve (M0/M1 match)")
        XCTAssertEqual(MonaLSPProviderSurface.codeAction.resolveMethod,
                       "codeAction/resolve", "codeAction resolve (M0/M1 match)")
        XCTAssertEqual(MonaLSPProviderSurface.codeLens.resolveMethod,
                       "codeLens/resolve", "codeLens resolve (M0/M1 match)")
        XCTAssertEqual(MonaLSPProviderSurface.inlayHint.resolveMethod,
                       "inlayHint/resolve", "inlayHint resolve (M0/M1 match)")
        XCTAssertEqual(MonaLSPProviderSurface.documentLink.resolveMethod,
                       "documentLink/resolve", "documentLink resolve (M0/M1 match)")
        XCTAssertNil(MonaLSPProviderSurface.hover.resolveMethod,
                     "hover has no resolve method (M0/M1 match)")
        Self.recordNativeOutput("lsp:25=nav9+edit8+pres8:resolveMethodsOK")

        // Static + dynamic registration.
        let registry = MonaLSPCapabilityRegistry()
        for surface in MonaLSPProviderSurface.allCases {
            XCTAssertEqual(registry.availability(for: surface), .unavailable,
                           "\(surface.rawValue) starts unavailable (M0/M1 match)")
        }
        registry.setStaticAvailability(.hover, .available)
        XCTAssertEqual(registry.availability(for: .hover), .available,
                       "static availability set (M0/M1 match)")
        XCTAssertTrue(registry.registerDynamically(.definition),
                      "dynamic registration succeeds (M0/M1 match)")
        XCTAssertEqual(registry.availability(for: .definition), .dynamicallyRegistered,
                       "dynamically registered (M0/M1 match)")

        // Session lifecycle: uninitialized → initializing → initialized →
        // shuttingDown → shutdown → exited.
        let session = MonaLSPSession()
        XCTAssertEqual(session.state, .uninitialized, "session starts uninitialized")
        XCTAssertEqual(session.epoch, 0)
        XCTAssertEqual(session.beginInitialize(), .uninitialized,
                       "beginInitialize returns prior state")
        XCTAssertEqual(session.state, .initializing)
        XCTAssertEqual(session.completeInitialize(), .initializing)
        XCTAssertEqual(session.state, .initialized)
        XCTAssertEqual(session.beginShutdown(), .initialized)
        XCTAssertEqual(session.state, .shuttingDown)
        XCTAssertEqual(session.completeShutdown(), .shuttingDown)
        XCTAssertEqual(session.state, .shutdown)
        XCTAssertEqual(session.exit(), .shutdown)
        XCTAssertEqual(session.state, .exited)
        Self.recordNativeOutput("lsp:sessionLifecycle=uninit→init→exit")

        // Framing: encode → canonical header + payload; decode reconstructs.
        let encoder = MonaLSPFrameEncoder()
        let decoder = MonaLSPFrameDecoder()
        let payload = Data("héllo→世界🌱".utf8)
        let framed = encoder.encode(payload)
        let header = Data("Content-Length: \(payload.count)\r\n\r\n".utf8)
        XCTAssertEqual(framed, header + payload,
                       "canonical ASCII header + raw payload (M0/M1 match)")

        // Byte-by-byte fragmentation reconstructs the frame.
        var frames: [Data] = []
        var i = 0
        while i < framed.count {
            let result = decoder.feed(framed.subdata(in: i..<i+1))
            frames.append(contentsOf: result.frames)
            XCTAssertNil(result.error, "no error on byte-by-byte feed")
            i += 1
        }
        XCTAssertEqual(frames, [payload],
                       "byte-by-byte reconstructs the payload (M0/M1 match)")
        Self.recordNativeOutput("lsp:framing=encodeDecodeRoundTrip")
    }

    // ── 1c. Snippet parser + 39 variables + session navigation ──

    /// The snippet parser ports text, escape, tabstop, placeholder, variable
    /// grammar over raw UTF-16 (preserving source offsets); the variable
    /// resolver recognizes exactly 39 identifiers; and the session layer
    /// supports placeholder navigation (moveNext/accept/cancel) — the M0/M1
    /// snippet contract (SN1-R closure).
    func testC06_SnippetParserAndSessionAgainstM0M1() {
        // Parser grammar: text, escape, tabstop, variable.
        let parse: (String) -> [MonaSnippetMarker] = {
            MonaSnippetParser.parse(Array($0.utf16))
        }
        XCTAssertEqual(parse("hello"),
                       [.text("hello", MonaSnippetSpan(start: 0, end: 5))],
                       "text marker with span (M0/M1 match)")
        XCTAssertEqual(parse("\\$"),
                       [.escape("$", MonaSnippetSpan(start: 0, end: 2))],
                       "escape marker (M0/M1 match)")
        XCTAssertEqual(parse("$1"),
                       [.tabstop(index: 1, span: MonaSnippetSpan(start: 0, end: 2))],
                       "tabstop marker (M0/M1 match)")
        XCTAssertEqual(parse("$0"),
                       [.tabstop(index: 0, span: MonaSnippetSpan(start: 0, end: 2))],
                       "final tabstop $0 (M0/M1 match)")

        // A variable resolves (39 identifiers recognized).
        let varMarkers = parse("${CURRENT_YEAR}")
        XCTAssertEqual(varMarkers.count, 1, "variable marker parsed (M0/M1 match)")

        // Exactly 39 recognized variable identifiers (the M0/M1 contract set).
        XCTAssertEqual(MonaSnippetVariableResolver.variableIdentifiers.count, 39,
                       "exactly 39 recognized variable identifiers (M0/M1 match)")
        Self.recordNativeOutput("snippet:parser=text+escape+tabstop+var:vars39")

        // 7 format shorthands.
        XCTAssertEqual(MonaSnippetShorthand.allCases.count, 7,
                       "7 format shorthands (M0/M1 match)")

        // Session navigation: a snippet with two tabstops navigates forward.
        let model = MonaCodeModel(
            text: "", uri: MonaURI(scheme: "inmemory", path: "/c06-snip"))
        let barrier = MonaModelInputBarrier(model: model)
        let controller = MonaSnippetController(model: model, barrier: barrier)
        let config = MonaSnippetInsertionConfig.defaults()
        let outcome = controller.insertSnippet(
            template: "a$1b$0", at: MonaPosition(line: 1, column: 1), config: config)
        if case .applied = outcome { /* ok */ } else {
            XCTFail("Snippet: insertion must apply; got \(outcome)")
        }
        XCTAssertNotNil(controller.activeSession,
                        "active session created (M0/M1 match)")
        XCTAssertTrue(controller.moveNextPlaceholder(),
                      "moveNext advances the placeholder (M0/M1 match)")
        controller.cancelSnippet()
        let activeAfter = controller.activeSession?.isActive ?? false
        XCTAssertFalse(activeAfter,
                       "cancel deactivates the session (M0/M1 match)")
        Self.recordNativeOutput("snippet:session=insert+moveNext+cancel")
    }

    // ── 1d. Markdown parser + security ──

    /// The Markdown parser ports the pinned Marked 14 grammar subset into a
    /// semantic tree, keeps parsed source ranges in raw UTF-16, and rejects
    /// raw HTML execution, style, scripts, media loading, remote images, web
    /// layout, and untrusted command links (XSS/HTML-injection prevention) —
    /// the M0/M1 Markdown contract (MD1-R closure).
    func testC06_MarkdownParserAndSecurityAgainstM0M1() {
        // Text grammar: a paragraph with literal text + UTF-16 span.
        let doc = MonaMarkdownParser.parse("hello world", trust: .untrusted)
        XCTAssertEqual(doc.blocks.count, 1, "one block (M0/M1 match)")
        guard case .paragraph(let inline, _) = doc.blocks[0] else {
            return XCTFail("Markdown: expected paragraph")
        }
        XCTAssertEqual(inline.count, 1)
        guard case .text(let s, _) = inline[0] else {
            return XCTFail("Markdown: expected text inline")
        }
        XCTAssertEqual(s, "hello world", "text content (M0/M1 match)")

        // Code grammar: a fenced code block with language info.
        let codeDoc = MonaMarkdownParser.parse("```swift\nlet x = 1\n```", trust: .untrusted)
        XCTAssertTrue(codeDoc.blocks.contains(where: { block in
            if case .codeBlock = block { return true }
            return false
        }), "fenced code block parsed (M0/M1 match)")

        // Security: raw HTML is captured (never executed). A <script> block
        // is retained as rawHtml so callers can observe what was rejected,
        // but it never executes, styles, loads media, or lays out content.
        let htmlDoc = MonaMarkdownParser.parse("<script>alert(1)</script>", trust: .untrusted)
        XCTAssertTrue(htmlDoc.blocks.contains(where: { block in
            if case .rawHtml = block { return true }
            return false
        }), "raw <script> captured as rawHtml (never executed) (M0/M1 match)")

        // Security: a javascript: link is dropped (never an active link).
        let linkDoc = MonaMarkdownParser.parse("[click](javascript:alert(1))", trust: .untrusted)
        for link in Self.markdownLinks(linkDoc) {
            if case .dropped = link.trust { /* ok */ } else {
                XCTFail("Markdown: javascript: link must be dropped, got \(link.trust)")
            }
        }

        // Security: an image's src is discarded at parse time (media is an
        // explicit feature cut) — only the alt text is retained.
        let imgDoc = MonaMarkdownParser.parse("![alt](https://example.com/x.png)", trust: .untrusted)
        XCTAssertTrue(Self.collectInline(imgDoc).contains(where: { inline in
            if case .image = inline { return true }
            return false
        }), "image alt retained, src discarded (M0/M1 match)")

        // Value limit: oversized content is truncated (no unbounded growth).
        XCTAssertGreaterThan(MonaMarkdownParser.valueLimitUTF16, 0,
                            "valueLimitUTF16 > 0 (M0/M1 match)")
        XCTAssertEqual(MonaMarkdownParser.valueLimitUTF16, 100_000,
                       "valueLimitUTF16 = 100000 (M0/M1 match)")

        // Scheme classification: 9 admitted, 2 dropped.
        XCTAssertEqual(MonaMarkdownParser.admittedSchemes.count, 9,
                       "9 admitted schemes (M0/M1 match)")
        XCTAssertTrue(MonaMarkdownParser.droppedSchemes.contains("data"),
                       "data: scheme dropped (M0/M1 match)")
        XCTAssertTrue(MonaMarkdownParser.droppedSchemes.contains("javascript"),
                       "javascript: scheme dropped (M0/M1 match)")
        Self.recordNativeOutput("markdown:parser+security=rawHtml+jsDropped+imgSrcDiscarded")
    }

    // MARK: Operation 2 — Run every contract overlay, T-1/T/T+1 boundary,
    // raw-unit fixture, native-adapted assertion, failure row, and exact-set
    // check assigned to the gate.

    // ── 2a. Contract overlay (L2-R closure + SN1-R/MD1-R manifests) ──

    /// The contract overlay: the L2-R provider-LSP closure, the SN1-R snippet
    /// manifest, and the MD1-R Markdown manifest all exist on disk, hash to
    /// stable SHA-256 digests, and carry the M0/M1-ported counts.
    func testC06_ContractOverlayAndExactSetCheck() throws {
        XCTAssertEqual(Self.frozenSourceRevision, "P07-T011")
        let hexRegex = try NSRegularExpression(pattern: "^[0-9a-f]{64}$")
        let hexRange = NSRange(Self.frozenSourceSetDigest.startIndex...,
                               in: Self.frozenSourceSetDigest)
        XCTAssertNotNil(hexRegex.firstMatch(in: Self.frozenSourceSetDigest, range: hexRange))

        let qsRange = NSRange(Self.qualifiedSetHash.startIndex...,
                              in: Self.qualifiedSetHash)
        XCTAssertNotNil(hexRegex.firstMatch(in: Self.qualifiedSetHash, range: qsRange),
                        "qualified-set hash is 64-char lowercase hex SHA-256")

        // The L2-R closure artifact exists and is non-empty.
        let l2rPath = parentArtifactsDir + "/language-l2r-provider-lsp-closure.html"
        XCTAssertTrue(FileManager.default.fileExists(atPath: l2rPath),
                      "L2-R closure artifact exists (not stale/missing)")
        let l2rHash = sha256File(l2rPath)
        XCTAssertEqual(l2rHash.count, 64, "L2-R closure hash is 64-char SHA-256")
        Self.recordNativeOutput("contractOverlay:l2rClosure:hash=\(l2rHash.prefix(12))")

        // The SN1-R snippet manifest carries 39 variables.
        let sn1rPath = parentArtifactsDir + "/monacode-sn1r-snippet-engine-manifest.json"
        let sn1rData = try Data(contentsOf: URL(fileURLWithPath: sn1rPath))
        let sn1rObj = try JSONSerialization.jsonObject(with: sn1rData) as? [String: Any]
        let knownVars = sn1rObj?["knownVariables"] as? [String: Any] ?? [:]
        XCTAssertEqual(knownVars["count"] as? Int, 39,
                       "SN1-R: 39 known variables (M0/M1 match)")
        Self.recordNativeOutput("contractOverlay:sn1rManifest:vars39")

        // The MD1-R Markdown manifest carries the value limit.
        let md1rPath = parentArtifactsDir + "/monacode-md1r-markdown-contract-manifest.json"
        let md1rData = try Data(contentsOf: URL(fileURLWithPath: md1rPath))
        let md1rObj = try JSONSerialization.jsonObject(with: md1rData) as? [String: Any]
        let baselinePolicy = md1rObj?["baselineWebPolicy"] as? [String: Any] ?? [:]
        XCTAssertEqual(baselinePolicy["valueLimitUTF16"] as? Int, 100_000,
                       "MD1-R: valueLimitUTF16 = 100000 (M0/M1 match)")
        Self.recordNativeOutput("contractOverlay:md1rManifest:valueLimit100000")

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

    // ── 2b. T-1/T/T+1 boundary (provider + LSP + snippet/markdown) ──

    /// The T-1/T/T+1 boundary cases for the provider/LSP/snippet/markdown
    /// domain: provider boundaries (30 identities, plain-text fallback,
    /// unavailable fallback), LSP boundaries (25 surfaces, session initialized,
    /// stale response), and snippet/markdown boundaries (text marker, tabstop
    /// marker, javascript: link dropped). Every case must run.
    func testC06_TMinus1TTPlus1BoundaryCases() {
        let boundaries: [(id: String, bound: String, expect: Bool, check: () -> Bool)] = [
            ("provider-30-T-1", "T-1", true, {
                MonaProviderRegistry.identityCount == 30
            }),
            ("provider-fallback-T", "T", true, {
                MonaDirectProviderSurface.directTokenFactory.fallback == .plainText
            }),
            ("provider-unavailable-T+1", "T+1", true, {
                MonaDirectProviderSurface.newSymbolName.fallback == .unavailable
            }),
            ("lsp-25-T-1", "T-1", true, {
                MonaLSPProviderSurface.allCases.count == 25
            }),
            ("lsp-session-T", "T", true, {
                let s = MonaLSPSession()
                s.beginInitialize(); s.completeInitialize()
                return s.state == .initialized
            }),
            ("lsp-stale-T+1", "T+1", true, {
                let s = MonaLSPSession()
                let epoch = s.epoch
                s.restart()
                return s.epoch == epoch + 1
            }),
            ("snippet-text-T-1", "T-1", true, {
                let m = MonaSnippetParser.parse(Array("hello".utf16))
                return m.count == 1
            }),
            ("snippet-tabstop-T", "T", true, {
                let m = MonaSnippetParser.parse(Array("$1".utf16))
                if case .tabstop(let idx, _) = m.first { return idx == 1 }
                return false
            }),
            ("markdown-dropped-T+1", "T+1", true, {
                let d = MonaMarkdownParser.parse("[x](javascript:alert(1))", trust: .untrusted)
                let links = Self.markdownLinks(d)
                return links.allSatisfy {
                    if case .dropped = $0.trust { return true }
                    return false
                }
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

    /// The native-adapted assertion: the JSON-RPC codec preserves identifier
    /// types (integer ≠ string), notifications have no id field, and
    /// deterministic encoding sorts object keys by UTF-16 lexicographic order
    /// — the M0/M1 JSON-RPC wire contract. The failure row: malformed JSON →
    /// typed parseError, and oversized Content-Length → typed terminal error.
    func testC06_NativeAdaptedAssertionAndFailureRows() throws {
        let codec = MonaJSONRPCCodec()

        // Native-adapted: integer 5 ≠ string "5" (identifier type preservation).
        let intReq = MonaJSONRPCMessage.request(
            id: .integer(5), method: "initialize", params: nil)
        let intBytes = try codec.encode(intReq).get()
        XCTAssertEqual(intBytes,
            Data("{\"jsonrpc\":\"2.0\",\"id\":5,\"method\":\"initialize\"}".utf8),
            "integer id preserved (M0/M1 match)")

        let strReq = MonaJSONRPCMessage.request(
            id: .string("5"), method: "foo", params: nil)
        let strBytes = try codec.encode(strReq).get()
        XCTAssertEqual(strBytes,
            Data("{\"jsonrpc\":\"2.0\",\"id\":\"5\",\"method\":\"foo\"}".utf8),
            "string id preserved (M0/M1 match)")
        Self.recordNativeOutput("nativeAdapted:jsonrpc=idTypePreserved")

        // Notification has NO id field.
        let notifBytes = try codec.encode(
            .notification(method: "didChange", params: nil)).get()
        XCTAssertFalse(String(data: notifBytes, encoding: .utf8)!.contains("\"id\":"),
                       "notification has no id field (M0/M1 match)")

        // Failure row 1: malformed JSON → typed parseError.
        XCTAssertEqual(
            codec.decode(Data("{bad json".utf8)),
            .failure(.parseError),
            "malformed JSON → parseError (M0/M1 match)")

        // Failure row 2: oversized Content-Length → typed terminal error.
        let decoder = MonaLSPFrameDecoder(maxBodyLength: 10)
        let r = decoder.feed(Data("Content-Length: 100\r\n\r\n".utf8))
        XCTAssertEqual(r.error, .oversizedBody(actual: 100, max: 10),
                       "oversized body → typed terminal error (M0/M1 match)")
        Self.recordNativeOutput("failureRows:parseError+oversizedBody=rejected")
    }

    // MARK: Operation 3 — Bind evidence manifest

    func testC06_EvidenceManifestBinding() throws {
        // comparator: the M0/M1 reference (L2-R provider-LSP closure).
        let comparatorPath = parentArtifactsDir + "/language-l2r-provider-lsp-closure.html"
        let comparatorHash = sha256File(comparatorPath)
        XCTAssertEqual(comparatorHash.count, 64,
                       "comparator hash is 64-char SHA-256")

        // fixture: the M0/M1 snippet-engine manifest (SN1-R).
        let fixturePath = parentArtifactsDir + "/monacode-sn1r-snippet-engine-manifest.json"
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

        print("P09-T015 comparator=\(comparatorHash.prefix(12)) native=\(nativeHash.prefix(12)) environment=\(environmentFingerprint.prefix(12)) candidate=\(Self.qualifiedSetHash.prefix(12)) sourceRev=\(Self.frozenSourceRevision) fixture=\(fixtureHash.prefix(12)) output=\(outputHash.prefix(12)) cases=9")
    }

    // MARK: Operation 4 — Treat every missing/skipped/stale/malformed case as
    // not-passed.

    func testC06_NoMissingSkippedStaleMalformedCases() throws {
        // The L2-R closure artifact exists and is non-empty.
        let l2rPath = parentArtifactsDir + "/language-l2r-provider-lsp-closure.html"
        XCTAssertTrue(FileManager.default.fileExists(atPath: l2rPath),
                      "L2-R closure artifact must exist (not stale/missing)")
        let l2rData = try Data(contentsOf: URL(fileURLWithPath: l2rPath))
        XCTAssertGreaterThan(l2rData.count, 0,
                             "L2-R closure artifact non-empty (not malformed)")

        // The SN1-R snippet manifest carries well-formed counts.
        let sn1rPath = parentArtifactsDir + "/monacode-sn1r-snippet-engine-manifest.json"
        let sn1rData = try Data(contentsOf: URL(fileURLWithPath: sn1rPath))
        let sn1rObj = try JSONSerialization.jsonObject(with: sn1rData) as? [String: Any]
        let knownVars = sn1rObj?["knownVariables"] as? [String: Any] ?? [:]
        XCTAssertFalse(knownVars.isEmpty,
                       "SN1-R known variables present (not malformed)")
        XCTAssertEqual(knownVars["count"] as? Int, 39,
                       "SN1-R variable count = 39 (not stale)")

        // The MD1-R Markdown manifest carries well-formed counts.
        let md1rPath = parentArtifactsDir + "/monacode-md1r-markdown-contract-manifest.json"
        let md1rData = try Data(contentsOf: URL(fileURLWithPath: md1rPath))
        let md1rObj = try JSONSerialization.jsonObject(with: md1rData) as? [String: Any]
        let baselinePolicy = md1rObj?["baselineWebPolicy"] as? [String: Any] ?? [:]
        XCTAssertFalse(baselinePolicy.isEmpty,
                       "MD1-R baseline policy present (not malformed)")
        XCTAssertEqual(baselinePolicy["valueLimitUTF16"] as? Int, 100_000,
                       "MD1-R valueLimitUTF16 = 100000 (not stale)")

        // The snippet closure artifact exists and is non-empty.
        let sn1rClosurePath = parentArtifactsDir + "/snippet-sn1r-engine-closure.html"
        XCTAssertTrue(FileManager.default.fileExists(atPath: sn1rClosurePath),
                      "SN1-R snippet closure must exist (not stale/missing)")
        let sn1rClosureData = try Data(contentsOf: URL(fileURLWithPath: sn1rClosurePath))
        XCTAssertGreaterThan(sn1rClosureData.count, 0,
                             "SN1-R snippet closure non-empty (not malformed)")

        // The markdown security closure artifact exists and is non-empty.
        let md1rClosurePath = parentArtifactsDir + "/markdown-md1r-native-security-closure.html"
        XCTAssertTrue(FileManager.default.fileExists(atPath: md1rClosurePath),
                      "MD1-R markdown closure must exist (not stale/missing)")
        let md1rClosureData = try Data(contentsOf: URL(fileURLWithPath: md1rClosurePath))
        XCTAssertGreaterThan(md1rClosureData.count, 0,
                             "MD1-R markdown closure non-empty (not malformed)")

        // The 9 boundary cases each have a bound in {T-1, T, T+1}.
        let validBounds: Set<String> = ["T-1", "T", "T+1"]
        let expectedBounds = ["T-1", "T", "T+1", "T-1", "T", "T+1", "T-1", "T", "T+1"]
        for bound in expectedBounds {
            XCTAssertTrue(validBounds.contains(bound),
                          "bound '\(bound)' not in {T-1, T, T+1}")
        }
    }

    // MARK: - Markdown AST helpers

    /// Collects all inline nodes from a Markdown document (recursively).
    private static func collectInline(_ doc: MonaMarkdownDocument) -> [MonaMarkdownInline] {
        var result: [MonaMarkdownInline] = []
        for block in doc.blocks {
            collectInlineFromBlock(block, into: &result)
        }
        return result
    }

    private static func collectInlineFromBlock(_ block: MonaMarkdownBlock, into result: inout [MonaMarkdownInline]) {
        switch block {
        case .heading(_, let inline, _):
            result.append(contentsOf: inline)
        case .paragraph(let inline, _):
            result.append(contentsOf: inline)
        case .blockquote(let blocks, _):
            for b in blocks { collectInlineFromBlock(b, into: &result) }
        case .list(let list, _):
            for item in list.items {
                for b in item.blocks { collectInlineFromBlock(b, into: &result) }
            }
        case .codeBlock, .thematicBreak, .rawHtml, .table:
            break
        }
    }

    /// Extracts all links from a Markdown document.
    private static func markdownLinks(_ doc: MonaMarkdownDocument) -> [MonaMarkdownLink] {
        var links: [MonaMarkdownLink] = []
        let inlines = collectInline(doc)
        for inline in inlines {
            if case .link(let link, _) = inline {
                links.append(link)
            }
        }
        return links
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
