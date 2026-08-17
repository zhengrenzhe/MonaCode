// MonaLanguageRegistryTests.swift
//
// P05-T008 — Retain only core language metadata and explicit plain-text fallback.
//
// Verifies the Core language registry:
//   - Retains EXACTLY ONE language metadata identity as live (the plain-text
//     core fallback, `"plaintext"`, `core-fallback-metadata`).
//   - Records all 90 built-in language descriptors as `cut-built-in-language-
//     content` with NO bundled grammar and NO provider.
//   - Exposes explicit host registration for host-provided metadata.
//   - Falls back to the plain-text language when no language/provider is
//     registered for a model.
//   - Disposal is idempotent.
//
// On Green, `testLanguageRegistryContractLeaf` prints the contract line:
//     LANGUAGES total=91 retained=1 cut=90 fallback=plaintext hostRegistered=0 excluded=pass fallbackBehavior=pass idempotent=pass

import XCTest
import MonaCode

final class MonaLanguageRegistryTests: XCTestCase {

    // MARK: - 1. Exactly one retained fallback metadata identity

    func testLanguageRegistryRetainsExactlyOneLiveFallbackIdentity() {
        let registry = MonaLanguageRegistry()
        // 91 frozen identities: 1 core-fallback-metadata + 90 cut-built-in.
        XCTAssertEqual(MonaLanguageRegistry.frozenIdentities.count, 91)
        XCTAssertEqual(registry.totalCount, 91)
        XCTAssertEqual(registry.liveCount, 1)
        XCTAssertEqual(registry.cutCount, 90)
    }

    func testLanguageRegistryLiveIdentityIsPlainTextCoreFallback() {
        let registry = MonaLanguageRegistry()
        let live = registry.liveIdentities
        XCTAssertEqual(live.count, 1)
        XCTAssertEqual(live[0].id, "plaintext")
        XCTAssertEqual(live[0].disposition, .coreFallbackMetadata)
        XCTAssertTrue(live[0].isLive)
        XCTAssertEqual(live[0].hasLoader, false)
        // The retained fallback identity equals MonaPlainTextLanguage.identity.
        XCTAssertEqual(registry.fallbackIdentity, MonaPlainTextLanguage.identity)
        XCTAssertEqual(registry.fallbackIdentity.id, "plaintext")
    }

    func testLanguageRegistryFallbackIdentityMetadataIsVerbatimFromManifest() {
        let registry = MonaLanguageRegistry()
        let fallback = registry.fallbackIdentity
        XCTAssertEqual(fallback.descriptor.id, "plaintext")
        XCTAssertEqual(fallback.descriptor.aliases, ["Plain Text", "text"])
        XCTAssertEqual(fallback.descriptor.extensions, [".txt"])
        XCTAssertEqual(fallback.descriptor.mimetypes, ["text/plain"])
    }

    // MARK: - 2. All 90 built-in descriptors recorded as cut (no grammar/provider)

    func testLanguageRegistryRecordsAllNinetyBuiltInsAsCutBuiltinLanguageContent() {
        let registry = MonaLanguageRegistry()
        let cut = registry.cutIdentities
        XCTAssertEqual(cut.count, 90)
        // Every cut identity is disposition == cut-builtin-language-content and
        // NOT live.
        for identity in cut {
            XCTAssertEqual(identity.disposition, .cutBuiltinLanguageContent)
            XCTAssertFalse(identity.isLive)
        }
    }

    func testLanguageRegistryCutIdentitiesAreUniqueAndInManifestSourceOrder() {
        let registry = MonaLanguageRegistry()
        let cut = registry.cutIdentities
        // No coalescing: every cut id is unique.
        let ids = cut.map { $0.id }
        XCTAssertEqual(Set(ids).count, ids.count)
        // First 3 and last 3 in manifest source order (alphabetical).
        let expectedFirst = ["abap", "aes", "apex"]
        let actualFirst = Array(ids.prefix(3))
        XCTAssertEqual(actualFirst, expectedFirst)
        let expectedLast = ["xml", "yaml"]
        let actualLast = Array(ids.suffix(2))
        XCTAssertEqual(actualLast, expectedLast)
    }

    func testLanguageRegistryCutIdentitiesCarryNoBundledGrammarOrProvider() {
        let registry = MonaLanguageRegistry()
        // The cut built-in language identity type carries ONLY metadata
        // (id, disposition, hasLoader, descriptor). It has NO grammar field,
        // NO provider field, and NO bundled loader/TokenizerConfig — the
        // `MonaLanguageIdentity` type exposes none of those. `hasLoader` is a
        // recorded metadata fact about the original monaco-editor built-in,
        // NOT a bundled loader.
        let python = registry.cutBuiltInIdentity(for: "python")
        XCTAssertNotNil(python)
        XCTAssertEqual(python?.disposition, .cutBuiltinLanguageContent)
        XCTAssertFalse(python?.isLive ?? true)
        XCTAssertEqual(python?.hasLoader, true) // recorded fact, not a bundle
        XCTAssertEqual(python?.descriptor.id, "python")
        XCTAssertEqual(python?.descriptor.aliases, ["Python", "py"])
        XCTAssertEqual(python?.descriptor.extensions, [".py", ".rpy", ".pyw", ".cpy", ".gyp", ".gypi"])
        // json is the only cut built-in whose original had no loader.
        let json = registry.cutBuiltInIdentity(for: "json")
        XCTAssertNotNil(json)
        XCTAssertEqual(json?.hasLoader, false)
        // `json` is still CUT (not live) despite hasLoader == false.
        XCTAssertEqual(json?.disposition, .cutBuiltinLanguageContent)
        XCTAssertFalse(json?.isLive ?? true)
    }

