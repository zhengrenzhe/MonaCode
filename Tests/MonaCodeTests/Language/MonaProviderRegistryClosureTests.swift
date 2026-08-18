// MonaProviderRegistryClosureTests.swift
//
// P06-T005 — Close all 30 provider registries and five direct-only surfaces.
//
// Verifies the four implementation-operation contracts:
//   1. Register exactly 30 provider identities: 25 LSP-backed and five
//      direct-only.
//   2. Implement direct token factory, new-symbol-name, multi-document-
//      highlight, paste-edit, and drop-edit adapters WITHOUT pretending they
//      are LSP capabilities.
//   3. Return explicit unavailable capability or plain-text behavior when no
//      provider is attached.
//   4. Never bundle a built-in language implementation or server.
//
// Test contract (P06-T005): exactly 30 identities (25 LSP-backed + 5
// direct-only); the 5 direct-only are distinct from LSP; unavailable /
// plain-text when no provider; no bundled built-in language/server.

import XCTest
import MonaCode

final class MonaProviderRegistryClosureTests: XCTestCase {

    // MARK: - Helpers

    /// A model + gate + executor + registry wired for a test.
    private func makeRegistry() -> (MonaCodeModel, MonaPublicationGate, MonaProviderExecutor, MonaProviderRegistry) {
        let model = MonaCodeModel(text: "abc", uri: MonaURI(scheme: "inmemory", path: "/t005"))
        let gate = MonaPublicationGate(model: model)
        let executor = MonaProviderExecutor(gate: gate)
        let registry = MonaProviderRegistry(executor: executor)
        return (model, gate, executor, registry)
    }

    // MARK: - 1. Exactly 30 provider identities (25 LSP-backed + 5 direct-only)

    func testExactly30ProviderIdentitiesByConstants() {
        XCTAssertEqual(MonaProviderRegistry.identityCount, 30)
        XCTAssertEqual(MonaProviderRegistry.lspBackedCount, 25)
        XCTAssertEqual(MonaProviderRegistry.directOnlyCount, 5)
        XCTAssertEqual(MonaProviderRegistry.lspBackedCount + MonaProviderRegistry.directOnlyCount, 30)
    }

    func testAllIdentitiesCountIsExactly30() {
        let (_, _, _, registry) = makeRegistry()
        let identities = registry.allIdentities
        XCTAssertEqual(identities.count, 30, "allIdentities must enumerate exactly 30")
    }

    func test25LSPBackedIdentities() {
        let (_, _, _, registry) = makeRegistry()
        let lsp = registry.allIdentities.filter { $0.isLSPBacked }
        XCTAssertEqual(lsp.count, 25, "25 LSP-backed identities")
    }

    func test5DirectOnlyIdentities() {
        let (_, _, _, registry) = makeRegistry()
        let direct = registry.allIdentities.filter { $0.isDirectOnly }
        XCTAssertEqual(direct.count, 5, "5 direct-only identities")
    }

    func testNoIdentityIsBothLSPBackedAndDirectOnly() {
        let (_, _, _, registry) = makeRegistry()
        for identity in registry.allIdentities {
            XCTAssertNotEqual(identity.isLSPBacked, identity.isDirectOnly,
                "identity cannot be both LSP-backed and direct-only")
        }
    }

    func test30IdentitiesAreAllDistinct() {
        let (_, _, _, registry) = makeRegistry()
        let unique = Set(registry.allIdentities)
        XCTAssertEqual(unique.count, 30, "all 30 identities must be distinct")
    }

    func testLSPBackedIdentitiesMatchThe25T004Surfaces() {
        let (_, _, _, registry) = makeRegistry()
        let lspSurfaces = registry.allIdentities.compactMap { identity -> MonaLSPProviderSurface? in
            if case .lsp(let s) = identity { return s }
            return nil
        }
        XCTAssertEqual(Set(lspSurfaces), Set(MonaLSPProviderSurface.allCases))
        XCTAssertEqual(lspSurfaces.count, 25)
    }

    func testDirectOnlyIdentitiesMatchThe5DirectSurfaces() {
        let (_, _, _, registry) = makeRegistry()
        let directSurfaces = registry.allIdentities.compactMap { identity -> MonaDirectProviderSurface? in
            if case .direct(let s) = identity { return s }
            return nil
        }
        XCTAssertEqual(Set(directSurfaces), Set(MonaDirectProviderSurface.allCases))
        XCTAssertEqual(directSurfaces.count, 5)
    }

    // MARK: - 2. The 5 direct-only are distinct from LSP (not pretending)

    func testDirectOnlySurfaceCountIs5() {
        XCTAssertEqual(MonaDirectProviderSurface.allCases.count, 5)
    }

    func testDirectOnlySurfacesAreNotLSPCapabilities() {
        for surface in MonaDirectProviderSurface.allCases {
            XCTAssertFalse(surface.isLSPCapability,
                "direct-only surface \(surface.rawValue) must NOT be an LSP capability")
            XCTAssertNil(surface.lspMethod,
                "direct-only surface \(surface.rawValue) must have no LSP method name")
        }
    }