    func testLanguageRegistryCutBuiltInsAreNotLiveRegistrations() {
        let registry = MonaLanguageRegistry()
        // Cut built-in descriptors are recorded as UNAVAILABLE: they are NOT
        // registered as live (contains returns false for every cut id).
        XCTAssertFalse(registry.contains("python"))
        XCTAssertFalse(registry.contains("javascript"))
        XCTAssertFalse(registry.contains("typescript"))
        XCTAssertFalse(registry.contains("json"))
        XCTAssertFalse(registry.contains("swift"))
        XCTAssertFalse(registry.contains("html"))
        // The cut lookup accessor returns the recorded descriptor (metadata
        // only), while the live lookup returns nil.
        XCTAssertNotNil(registry.cutBuiltInIdentity(for: "typescript"))
        XCTAssertNil(registry.frozenLiveIdentity(for: "typescript"))
    }

    // MARK: - 3. Host registration

    func testLanguageRegistryHostRegistrationRegistersLiveMetadata() {
        let registry = MonaLanguageRegistry()
        XCTAssertEqual(registry.hostRegisteredCount, 0)
        XCTAssertNil(registry.hostRegisteredIdentity(for: "mylang"))

        let hostLang = MonaLanguageIdentity(
            id: "mylang",
            disposition: .hostProvided,
            hasLoader: true,
            aliases: ["My Language", "mylang"],
            extensions: [".myl"],
            mimetypes: ["text/x-mylang"]
        )
        registry.register(hostLang)

        XCTAssertEqual(registry.hostRegisteredCount, 1)
        XCTAssertEqual(registry.hostRegisteredIdentity(for: "mylang"), hostLang)
        XCTAssertTrue(registry.contains("mylang"))
    }

    func testLanguageRegistryHostRegistrationIsIdempotentReplacement() {
        let registry = MonaLanguageRegistry()
        let first = MonaLanguageIdentity(
            id: "mylang", disposition: .hostProvided, hasLoader: true,
            aliases: ["First"], extensions: [".first"], mimetypes: []
        )
        let second = MonaLanguageIdentity(
            id: "mylang", disposition: .hostProvided, hasLoader: false,
            aliases: ["Second"], extensions: [".second"], mimetypes: ["text/x-second"]
        )
        registry.register(first)
        registry.register(second)
        // Re-registering the same id replaces (no duplicate count).
        XCTAssertEqual(registry.hostRegisteredCount, 1)
        XCTAssertEqual(registry.hostRegisteredIdentity(for: "mylang"), second)
    }

    func testLanguageRegistryUnregisterRemovesHostRegistrationOnly() {
        let registry = MonaLanguageRegistry()
        let hostLang = MonaLanguageIdentity(
            id: "mylang", disposition: .hostProvided, hasLoader: false,
            aliases: ["My Language"], extensions: [".myl"], mimetypes: []
        )
        registry.register(hostLang)
        XCTAssertTrue(registry.contains("mylang"))
        registry.unregister("mylang")
        XCTAssertFalse(registry.contains("mylang"))
        XCTAssertEqual(registry.hostRegisteredCount, 0)
        // Unregistering a frozen identity is a no-op (plaintext stays live).
        registry.unregister("plaintext")
        XCTAssertTrue(registry.contains("plaintext"))
    }

    // MARK: - 4. Plain-text fallback when no language registered

    func testLanguageRegistryResolvesUnknownLanguageToPlainTextFallback() {
        let registry = MonaLanguageRegistry()
        // No host registration for "unknown" → plain-text fallback.
        let resolved = registry.resolveLanguage(for: "unknown")
        XCTAssertEqual(resolved.id, "plaintext")
        XCTAssertEqual(resolved.disposition, .coreFallbackMetadata)
        XCTAssertEqual(resolved, registry.fallbackIdentity)
    }

    func testLanguageRegistryResolvesCutBuiltInToPlainTextFallback() {
        let registry = MonaLanguageRegistry()
        // A cut built-in (python) is NOT live and has no host registration →
        // plain-text fallback (no grammar/provider bundled).
        let resolved = registry.resolveLanguage(for: "python")
        XCTAssertEqual(resolved.id, "plaintext")
        XCTAssertEqual(resolved, registry.fallbackIdentity)
    }

    func testLanguageRegistryResolvesPlainTextToItself() {
        let registry = MonaLanguageRegistry()
        let resolved = registry.resolveLanguage(for: "plaintext")
        XCTAssertEqual(resolved.id, "plaintext")
        XCTAssertEqual(resolved.disposition, .coreFallbackMetadata)
    }

    func testLanguageRegistryResolvesHostRegisteredLanguageToHostMetadata() {
        let registry = MonaLanguageRegistry()
        let hostLang = MonaLanguageIdentity(
            id: "python", disposition: .hostProvided, hasLoader: true,
            aliases: ["Python (host)"], extensions: [".py"], mimetypes: ["text/x-python"]
        )
        registry.register(hostLang)
        // Host registration takes precedence over the cut built-in record.
        let resolved = registry.resolveLanguage(for: "python")
        XCTAssertEqual(resolved, hostLang)
        XCTAssertEqual(resolved.disposition, .hostProvided)
    }

    func testLanguageRegistryPlainTextFallbackBehaviorHasNoTokenizationOrGrammar() {
        let registry = MonaLanguageRegistry()
        let plainText = registry.plainTextFallback()
        XCTAssertEqual(plainText.id, "plaintext")
        XCTAssertEqual(plainText.aliases, ["Plain Text", "text"])
        XCTAssertEqual(plainText.extensions, [".txt"])
        XCTAssertEqual(plainText.mimetypes, ["text/plain"])
        // Plain-text fallback behavior: no tokenization, no grammar, no provider.
        XCTAssertFalse(plainText.hasTokenization)
        XCTAssertFalse(plainText.hasGrammar)
        XCTAssertFalse(plainText.hasProvider)
    }

    // MARK: - 5. Disposal is idempotent

    func testLanguageRegistryDisposalIsIdempotent() {
        let registry = MonaLanguageRegistry()
        XCTAssertFalse(registry.isDisposed)
        registry.dispose()
        XCTAssertTrue(registry.isDisposed)
        // Repeated disposal is a no-op.
        registry.dispose()
        registry.dispose()
        XCTAssertTrue(registry.isDisposed)
        // Frozen identity inventory is still queryable (immutable).
        XCTAssertEqual(registry.totalCount, 91)
        XCTAssertEqual(registry.liveCount, 1)
        XCTAssertEqual(registry.cutCount, 90)
        // Resolution still returns the plain-text fallback after disposal.
        XCTAssertEqual(registry.resolveLanguage(for: "unknown").id, "plaintext")
    }

    func testLanguageRegistryRefusesHostRegistrationAfterDisposal() {
        let registry = MonaLanguageRegistry()
        registry.dispose()
        let hostLang = MonaLanguageIdentity(
            id: "postdisposal", disposition: .hostProvided, hasLoader: false,
            aliases: ["Post Disposal"], extensions: [".pd"], mimetypes: []
        )
        registry.register(hostLang)
        // Registration is refused after disposal.
        XCTAssertEqual(registry.hostRegisteredCount, 0)
        XCTAssertNil(registry.hostRegisteredIdentity(for: "postdisposal"))
        XCTAssertFalse(registry.contains("postdisposal"))
    }

    // MARK: - Contract leaf

    func testLanguageRegistryContractLeaf() {
        let registry = MonaLanguageRegistry()

        let total = registry.totalCount
        let retained = registry.liveCount
        let cut = registry.cutCount
        let hostRegistered = registry.hostRegisteredCount
        let fallbackId = registry.fallbackIdentity.id

        // Excluded: every cut built-in is NOT a live registration.
        let excludedPass =
            !registry.contains("python") &&
            !registry.contains("javascript") &&
            !registry.contains("typescript") &&
            !registry.contains("json") &&
            !registry.contains("swift")

        // Fallback behavior: unknown + cut built-in both resolve to plaintext.
        let fallbackBehaviorPass =
            registry.resolveLanguage(for: "unknown").id == "plaintext" &&
            registry.resolveLanguage(for: "python").id == "plaintext" &&
            registry.plainTextFallback().hasTokenization == false

        // Idempotent disposal.
        let registry2 = MonaLanguageRegistry()
        registry2.dispose()
        registry2.dispose()
        let idempotentPass = registry2.isDisposed && registry2.totalCount == 91

        print("LANGUAGES total=\(total) retained=\(retained) cut=\(cut) fallback=\(fallbackId) hostRegistered=\(hostRegistered) excluded=\(excludedPass ? "pass" : "fail") fallbackBehavior=\(fallbackBehaviorPass ? "pass" : "fail") idempotent=\(idempotentPass ? "pass" : "fail")")

        XCTAssertEqual(total, 91)
        XCTAssertEqual(retained, 1)
        XCTAssertEqual(cut, 90)
        XCTAssertEqual(fallbackId, "plaintext")
        XCTAssertTrue(excludedPass)
        XCTAssertTrue(fallbackBehaviorPass)
        XCTAssertTrue(idempotentPass)
    }
}