    func testDirectOnlyRawValuesDoNotCollideWithLSPMethodNames() {
        let lspMethods = Set(MonaLSPProviderSurface.allCases.map { $0.method })
        for surface in MonaDirectProviderSurface.allCases {
            XCTAssertFalse(lspMethods.contains(surface.rawValue),
                "direct-only raw value \(surface.rawValue) must NOT collide with any LSP method name")
        }
    }

    func testFiveDirectOnlySurfacesAreTheContractSet() {
        // The 5 direct-only surface ids from the P06-T005 spec.
        let expected: Set<String> = [
            "direct-token-factory",
            "new-symbol-name",
            "multi-document-highlight",
            "paste-edit",
            "drop-edit",
        ]
        let actual = Set(MonaDirectProviderSurface.allCases.map { $0.rawValue })
        XCTAssertEqual(actual, expected)
        XCTAssertEqual(actual.count, 5)
    }

    func testDirectAdaptersShareTheExecutorPublicationQueue() {
        let (_, _, executor, registry) = makeRegistry()
        for surface in MonaDirectProviderSurface.allCases {
            let adapter = registry.directAdapter(for: surface)
            XCTAssertNotNil(adapter, "registry must hold an adapter for \(surface.rawValue)")
            XCTAssertTrue(adapter?.executor === executor,
                "direct adapter for \(surface.rawValue) must share the executor's publication queue")
        }
    }

    func testLSPAdaptersShareTheExecutorPublicationQueue() {
        let (_, _, executor, registry) = makeRegistry()
        // The 25 LSP-backed adapters share the SAME executor as the 5
        // direct-only adapters — ONE publication path, no parallel mechanism.
        for surface in MonaLSPProviderSurface.allCases {
            let adapter = registry.lspAdapters.adapter(for: surface)
            XCTAssertNotNil(adapter)
            XCTAssertTrue(adapter?.executor === executor,
                "LSP adapter for \(surface.method) must share the executor's publication queue")
        }
    }

    // MARK: - 3. Unavailable / plain-text when no provider attached

    func testAll25LSPBackedSurfacesStartUnavailable() {
        let (_, _, _, registry) = makeRegistry()
        for surface in MonaLSPProviderSurface.allCases {
            let identity = MonaProviderIdentity.lsp(surface)
            XCTAssertFalse(registry.isAttached(identity),
                "LSP surface \(surface.method) must start unattached (unavailable)")
            XCTAssertEqual(registry.fallback(for: identity), .unavailable,
                "LSP surface \(surface.method) fallback must be .unavailable")
        }
    }

    func testAll5DirectOnlySurfacesStartUnattached() {
        let (_, _, _, registry) = makeRegistry()
        for surface in MonaDirectProviderSurface.allCases {
            let identity = MonaProviderIdentity.direct(surface)
            XCTAssertFalse(registry.isAttached(identity),
                "direct surface \(surface.rawValue) must start unattached")
        }
    }

    func testDirectTokenFactoryFallbackIsPlainText() {
        let (_, _, _, registry) = makeRegistry()
        let identity = MonaProviderIdentity.direct(.directTokenFactory)
        XCTAssertEqual(registry.fallback(for: identity), .plainText,
            "direct token factory fallback must be plain-text (reuses MonaPlainTextLanguage)")
    }

    func testOtherFourDirectOnlyFallbacksAreUnavailable() {
        let (_, _, _, registry) = makeRegistry()
        let others: [MonaDirectProviderSurface] = [
            .newSymbolName, .multiDocumentHighlight, .pasteEdit, .dropEdit,
        ]
        for surface in others {
            let identity = MonaProviderIdentity.direct(surface)
            XCTAssertEqual(registry.fallback(for: identity), .unavailable,
                "direct surface \(surface.rawValue) fallback must be .unavailable")
        }
    }

    func testDirectTokenFactorySurfaceFallbackIsPlainText() {
        XCTAssertEqual(MonaDirectProviderSurface.directTokenFactory.fallback, .plainText)
    }

    func testOtherFourDirectOnlySurfaceFallbacksAreUnavailable() {
        let others: [MonaDirectProviderSurface] = [
            .newSymbolName, .multiDocumentHighlight, .pasteEdit, .dropEdit,
        ]
        for surface in others {
            XCTAssertEqual(surface.fallback, .unavailable,
                "direct surface \(surface.rawValue) surface fallback must be .unavailable")
        }
    }

    func testPlainTextFallbackReusesMonaPlainTextLanguage() {
        let (_, _, _, registry) = makeRegistry()
        let plainText = registry.plainTextFallback
        XCTAssertEqual(plainText.id, MonaPlainTextLanguage.languageId)
        XCTAssertEqual(plainText.id, "plaintext")
        XCTAssertFalse(plainText.hasTokenization,
            "plain-text fallback performs no tokenization")
        XCTAssertFalse(plainText.hasGrammar,
            "plain-text fallback bundles no grammar")
        XCTAssertFalse(plainText.hasProvider,
            "plain-text fallback bundles no provider")
    }

    // MARK: - 4. Never bundle a built-in language implementation or server

    func testRegistryBundlesNoBuiltInLanguageServer() {
        let (_, _, _, registry) = makeRegistry()
        // The registry holds attachment points only — it does NOT ship a
        // built-in language server. Hosts/LSP supply the server.
        XCTAssertNil(registry.bundledLanguageServer,
            "registry must NOT bundle a built-in language server")
    }

    func testRegistryBundlesNoBuiltInLanguageImplementation() {
        let (_, _, _, registry) = makeRegistry()
        // The registry holds attachment points only — it does NOT ship a
        // built-in language implementation. Hosts/LSP supply providers.
        XCTAssertNil(registry.bundledLanguageImplementation,
            "registry must NOT bundle a built-in language implementation")
    }

    func testRegistryStartsEmptyOfAttachedProviders() {
        let (_, _, _, registry) = makeRegistry()
        // No provider is attached by default — the Core provides only the
        // registry + plain-text fallback. Hosts/LSP supply providers.
        let attached = registry.allIdentities.filter { registry.isAttached($0) }
        XCTAssertEqual(attached.count, 0,
            "registry must start with zero attached providers")
    }

    func testRegistryOnlyProvidesPlainTextFallbackBehavior() {
        let (_, _, _, registry) = makeRegistry()
        // The ONLY Core-provided fallback behavior is plain-text (for the
        // direct token factory). Every other surface is unavailable.
        let plainTextSurfaces = registry.allIdentities.filter {
            registry.fallback(for: $0) == .plainText
        }
        XCTAssertEqual(plainTextSurfaces.count, 1,
            "exactly one surface (direct token factory) has a plain-text fallback")
        XCTAssertEqual(plainTextSurfaces, [.direct(.directTokenFactory)])
    }

    // MARK: - Registration, lookup, release

    func testDirectProviderAttachAndRelease() {
        let (_, _, _, registry) = makeRegistry()
        let identity = MonaProviderIdentity.direct(.newSymbolName)
        XCTAssertFalse(registry.isAttached(identity))
        registry.attachDirect(.newSymbolName)
        XCTAssertTrue(registry.isAttached(identity))
        registry.releaseDirect(.newSymbolName)
        XCTAssertFalse(registry.isAttached(identity))
    }

    func testDirectProviderReleaseIsIdempotent() {
        let (_, _, _, registry) = makeRegistry()
        registry.attachDirect(.pasteEdit)
        XCTAssertTrue(registry.isAttached(.direct(.pasteEdit)))
        registry.releaseDirect(.pasteEdit)
        XCTAssertFalse(registry.isAttached(.direct(.pasteEdit)))
        // A second release is a no-op (idempotent).
        registry.releaseDirect(.pasteEdit)
        XCTAssertFalse(registry.isAttached(.direct(.pasteEdit)))
    }

    func testLSPStaticAvailabilityRegistersAsAttached() {
        let (_, _, _, registry) = makeRegistry()
        let identity = MonaProviderIdentity.lsp(.hover)
        XCTAssertFalse(registry.isAttached(identity))
        registry.lspCapabilities.setStaticAvailability(.hover, .available)
        XCTAssertTrue(registry.isAttached(identity))
        XCTAssertEqual(registry.fallback(for: identity), .unavailable,
            "LSP-backed fallback is always .unavailable (provider attaches, not fallback)")
    }

    func testLSPUnregisterReturnsToUnavailable() {
        let (_, _, _, registry) = makeRegistry()
        registry.lspCapabilities.setStaticAvailability(.completion, .available)
        XCTAssertTrue(registry.isAttached(.lsp(.completion)))
        XCTAssertTrue(registry.lspCapabilities.unregister(.completion))
        XCTAssertFalse(registry.isAttached(.lsp(.completion)))
    }

    func testDirectAdapterPublishesThroughExecutorNotLSP() {
        // A direct-only adapter publishes through the deterministic executor
        // (the SAME path as the 25 LSP-backed adapters), NOT through the LSP
        // session. It does not pretend to be an LSP capability.
        let (model, _, executor, registry) = makeRegistry()
        let adapter = registry.directAdapter(for: .dropEdit)!
        XCTAssertEqual(adapter.surface, .dropEdit)
        XCTAssertFalse(adapter.surface.isLSPCapability,
            "drop-edit adapter must NOT pretend to be an LSP capability")
        XCTAssertNil(adapter.surface.lspMethod)

        // Publish a value through the executor — the ticket (captured at
        // issue time) is the only gate; the direct adapter funnels through
        // the SAME publication queue as the LSP-backed adapters.
        let gate = MonaPublicationGate(model: model)
        let ticket = gate.captureTicket()
        var received = false
        _ = adapter.publish(value: "drop-edit-result", ticket: ticket) { _ in
            received = true
        }
        executor.drain()
        XCTAssertTrue(received,
            "direct adapter must publish through the executor (drain delivers)")
    }
}
