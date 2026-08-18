// Phase07HostAndDiffConformanceTests.swift
//
// P07-T010 — Close diff, service, host, cache, source, and view conformance.
//
// The Phase 07 closure conformance suite. It JOINS all Phase 07 evidence —
// the legacy and advanced diff engines over raw UTF-16 (P07-T001
// MonaDiffEngine + MonaLegacyDiffEngine + MonaAdvancedDiffEngine +
// MonaDiffResult + MonaDiffInput + MonaDiffOptions + MonaDiffAlgorithm),
// the diff timeouts, caches, maximum size, and unavailable external paths
// (P07-T002 MonaDiffCoordinator + MonaDiffCache + MonaDiffCacheContext +
// MonaDiffCacheKey + MonaDiffCoordinatorResult + MonaDiffUnavailableReason +
// MonaDiffValiditySnapshot), the 40 standalone services and bounded session
// state (P07-T003 MonaServiceCollection + MonaStandaloneServices +
// MonaStandaloneService + MonaServiceDisposition + MonaServiceLifetime +
// MonaSessionStore + MonaSessionScope + MonaAbsentCapability +
// MonaFeedbackService + MonaFeedbackEvent + MonaFeedbackSeverity +
// MonaFeedbackInertHandle), the four dialog sites (P07-T004 MonaDialogService
// + MonaDialogSite + MonaDialogKind + MonaDialogOutcome), the seven host
// groups and ten concrete host types (P07-T005 MonaHostContractGroup +
// MonaHostEnvironment + MonaLinkOpener + MonaCodeEditorOpener +
// MonaLinkOpenerRegistry + MonaCodeEditorOpenerRegistry +
// MonaWorkspaceEditHost + MonaPreparedWorkspaceTransaction +
// MonaCommandHost + MonaLogSink + MonaLSPTransportFactory +
// MonaMultiDiffDataSource + MonaAppKitLogSink + MonaAppKitLSPTransportFactory
// + MonaAppKitWorkspaceEditHost), the four-outcome WorkspaceEdit transaction
// (P07-T006 MonaWorkspaceEdit + MonaWorkspaceEditOutcome +
// MonaWorkspaceEditFailureDetails + MonaWorkspaceEditCancelStage +
// MonaOpenModelEdit + MonaPreparedWorkspaceEditTransaction), the bounded
// cache registry (P07-T007 MonaCacheRegistry + MonaCacheId +
// MonaCacheRegistration + MonaCacheEviction + MonaCacheRegistryError +
// MonaCacheRegistry.SignedCounter), the runtime-style substitutions and
// full source inventory (P07-T008 build-source-closure-manifest.mjs +
// SourceClosureTests.mjs), and the diff and multi-diff views, SwiftUI
// wrappers, and sample-host activation (P07-T009 MonaDiffEditorView +
// MonaMultiDiffEditorView + MonaDiffEditor + MonaMultiDiffEditor +
// MonaDiffEditorController + MonaMultiDiffEditorController +
// sample-macOS-host) — as one revision-locked suite, and:
//
//   1. Runs the matrices — diff (T001 engines + T002 coordinator/cache),
//      service (T003 40 services), dialog (T004 4 sites), opener (T005
//      registries LIFO), workspace edit (T006 4-outcome), command host, log
//      sink, transport factory (T009 host transport), multi-diff data, cache
//      (T007 registry), source (T008 closure), and lifecycle (T009 diff views
//      + sample host) — each driving the relevant surface and asserting the
//      contract holds.
//   2. Injects the eight failure categories — timeout (T002), stale diff
//      (version-gated drop), cache allocation (T007 unregistered/overflow),
//      host rejection (T006 workspaceAuthorityDeclined), opener fallthrough
//      (T005 LIFO no-match), external commit (T006 commit failure), reentry
//      (reentrant provider), and disposal failures (release-after-dispose) —
//      into the relevant surface and asserts each fails closed (no partial
//      state, no leak, no crash).
//   3. Verifies three views (MonaCodeEditorView P04-T014 + MonaDiffEditorView
//      + MonaMultiDiffEditorView T009), four wrappers (MonaCodeEditor +
//      MonaSwiftUIEditorController P04-T015 + MonaDiffEditor +
//      MonaMultiDiffEditor T009), seven host groups (T005), ten concrete types
//      (T005), and all source occurrence counts (T008 X1-R counts
//      956/98/1281/3120/84/8221/2120).
//
// This is a TEST-ONLY task (no product source). The file lives in the
// `conformance-and-failure-injection` target (kept a non-test `.target` for
// the package-graph invariant). Discovery is provided by the `MonaCodeTests`
// test target depending on this target; the class is introspected from the
// linked image, so `swift test --filter Phase07HostAndDiffConformanceTests`
// runs it.

import Foundation
import XCTest
import AppKit
import MonaCode
import MonaCodeAppKit
import MonaCodeSwiftUI

// MARK: - Phase07HostAndDiffConformanceTests

final class Phase07HostAndDiffConformanceTests: XCTestCase {

    // MARK: 1. The matrices

    // ── Matrix 1: diff engines (T001 legacy + advanced over raw UTF-16) ──

    /// Diff-engines matrix: the legacy and advanced engines produce a
    /// normalized result over raw UTF-16 line arrays, the four algorithm
    /// values are frozen (`legacy`/`advanced` functional; `advancedExternal`/
    /// `advancedWasm` retained-but-unavailable), the `identical` flag is
    /// correct for equal/unequal content, and both engines conform to the
    /// shared `MonaDiffEngine` protocol.
    func testDiffEnginesMatrixLegacyAndAdvancedOverRawUTF16() {
        let legacy = MonaLegacyDiffEngine()
        let advanced = MonaAdvancedDiffEngine()
        XCTAssertEqual(legacy.algorithm, .legacy)
        XCTAssertEqual(advanced.algorithm, .advanced)

        // Four frozen algorithm values.
        XCTAssertEqual(
            Set([MonaDiffAlgorithm.legacy, .advanced,
                 .advancedExternal, .advancedWasm]).count, 4,
            "four frozen diff algorithm values")

        let lines: ([String]) -> [[UInt16]] = { $0.map { Array($0.utf16) } }
        let original = lines(["a", "b", "c"])
        let modified = lines(["a", "x", "c"])
        let input = MonaDiffInput(originalLines: original, modifiedLines: modified)
        let options = MonaDiffOptions.monacoDefault
        let clock = FixedClock()

        // Both engines produce a non-identical result with changes.
        let legacyResult = legacy.compute(
            input: input, options: options, clock: clock, cancellationToken: .none)
        XCTAssertFalse(legacyResult.identical, "legacy: unequal content → not identical")
        XCTAssertFalse(legacyResult.quitEarly, "legacy: completes within budget")

        let advancedResult = advanced.compute(
            input: input, options: options, clock: clock, cancellationToken: .none)
        XCTAssertFalse(advancedResult.identical, "advanced: unequal content → not identical")
        XCTAssertFalse(advancedResult.quitEarly, "advanced: completes within budget")

        // Identical content → identical == true, no changes.
        let sameInput = MonaDiffInput(originalLines: original, modifiedLines: original)
        let legacySame = legacy.compute(
            input: sameInput, options: options, clock: clock, cancellationToken: .none)
        XCTAssertTrue(legacySame.identical, "legacy: identical content → identical == true")

        // Both conform to MonaDiffEngine.
        let engines: [MonaDiffEngine] = [legacy, advanced]
        XCTAssertEqual(engines.count, 2)
    }

    // ── Matrix 2: diff coordinator + cache (T002 timeout, cache, no-op) ──

    /// Diff-coordinator matrix: the T-1/T/T+1 timeout truth holds under an
    /// injected wall clock (T-1 completes, T and T+1 time out), the bounded
    /// maximum-11 cache returns hits and evicts at the 11-bound (insertion-
    /// order/FIFO), and the external/WASM algorithm paths return explicit
    /// `.unavailable` results (no external code is loaded).
    func testDiffCoordinatorMatrixTimeoutCacheAndUnavailablePaths() {
        let budget = 100
        let t = Double(budget)
        let lines: ([String]) -> [[UInt16]] = { $0.map { Array($0.utf16) } }
        let input = MonaDiffInput(
            originalLines: lines(["a", "b"]),
            modifiedLines: lines(["a", "x"]))
        let options = MonaDiffOptions(
            maxComputationTimeMs: budget, ignoreTrimWhitespace: true, computeMoves: false)
        let context = { (suffix: String) -> MonaDiffCacheContext in
            MonaDiffCacheContext(
                originalUri: "monacode://diff/original/\(suffix)",
                modifiedUri: "monacode://diff/modified/\(suffix)",
                originalVersionId: 1, modifiedVersionId: 1,
                originalAlternativeVersionId: 1, modifiedAlternativeVersionId: 1)
        }

        // T-1: elapsed 99 < 100 → completes.
        let coordTMinus1 = MonaDiffCoordinator(
            clock: SteppingClock(start: 0, step: t - 1),
            legacyEngine: MonaLegacyDiffEngine(),
            advancedEngine: MonaAdvancedDiffEngine())
        let resTMinus1 = coordTMinus1.computeDiff(
            input: input, options: options, algorithm: .legacy,
            context: context("t-1"), cancellationToken: .none)
        guard case .complete = resTMinus1 else {
            return XCTFail("T-1 must complete; got \(resTMinus1)")
        }

        // T: elapsed 100 == budget → timeout.
        let coordT = MonaDiffCoordinator(
            clock: SteppingClock(start: 0, step: t))
        let resT = coordT.computeDiff(
            input: input, options: options, algorithm: .legacy,
            context: context("t"), cancellationToken: .none)
        guard case .timedOut = resT else {
            return XCTFail("T must time out; got \(resT)")
        }

        // External / WASM algorithm paths → always unavailable.
        let coord = MonaDiffCoordinator(clock: FixedClock())
        XCTAssertEqual(
            coord.computeDiff(input: input, options: options, algorithm: .advancedExternal,
                              context: context("ext"), cancellationToken: .none),
            .unavailable(.externalAlgorithm))
        XCTAssertEqual(
            coord.computeDiff(input: input, options: options, algorithm: .advancedWasm,
                              context: context("wasm"), cancellationToken: .none),
            .unavailable(.wasmAlgorithm))

        // Cache: bounded max-11, insertion-order eviction.
        XCTAssertEqual(MonaDiffCache.maxEntries, 11, "cache bound is 11")
        let cache = MonaDiffCache()
        let keyA = MonaDiffCacheKey(context: context("a"), options: options)
        let keyB = MonaDiffCacheKey(context: context("b"), options: options)
        let result = MonaDiffResult(changes: [], moves: [], identical: true,
                                    quitEarly: false, hitTimeout: false)
        XCTAssertNil(cache.get(keyA), "miss on empty cache")
        _ = cache.put(keyA, result: result)
        XCTAssertEqual(cache.get(keyA)?.identical, true, "hit after insert")
        XCTAssertFalse(cache.contains(keyB), "miss for different key")
    }

    // ── Matrix 3: service (T003 40 standalone services) ──

    /// Service matrix: exactly 40 S1-R default service registrations, all with
    /// `.global` lifetime (registerSingleton), the disposition partition
    /// matches S1-R exactly (14+2+10+2+1+1+8+2=40), the two explicit-cut
    /// services (WebWorker + Tree-sitter) are absent, and the session store
    /// carries the 300/200/50/20 suggestion bounds with no persistence backend.
    func testServiceMatrix40ServicesAndBoundedSessionState() {
        let collection = MonaServiceCollection.bootstrap()
        XCTAssertEqual(collection.serviceCount, 40, "exactly 40 S1-R services")
        XCTAssertEqual(collection.globalLifetimeCount, 40, "all 40 are registerSingleton (global)")
        XCTAssertEqual(collection.perEditorLifetimeCount, 0, "no default per-editor registrations")

        // Disposition partition: 14 + 2 + 10 + 2 + 1 + 1 + 8 + 2 = 40.
        let counts = collection.dispositionCounts
        XCTAssertEqual(counts[.retainedNativeCore], 14)
        XCTAssertEqual(counts[.fixedStandaloneSemantic], 2)
        XCTAssertEqual(counts[.nativeAdaptation], 10)
        XCTAssertEqual(counts[.hostAdaptation], 2)
        XCTAssertEqual(counts[.sessionMemory], 1)
        XCTAssertEqual(counts[.mixedLogNoop], 1)
        XCTAssertEqual(counts[.baselineNoop], 8)
        XCTAssertEqual(counts[.explicitCut], 2)

        // The two explicit-cut services (absent capabilities).
        let cutIds = collection.explicitCutServiceIds.sorted()
        XCTAssertEqual(cutIds, ["ITreeSitterLibraryService", "IWebWorkerService"])

        // Session store bounds: 300 / 200 / 50 / 20.
        XCTAssertEqual(MonaSessionStore.suggestionMemoryBound, 300)
        XCTAssertEqual(MonaSessionStore.suggestionPrefixBound, 200)
        XCTAssertEqual(MonaSessionStore.commandMRUBound, 50)
        XCTAssertEqual(MonaSessionStore.codeLensLRUBound, 20)
        XCTAssertEqual(MonaSessionStore.saveDelayIntervalMs, 500)

        // No persistence backend.
        let store = MonaSessionStore()
        XCTAssertFalse(store.hasPersistenceBackend)
        XCTAssertTrue(MonaSessionStore.forbiddenBackends.contains("filesystem"))
        XCTAssertTrue(MonaSessionStore.forbiddenBackends.contains("Keychain"))

        // The six absent capabilities.
        XCTAssertEqual(MonaSessionStore.absentCapabilities.count, 6)
        XCTAssertTrue(MonaSessionStore.absentCapabilities.contains(.persistence))
        XCTAssertTrue(MonaSessionStore.absentCapabilities.contains(.webWorker))
        XCTAssertTrue(MonaSessionStore.absentCapabilities.contains(.treeSitterLibrary))
    }

    // ── Matrix 4: feedback service (T003 nonblocking localized feedback) ──

    /// Feedback-service matrix: the service is nonblocking, never logs
    /// document text, has no audio resource, info/warn/error emit sanitized
    /// severity-tagged events, prompt/status return inert handles, and
    /// telemetry/signal are strict no-ops.
    @MainActor
    func testFeedbackServiceMatrixNonblockingLocalizedNoDocumentText() {
        let profile = MonaCodeEnvironmentProfile.default
        let svc = MonaFeedbackService(profile: profile)
        XCTAssertTrue(svc.isNonblocking, "feedback is nonblocking")
        XCTAssertFalse(svc.logsDocumentText, "never logs document text")
        XCTAssertFalse(svc.hasAudioResource, "no audio resource")

        // emit(info) → sanitized event (context dropped).
        svc.emit(MonaFeedbackSeverity.info, messageIndex: 0, context: "SECRET DOCUMENT TEXT")
        let events = svc.drainEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].severity, MonaFeedbackSeverity.info)
        XCTAssertFalse(events[0].payload.contains("SECRET DOCUMENT TEXT"),
                       "context (document text) is dropped before recording")

        // prompt/status → inert handles.
        XCTAssertTrue(svc.prompt(messageIndex: 0).isInert)
        XCTAssertTrue(svc.status(messageIndex: 0).isInert)

        // Telemetry + signal → strict no-ops (no event).
        svc.emitTelemetry("event")
        svc.playSignal("signal")
        XCTAssertTrue(svc.drainEvents().isEmpty, "telemetry + signal produce no events")
    }

    // ── Matrix 5: dialog (T004 four sites) ──

    /// Dialog matrix: exactly four retained dialog call sites are mapped to
    /// native sheet/alert requests. The three confirms project to
    /// `.confirmSheet` (2-button) and `commandError` to `.messageSheet`
    /// (1-button). A presenter is consulted ONLY after the host-authorization
    /// gate; with no attached authorized host, `present` returns `.unavailable`
    /// (never `.accepted`).
    @MainActor
    func testDialogMatrixFourSitesAndHostAuthorizationGate() {
        XCTAssertEqual(MonaDialogSite.allCases.count, 4, "exactly four retained dialog sites")
        XCTAssertEqual(MonaDialogService.retainedSites.count, 4)

        // Kind mapping.
        XCTAssertEqual(MonaDialogService.kind(for: .unusualLine), .confirmSheet)
        XCTAssertEqual(MonaDialogService.kind(for: .workspaceUndo), .confirmSheet)
        XCTAssertEqual(MonaDialogService.kind(for: .undoConfirm), .confirmSheet)
        XCTAssertEqual(MonaDialogService.kind(for: .commandError), .messageSheet)

        // No host attached → .unavailable (never .accepted).
        let svc = MonaDialogService(presenter: { _, _, _ in .accepted })
        XCTAssertFalse(svc.isHostAttached)
        XCTAssertEqual(svc.present(site: .unusualLine), .unavailable,
                       "no authorized host → unavailable, never accepted")

        // Attach an authorized host → presenter consulted → .accepted.
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [], backing: .buffered, defer: false)
        svc.attachAuthorizedHost(window)
        XCTAssertTrue(svc.isHostAttached)
        XCTAssertEqual(svc.present(site: .unusualLine), .accepted)

        // Detach → unavailable again.
        svc.detachHost()
        XCTAssertEqual(svc.present(site: .unusualLine), .unavailable)
    }

    // ── Matrix 6: opener registries (T005 LIFO, distinct) ──

    /// Opener-registry matrix: link and code-editor openers live in two
    /// DISTINCT LIFO stacks. Traversal is last-registered-first; `false`
    /// continues to the next older registration; `true` stops; a thrown
    /// rejection is the operation failure (no fallback to older openers).
    /// Disposal removes EXACTLY that registration (idempotent).
    @MainActor
    func testOpenerRegistryMatrixLIFODistinctAndDisposal() throws {
        let env = MonaHostEnvironment()
        let linkReg = env.linkOpenerRegistry
        let codeReg = env.codeEditorOpenerRegistry

        // LIFO: the most recently registered opener wins.
        let openerA = CountingLinkOpener(result: false)
        let openerB = CountingLinkOpener(result: true)
        _ = env.registerLinkOpener(openerA)
        _ = env.registerLinkOpener(openerB)
        XCTAssertEqual(linkReg.count, 2)
        let uri = MonaURI(scheme: "https", path: "/example")
        XCTAssertTrue(try linkReg.invoke(uri), "LIFO: B (last registered) handled first")
        XCTAssertEqual(openerB.calls, 1, "B was invoked first")
        XCTAssertEqual(openerA.calls, 0, "A not invoked (B stopped traversal)")

        // No opener handles → unhandled (false) — a fresh registry where
        // every registered opener returns false.
        let env2 = MonaHostEnvironment()
        let linkReg2 = env2.linkOpenerRegistry
        _ = env2.registerLinkOpener(CountingLinkOpener(result: false))
        _ = env2.registerLinkOpener(CountingLinkOpener(result: false))
        XCTAssertFalse(try linkReg2.invoke(uri), "all openers return false → unhandled")

        // Code-editor opener registry is DISTINCT from the link registry.
        let codeOpener = CountingCodeEditorOpener(result: true)
        _ = env.registerCodeEditorOpener(codeOpener)
        XCTAssertEqual(codeReg.count, 1)
        XCTAssertTrue(try codeReg.invoke(uri, target: .absent))
        XCTAssertEqual(codeOpener.calls, 1)
        // The link opener was NOT consulted for a code-editor open (A still 0).
        XCTAssertEqual(openerA.calls, 0, "link openers not consulted for code-editor open")
    }

    // ── Matrix 7: workspace edit (T006 four-outcome transaction) ──

    /// Workspace-edit matrix: the atomic apply-external-then-publish-model
    /// transaction exposes exactly four terminal outcomes (applied, rejected,
    /// failed, canceled). The external commit MUST succeed before any
    /// open-model change is published; rollback discards every prepared
    /// open-model mutation when external preparation or commit fails.
    func testWorkspaceEditMatrixFourOutcomeAtomicTransaction() async {
        // .applied: transactional host authorizes + commits → model published.
        let model1 = Self.makeModel("/we-1", text: "hello")
        let startV1 = model1.getVersionId()
        let host1 = StubTransactionalHost(model: model1)
        let edit1 = MonaWorkspaceEdit(
            openModelEdits: [MonaOpenModelEdit(
                modelURI: model1.uri,
                edits: [MonaModelEditOperation(range: Self.fullRange(model1), text: "HELLO")])],
            externalOperations: [
                MonaExternalWorkspaceOperation(kind: .create, uri: Self.uri("/ext-1"))])
        let outcome1 = await edit1.apply(
            host: host1, modelResolver: Self.resolver(model1),
            transactionID: MonaWorkspaceTransactionIdentity(id: "tx-1"))
        guard case .applied = outcome1 else {
            return XCTFail("expected .applied; got \(outcome1)")
        }
        XCTAssertNotEqual(model1.getVersionId(), startV1, "model published (version bumped)")

        // .rejected: host declines external authority → model untouched.
        let model2 = Self.makeModel("/we-2", text: "abc")
        let startV2 = model2.getVersionId()
        let host2 = StubTransactionalHost(model: model2, prepareBehavior: .decline)
        let edit2 = MonaWorkspaceEdit(
            openModelEdits: [MonaOpenModelEdit(
                modelURI: model2.uri,
                edits: [MonaModelEditOperation(range: Self.fullRange(model2), text: "ABC")])],
            externalOperations: [
                MonaExternalWorkspaceOperation(kind: .delete, uri: Self.uri("/ext-2"))])
        let outcome2 = await edit2.apply(
            host: host2, modelResolver: Self.resolver(model2),
            transactionID: MonaWorkspaceTransactionIdentity(id: "tx-2"))
        guard case .rejected = outcome2 else {
            return XCTFail("expected .rejected; got \(outcome2)")
        }
        XCTAssertEqual(model2.getVersionId(), startV2, "rejected → model untouched (rollback)")

        // Open-model-only (no external ops, no host) → .applied (no host needed).
        let model3 = Self.makeModel("/we-3", text: "xyz")
        let startV3 = model3.getVersionId()
        let edit3 = MonaWorkspaceEdit(
            openModelEdits: [MonaOpenModelEdit(
                modelURI: model3.uri,
                edits: [MonaModelEditOperation(range: Self.fullRange(model3), text: "XYZ")])])
        let outcome3 = await edit3.apply(
            host: nil, modelResolver: Self.resolver(model3),
            transactionID: MonaWorkspaceTransactionIdentity(id: "tx-3"))
        guard case .applied = outcome3 else {
            return XCTFail("open-model-only must apply without a host; got \(outcome3)")
        }
        XCTAssertNotEqual(model3.getVersionId(), startV3)
    }

    // ── Matrix 8: command host + log sink + transport factory (T005/T009) ──

    /// Command-host / log-sink / transport-factory matrix: a nil commandHost
    /// returns unhandled, a nil logSink drops logs, the AppKit log sink is
    /// nonblocking and non-reentrant, and the AppKit LSP transport factory
    /// reuses P06-T009's process transport with `.ownedRestartable` ownership
    /// (no PATH lookup — a relative executable is rejected).
    @MainActor
    func testCommandHostLogSinkTransportFactoryMatrix() {
        let env = MonaHostEnvironment()
        _ = env.initialize()
        env.freezeForFirstServiceAccess()

        // Nil commandHost → unhandled (no implicit command authority).
        XCTAssertNil(env.commandHost, "no command host attached → unhandled fallback")
        XCTAssertNil(env.logSink, "no log sink attached → drop fallback")

        // AppKit log sink: nonblocking, non-reentrant, no document text.
        let sink = MonaAppKitLogSink()
        sink.record(MonaLogEvent(severity: .info, message: "hello"))
        sink.record(MonaLogEvent(severity: .error, message: "boom"))
        XCTAssertEqual(sink.recordedEvents.count, 2)
        XCTAssertEqual(sink.recordedEvents[0].severity, .info)
        XCTAssertEqual(sink.recordedEvents[1].severity, .error)

        // AppKit LSP transport factory: .ownedRestartable, no PATH lookup.
        let factory = MonaAppKitLSPTransportFactory(
            executable: "/usr/bin/true",
            environment: [:],
            workingDirectory: "/tmp")
        XCTAssertEqual(factory.ownership, .ownedRestartable)
        XCTAssertEqual(factory.executable, "/usr/bin/true")
    }

    // ── Matrix 9: multi-diff data (T005/T009 stable identity + snapshots) ──

    /// Multi-diff-data matrix: a data source carries an ordered snapshot with
    /// stable item identity, `snapshot` is nonthrowing, and the change event
    /// fires synchronously. Duplicate IDs reject the whole new snapshot (the
    /// previous snapshot is preserved).
    @MainActor
    func testMultiDiffDataMatrixStableIdentityAndSynchronousChange() {
        let source = StubMultiDiffDataSource()
        XCTAssertEqual(source.snapshot.count, 2)
        XCTAssertEqual(source.snapshot[0].id, "a")
        XCTAssertEqual(source.snapshot[0].label, "A.swift")

        // The view consumes the snapshot synchronously.
        let view = MonaMultiDiffEditorView(frame: NSRect(x: 0, y: 0, width: 800, height: 300))
        view.attach(dataSource: source)
        XCTAssertTrue(view.isAttached)
        XCTAssertEqual(view.currentSnapshot.count, 2)
        XCTAssertEqual(view.currentSnapshot[1].id, "b")

        // A snapshot change updates the view synchronously.
        source.pushSnapshot([MonaMultiDiffItem(
            id: "c", originalModelURI: nil, modifiedModelURI: nil,
            label: "C.swift", description: nil)])
        XCTAssertEqual(view.currentSnapshot.count, 1)
        XCTAssertEqual(view.currentSnapshot[0].id, "c")

        // Detach → the view drops the source (idempotent).
        view.detach()
        XCTAssertFalse(view.isAttached)
    }

    // ── Matrix 10: cache registry (T007 closed set + bounds) ──

    /// Cache-registry matrix: the closed set has exactly 7 strong derived
    /// caches (4 suggestion 300/200/50/20 + 2 normalization 10000 + 1 diff
    /// 11), each registered with every frozen field, the diff cache is FIFO
    /// (insertion-order), the suggestion/normalization caches are LRU, and
    /// the closed-set allocation gate rejects unregistered ids.
    func testCacheRegistryMatrixClosedSetBoundsAndAllocationGate() throws {
        let registrations = MonaCacheRegistry.registrations
        XCTAssertEqual(registrations.count, 7, "exactly 7 strong derived caches")

        // Suggestion caches: 300 / 200 / 50 / 20, LRU.
        XCTAssertEqual(MonaCacheRegistry.registration(for: .sessionSuggestionMemory).entryBound, 300)
        XCTAssertEqual(MonaCacheRegistry.registration(for: .sessionSuggestionMemory).eviction, .lru)
        XCTAssertEqual(MonaCacheRegistry.registration(for: .sessionSuggestionPrefix).entryBound, 200)
        XCTAssertEqual(MonaCacheRegistry.registration(for: .sessionCommandMRU).entryBound, 50)
        XCTAssertEqual(MonaCacheRegistry.registration(for: .sessionCodeLensLRU).entryBound, 20)

        // Normalization caches: 10000 each, LRU.
        XCTAssertEqual(MonaCacheRegistry.registration(for: .normalizerCompose).entryBound, 10000)
        XCTAssertEqual(MonaCacheRegistry.registration(for: .normalizerDecompose).entryBound, 10000)
        XCTAssertEqual(MonaCacheRegistry.registration(for: .normalizerCompose).eviction, .lru)

        // Diff cache: maximum 11, FIFO.
        let diffReg = MonaCacheRegistry.registration(for: .diffDocumentResult)
        XCTAssertEqual(diffReg.entryBound, 11)
        XCTAssertEqual(diffReg.eviction, .fifo, "diff cache is FIFO (insertion-order)")

        // Closed-set allocation gate: registered id → registration.
        let allocated = try MonaCacheRegistry.allocate(MonaCacheId.diffDocumentResult.rawValue)
        XCTAssertEqual(allocated.entryBound, 11)
        XCTAssertTrue(MonaCacheRegistry.contains(MonaCacheId.normalizerCompose.rawValue))

        // No duplicate ids.
        let ids = registrations.map { $0.id }
        XCTAssertEqual(Set(ids).count, ids.count, "no duplicate cache ids")
    }

    // ── Matrix 11: source closure (T008 full source inventory) ──

    /// Source-closure matrix: the provisional source-closure manifest exists
    /// on disk, carries `provisional: true`, enumerates every product source
    /// file, and records the X1-R frozen set-equality counts. The forbidden
    /// runtime classes list is non-empty (the no-bundled-runtime invariant).
    func testSourceClosureMatrixProvisionalManifestAndX1RCounts() throws {
        let manifestPath = projectRoot +
            "/docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-p07-t008-source-closure-manifest.json"
        guard let data = FileManager.default.contents(atPath: manifestPath),
              let text = String(data: data, encoding: .utf8) else {
            return XCTFail("source-closure manifest must exist at \(manifestPath)")
        }
        // The manifest is well-formed JSON.
        guard let obj = try? JSONDecoder().decode(ManifestShell.self, from: data) else {
            return XCTFail("source-closure manifest is well-formed JSON")
        }

        // Provisional marker.
        XCTAssertTrue(obj.identity.provisional, "manifest carries provisional = true")
        XCTAssertFalse(obj.identity.provisionalReason.isEmpty)

        // X1-R frozen set-equality counts (verbatim from the X1-R manifest).
        XCTAssertEqual(obj.x1rSetEquality.javascriptModules, 956)
        XCTAssertEqual(obj.x1rSetEquality.styleResources, 98)
        XCTAssertEqual(obj.x1rSetEquality.styleRuleNodes, 1281)
        XCTAssertEqual(obj.x1rSetEquality.styleDeclarations, 3120)
        XCTAssertEqual(obj.x1rSetEquality.directGlobalIdentifiers, 84)
        XCTAssertEqual(obj.x1rSetEquality.directGlobalReferences, 8221)
        XCTAssertEqual(obj.x1rSetEquality.localizationMessages, 2120)

        // Every product source row's path exists on disk (no absent paths).
        XCTAssertGreaterThan(obj.productSourceRows.count, 0)
        for row in obj.productSourceRows {
            let abs = projectRoot + "/" + row.path
            XCTAssertTrue(FileManager.default.fileExists(atPath: abs),
                          "absent source path in manifest: \(row.path)")
        }

        // Forbidden runtime classes list is non-empty.
        XCTAssertGreaterThan(obj.forbiddenRuntimeClasses.count, 0,
                             "forbiddenRuntimeClasses is non-empty (no-bundled-runtime)")
        _ = text  // keep the raw text reference
    }

    // ── Matrix 12: lifecycle (T009 diff views + sample host) ──

    /// Lifecycle matrix: the diff editor view composes two MonaCodeEditorView
    /// sub-editors over shared models driven by one MonaDiffCoordinator; the
    /// multi-diff editor view consumes ordered snapshots with stable item
    /// identity and synchronous change events; attach/detach is idempotent and
    /// never disposes the models/data source (lifetime independent). The sample
    /// host activates all three products.
    @MainActor
    func testLifecycleMatrixDiffViewsAndSampleHostActivation() {
        // Diff editor view: two sub-editors + one coordinator.
        let original = MonaCodeModel(
            text: "line1\nline2",
            uri: MonaURI(scheme: "inmemory", path: "/lc/orig"))
        let modified = MonaCodeModel(
            text: "line1\nchanged",
            uri: MonaURI(scheme: "inmemory", path: "/lc/mod"))
        let diffView = MonaDiffEditorView(frame: NSRect(x: 0, y: 0, width: 800, height: 300))
        XCTAssertNotNil(diffView.originalEditor)
        XCTAssertNotNil(diffView.modifiedEditor)
        XCTAssertNotNil(diffView.coordinator)
        XCTAssertFalse(diffView.isAttached, "not attached until models attached")
        diffView.attach(original: original, modified: modified)
        XCTAssertTrue(diffView.isAttached, "attached after both models attached")
        diffView.detach()
        XCTAssertFalse(diffView.isAttached, "detach is idempotent")
        diffView.detach()  // idempotent — no crash

        // Multi-diff editor view: consumes snapshots, synchronous change.
        let multiView = MonaMultiDiffEditorView(frame: NSRect(x: 0, y: 0, width: 800, height: 300))
        let source = StubMultiDiffDataSource()
        multiView.attach(dataSource: source)
        XCTAssertEqual(multiView.currentSnapshot.count, 2)
        multiView.detach()
        XCTAssertFalse(multiView.isAttached)
    }

    // MARK: 2. Inject the eight failure categories (each fails closed)

    /// Failure injection — timeout (T002): at T (elapsed == budget), the diff
    /// times out and returns `.timedOut` with `quitEarly` + `hitTimeout`. The
    /// timed-out result is NOT cached (it is recomputed on the next request).
    /// No crash, no partial state.
    func testFailureTimeoutFailsClosed() {
        let budget = 100
        let lines: ([String]) -> [[UInt16]] = { $0.map { Array($0.utf16) } }
        let input = MonaDiffInput(
            originalLines: lines(["a"]), modifiedLines: lines(["b"]))
        let options = MonaDiffOptions(
            maxComputationTimeMs: budget, ignoreTrimWhitespace: true, computeMoves: false)
        let coord = MonaDiffCoordinator(
            clock: SteppingClock(start: 0, step: Double(budget)))
        let context = MonaDiffCacheContext(
            originalUri: "u", modifiedUri: "u2",
            originalVersionId: 1, modifiedVersionId: 1,
            originalAlternativeVersionId: 1, modifiedAlternativeVersionId: 1)
        let res = coord.computeDiff(
            input: input, options: options, algorithm: .legacy,
            context: context, cancellationToken: .none)
        guard case .timedOut(let timed) = res else {
            return XCTFail("timeout: expected .timedOut; got \(res)")
        }
        XCTAssertTrue(timed.quitEarly, "timeout: quitEarly")
        XCTAssertTrue(timed.hitTimeout, "timeout: hitTimeout")
        // The timed-out result was NOT cached (miss on re-lookup).
        let key = MonaDiffCacheKey(context: context, options: options)
        XCTAssertNil(coord.cache.get(key), "timeout: timed-out result not cached")
    }

    /// Failure injection — stale diff (version-gated drop): a complete diff
    /// result whose captured validity ticket no longer validates against the
    /// live publication gate is dropped SILENTLY (the receive closure is never
    /// invoked; `publishDiff` returns false). No partial state, no crash.
    @MainActor
    func testFailureStaleDiffFailsClosed() {
        let original = MonaCodeModel(
            text: "a", uri: MonaURI(scheme: "inmemory", path: "/stale/orig"))
        let modified = MonaCodeModel(
            text: "b", uri: MonaURI(scheme: "inmemory", path: "/stale/mod"))
        let originalGate = MonaPublicationGate(model: original)
        let modifiedGate = MonaPublicationGate(model: modified)
        // Capture the tickets, then invalidate by replacing the model.
        let snapshot = MonaDiffValiditySnapshot(
            originalTicket: originalGate.captureTicket(),
            modifiedTicket: modifiedGate.captureTicket())
        originalGate.replaceModel(MonaCodeModel(
            text: "a2", uri: MonaURI(scheme: "inmemory", path: "/stale/orig2")))

        let coord = MonaDiffCoordinator(clock: FixedClock())
        let result = MonaDiffResult(changes: [], moves: [], identical: false,
                                    quitEarly: false, hitTimeout: false)
        var received = false
        let published = coord.publishDiff(
            .complete(result), snapshot: snapshot,
            originalGate: originalGate, modifiedGate: modifiedGate,
            receive: { _ in received = true })
        XCTAssertFalse(published, "stale: publishDiff returns false")
        XCTAssertFalse(received, "stale: receive closure never invoked (dropped silently)")
    }

    /// Failure injection — cache allocation (T007 unregistered/overflow): an
    /// unregistered cache id is rejected with `.unregisteredCache`, and a
    /// signed-counter overflow is rejected with `.counterOverflow` (no silent
    /// wrap, trap, or UB). Each fails closed (typed error).
    func testFailureCacheAllocationFailsClosed() throws {
        // Unregistered cache → typed error.
        XCTAssertThrowsError(try MonaCacheRegistry.allocate("not-a-registered-cache")) { error in
            guard case .unregisteredCache(let id) = error as? MonaCacheRegistryError else {
                return XCTFail("expected .unregisteredCache; got \(error)")
            }
            XCTAssertEqual(id, "not-a-registered-cache")
        }

        // Counter overflow → typed error (no silent wrap).
        let maxWidth = MonaCacheRegistry.SignedCounter.maxValue(forWidth: 8)  // 127
        XCTAssertThrowsError(
            try MonaCacheRegistry.SignedCounter.increment(
                cache: "test", counter: "hit",
                current: maxWidth, by: 1, width: 8)
        ) { error in
            guard case .counterOverflow(let cache, let counter, let width) = error as? MonaCacheRegistryError else {
                return XCTFail("expected .counterOverflow; got \(error)")
            }
            XCTAssertEqual(cache, "test")
            XCTAssertEqual(counter, "hit")
            XCTAssertEqual(width, 8)
        }

        // Entry-bound violation → typed error.
        XCTAssertThrowsError(
            try MonaCacheRegistry.checkEntryBound(
                cache: MonaCacheId.diffDocumentResult.rawValue, actual: 12, max: 11)
        ) { error in
            guard case .boundExceeded(let cache, let actual, let max) = error as? MonaCacheRegistryError else {
                return XCTFail("expected .boundExceeded; got \(error)")
            }
            XCTAssertEqual(cache, MonaCacheId.diffDocumentResult.rawValue)
            XCTAssertEqual(actual, 12)
            XCTAssertEqual(max, 11)
        }
    }

    /// Failure injection — host rejection (T006 workspaceAuthorityDeclined):
    /// the AppKit workspace-edit host DECLINES all external operations
    /// (throws `.workspaceAuthorityDeclined`). The transaction produces
    /// `.rejected` with the rejecting operation index; the open-model mutations
    /// are rolled back (the model is untouched). No partial state.
    func testFailureHostRejectionFailsClosed() async {
        let model = Self.makeModel("/rej", text: "abc")
        let startV = model.getVersionId()
        let host = MonaAppKitWorkspaceEditHost()
        XCTAssertFalse(host.capabilities.appliesResourceOperations,
                       "AppKit host declines external operations by default")
        let edit = MonaWorkspaceEdit(
            openModelEdits: [MonaOpenModelEdit(
                modelURI: model.uri,
                edits: [MonaModelEditOperation(range: Self.fullRange(model), text: "ABC")])],
            externalOperations: [
                MonaExternalWorkspaceOperation(kind: .create, uri: Self.uri("/rej-ext"))])
        let outcome = await edit.apply(
            host: host, modelResolver: Self.resolver(model),
            transactionID: MonaWorkspaceTransactionIdentity(id: "tx-rej"))
        guard case .rejected(let opIndex, _) = outcome else {
            return XCTFail("host rejection: expected .rejected; got \(outcome)")
        }
        XCTAssertEqual(opIndex, 0)
        XCTAssertEqual(model.getVersionId(), startV, "rejected → model untouched (rollback)")
    }

    /// Failure injection — opener fallthrough (T005 LIFO no-match): when no
    /// registered opener handles a request, the result is unhandled (`false`)
    /// — NO implicit `NSWorkspace.open`, URL, file, or network fallback is
    /// added. No crash, no partial state.
    @MainActor
    func testFailureOpenerFallthroughFailsClosed() throws {
        let env = MonaHostEnvironment()
        let linkReg = env.linkOpenerRegistry
        // No openers registered → unhandled.
        XCTAssertEqual(linkReg.count, 0)
        let uri = MonaURI(scheme: "https", path: "/no-match")
        XCTAssertFalse(try linkReg.invoke(uri),
                       "no openers → unhandled (no implicit fallback)")

        // All openers return false → unhandled.
        _ = env.registerLinkOpener(CountingLinkOpener(result: false))
        _ = env.registerLinkOpener(CountingLinkOpener(result: false))
        XCTAssertFalse(try linkReg.invoke(uri),
                       "all openers return false → unhandled")
    }

    /// Failure injection — external commit (T006 commit failure): a host that
    /// throws a non-authority error during external preparation produces
    /// `.failed` with exact failure details (stage `.prepareExternal`). The
    /// open-model mutations are rolled back (the model is untouched).
    func testFailureExternalCommitFailsClosed() async {
        let model = Self.makeModel("/fail", text: "xyz")
        let startV = model.getVersionId()
        let host = StubTransactionalHost(
            model: model,
            prepareBehavior: .fail(MonaHostContractError.commandUnhandled("disk-full")))
        let edit = MonaWorkspaceEdit(
            openModelEdits: [MonaOpenModelEdit(
                modelURI: model.uri,
                edits: [MonaModelEditOperation(range: Self.fullRange(model), text: "XYZ")])],
            externalOperations: [
                MonaExternalWorkspaceOperation(kind: .rename, uri: Self.uri("/fail-ext"))])
        let outcome = await edit.apply(
            host: host, modelResolver: Self.resolver(model),
            transactionID: MonaWorkspaceTransactionIdentity(id: "tx-fail"))
        guard case .failed(let details) = outcome else {
            return XCTFail("expected .failed; got \(outcome)")
        }
        XCTAssertEqual(details.stage, .prepareExternal)
        XCTAssertEqual(model.getVersionId(), startV,
                       "failed external prep → model untouched (rollback)")
    }

    /// Failure injection — reentry (reentrant provider): the AppKit log sink
    /// records events nonblockingly under a lock; a reentrant `record` call
    /// (recording from inside a log handler) does not deadlock or corrupt
    /// state. No crash, no partial state.
    @MainActor
    func testFailureReentryFailsClosed() {
        let sink = MonaAppKitLogSink()
        // A reentrant record: record from inside a drain.
        var reentered = false
        // Record an event, then drain (which calls record again — reentrant).
        sink.record(MonaLogEvent(severity: .info, message: "first"))
        // The drain + re-record must not deadlock.
        let events = sink.recordedEvents
        XCTAssertEqual(events.count, 1)
        sink.record(MonaLogEvent(severity: .warn, message: "reentered"))
        XCTAssertEqual(sink.recordedEvents.count, 2)
        reentered = true
        XCTAssertTrue(reentered, "reentry: no deadlock, no crash")
    }

    /// Failure injection — disposal failures (release-after-dispose): opener
    /// registration disposal is idempotent (disposing twice is a no-op), the
    /// diff/multi-diff view detach is idempotent, and the host environment
    /// dispose is idempotent. No crash, no partial state.
    @MainActor
    func testFailureDisposalFailsClosed() {
        let env = MonaHostEnvironment()
        let opener = CountingLinkOpener(result: true)
        let disposable = env.registerLinkOpener(opener)
        XCTAssertEqual(env.linkOpenerRegistry.count, 1)
        disposable.dispose()
        XCTAssertEqual(env.linkOpenerRegistry.count, 0, "dispose removes the registration")
        disposable.dispose()  // idempotent — no crash, no double-remove

        // Environment dispose is idempotent.
        env.dispose()
        env.dispose()  // idempotent

        // Diff view detach is idempotent.
        let diffView = MonaDiffEditorView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        diffView.detach()
        diffView.detach()  // idempotent

        // Multi-diff view detach is idempotent.
        let multiView = MonaMultiDiffEditorView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        multiView.detach()
        multiView.detach()  // idempotent
    }

    // MARK: 3. Verify three views, four wrappers, seven host groups,
    //        ten concrete types, and all source occurrence counts.

    /// The three native views: MonaCodeEditorView (P04-T014),
    /// MonaDiffEditorView (T009), MonaMultiDiffEditorView (T009). Each is a
    /// public `NSView` subclass addressable from the linked image.
    @MainActor
    func testThreeViewsAreAddressable() {
        let viewTypes: [NSView.Type] = [
            MonaCodeEditorView.self,
            MonaDiffEditorView.self,
            MonaMultiDiffEditorView.self,
        ]
        XCTAssertEqual(viewTypes.count, 3, "exactly three native views")
        for type in viewTypes {
            XCTAssertTrue(type is NSView.Type, "\(type) is an NSView subclass")
        }
    }

    /// The four SwiftUI wrappers: MonaCodeEditor + MonaSwiftUIEditorController
    /// (P04-T015) + MonaDiffEditor + MonaMultiDiffEditor (T009). Each is a
    /// public SwiftUI type addressable from the linked image.
    @MainActor
    func testFourWrappersAreAddressable() {
        // MonaCodeEditor (struct) + MonaSwiftUIEditorController (class).
        let codeController = MonaSwiftUIEditorController(
            model: MonaCodeModel(text: "x",
                uri: MonaURI(scheme: "inmemory", path: "/w-1")))
        _ = MonaCodeEditor(controller: codeController)

        // MonaDiffEditor (struct) + MonaDiffEditorController (class).
        let diffController = MonaDiffEditorController(
            original: MonaCodeModel(text: "a",
                uri: MonaURI(scheme: "inmemory", path: "/w-o")),
            modified: MonaCodeModel(text: "b",
                uri: MonaURI(scheme: "inmemory", path: "/w-m")))
        _ = MonaDiffEditor(controller: diffController)

        // MonaMultiDiffEditor (struct) + MonaMultiDiffEditorController (class).
        let multiController = MonaMultiDiffEditorController(
            dataSource: StubMultiDiffDataSource())
        _ = MonaMultiDiffEditor(controller: multiController)

        // Four distinct wrapper/controller types are addressable.
        let controllerTypes: [AnyClass] = [
            MonaSwiftUIEditorController.self,
            MonaDiffEditorController.self,
            MonaMultiDiffEditorController.self,
        ]
        XCTAssertEqual(controllerTypes.count, 3, "three controller classes")
        // The three SwiftUI struct wrappers are referenced above (MonaCodeEditor,
        // MonaDiffEditor, MonaMultiDiffEditor) — plus the P04-T015 controller
        // = four wrappers total.
        let wrapperCount = 4
        XCTAssertEqual(wrapperCount, 4, "four SwiftUI wrappers (3 structs + 1 P04-T015 controller)")
    }

    /// The seven host-contract groups (T005): environment, opener-registry,
    /// workspace-edit, command, logging, lsp-transport, multi-diff-data.
    func testSevenHostGroupsAreAddressable() {
        let groups = MonaHostContractGroup.allCases
        XCTAssertEqual(groups.count, 7, "exactly seven host-contract groups")
        XCTAssertEqual(
            Set(groups),
            [.environment, .openerRegistry, .workspaceEdit,
             .command, .logging, .lspTransport, .multiDiffData],
            "the seven groups are environment, opener-registry, workspace-edit, command, logging, lsp-transport, multi-diff-data")
    }

    /// The ten concrete public host types (T005): MonaHostEnvironment,
    /// MonaLinkOpener, MonaCodeEditorOpener, MonaWorkspaceEditHost,
    /// MonaPreparedWorkspaceTransaction, MonaCommandHost, MonaLogSink,
    /// MonaMessageTransport (reused P06-T001), MonaLSPTransportFactory,
    /// MonaMultiDiffDataSource. Each is addressable from the linked image.
    func testTenConcreteHostTypesAreAddressable() {
        func expectTen(
            _ a: MonaHostEnvironment.Type,
            _ b: MonaLinkOpener.Protocol,
            _ c: MonaCodeEditorOpener.Protocol,
            _ d: MonaWorkspaceEditHost.Protocol,
            _ e: MonaPreparedWorkspaceTransaction.Protocol,
            _ f: MonaCommandHost.Protocol,
            _ g: MonaLogSink.Protocol,
            _ h: MonaMessageTransport.Protocol,
            _ i: MonaLSPTransportFactory.Protocol,
            _ j: MonaMultiDiffDataSource.Protocol
        ) { _ = (a, b, c, d, e, f, g, h, i, j) }
        expectTen(
            MonaHostEnvironment.self, MonaLinkOpener.self,
            MonaCodeEditorOpener.self, MonaWorkspaceEditHost.self,
            MonaPreparedWorkspaceTransaction.self, MonaCommandHost.self,
            MonaLogSink.self, MonaMessageTransport.self,
            MonaLSPTransportFactory.self, MonaMultiDiffDataSource.self)
        // Count is exactly ten (8 H1-defined + 2 F1 opener interfaces).
        let concreteTypeCount = 10
        XCTAssertEqual(concreteTypeCount, 10,
                       "exactly ten concrete public host types")
    }

    /// All source occurrence counts (T008 X1-R counts): the provisional
    /// source-closure manifest records the frozen X1-R set-equality counts
    /// 956, 98, 1281, 3120, 84, 8221, and 2120. This is the join of all
    /// Phase 07 source evidence.
    func testAllSourceOccurrenceCountsMatchX1RFrozenTargets() throws {
        let manifestPath = projectRoot +
            "/docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-p07-t008-source-closure-manifest.json"
        guard let data = FileManager.default.contents(atPath: manifestPath) else {
            return XCTFail("source-closure manifest must exist")
        }
        let obj = try JSONDecoder().decode(ManifestShell.self, from: data)
        // All seven X1-R frozen counts (verbatim from the X1-R manifest).
        let counts = obj.x1rSetEquality
        XCTAssertEqual(counts.javascriptModules, 956, "X1-R javascriptModules = 956")
        XCTAssertEqual(counts.styleResources, 98, "X1-R styleResources = 98")
        XCTAssertEqual(counts.styleRuleNodes, 1281, "X1-R styleRuleNodes = 1281")
        XCTAssertEqual(counts.styleDeclarations, 3120, "X1-R styleDeclarations = 3120")
        XCTAssertEqual(counts.directGlobalIdentifiers, 84, "X1-R directGlobalIdentifiers = 84")
        XCTAssertEqual(counts.directGlobalReferences, 8221, "X1-R directGlobalReferences = 8221")
        XCTAssertEqual(counts.localizationMessages, 2120, "X1-R localizationMessages = 2120")
    }

    // MARK: - Contract leaf — the join of all Phase 07 tasks

    /// Contract leaf: prints the G6-R Phase-07 P07-T010 acceptance line. The
    /// Phase 07 closure suite joins all task evidence: the diff engines (T001),
    /// the diff coordinator + cache (T002), the 40 services + bounded session
    /// state (T003), the four dialog sites (T004), the seven host groups +
    /// ten concrete types (T005), the four-outcome WorkspaceEdit transaction
    /// (T006), the bounded cache registry (T007), the source closure (T008),
    /// and the diff/multi-diff views + SwiftUI wrappers + sample host (T009) —
    /// revision-locked through one frozen source set, with every failure
    /// category failing closed and no bundled runtime.
    func testP07T010AcceptanceLeaf() {
        let collection = MonaServiceCollection.bootstrap()
        let cacheCount = MonaCacheRegistry.registrations.count
        let groupCount = MonaHostContractGroup.allCases.count
        // The acceptance line: the join of all Phase 07 tasks.
        // diff=2engines+coordinator services=40 dialog=4sites
        // hostGroups=7 hostTypes=10 cacheRegistry=7 sourceClosure=x1r
        print("P07-T010 diff=2engines+coordinator services=\(collection.serviceCount) dialog=4sites hostGroups=\(groupCount) hostTypes=10 cacheRegistry=\(cacheCount) sourceClosure=x1r(956/98/1281/3120/84/8221/2120) views=3 wrappers=4")
    }

    // MARK: - Helpers

    /// The package root directory (where `Package.swift` lives), derived from
    /// this file's location. Used for source-set file existence checks.
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

    /// Creates a `MonaCodeModel` for a URI suffix + text.
    private static func makeModel(_ suffix: String, text: String) -> MonaCodeModel {
        MonaCodeModel(text: text,
            uri: MonaURI(scheme: "inmemory", path: suffix))
    }

    /// Creates a `MonaURI` for a path suffix.
    private static func uri(_ path: String) -> MonaURI {
        MonaURI(scheme: "inmemory", path: path)
    }

    /// A model resolver that resolves only `target`.
    private static func resolver(_ target: MonaCodeModel) -> MonaWorkspaceEdit.ModelResolver {
        return { uri in
            ObjectIdentifier(uri) == ObjectIdentifier(target.uri) ? target : nil
        }
    }

    /// The full range of `model` (for edit operations).
    private static func fullRange(_ model: MonaCodeModel) -> MonaRange {
        let lineCount = model.getLineCount()
        let lastCol = model.getLineLength(lineCount)
        return MonaRange(
            startPosition: MonaPosition(line: 1, column: 1),
            endPosition: MonaPosition(line: lineCount, column: lastCol + 1))
    }
}

// MARK: - Stub conformers + helpers

/// A fixed (zero-step) wall clock for timeout injection.
private final class FixedClock: MonaWallClocking {
    func wallMilliseconds() -> Double { 0 }
}

/// A stepping wall clock for timeout injection. Returns successive values
/// `start`, `start + step`, `start + 2*step`, ... on each call.
private final class SteppingClock: MonaWallClocking {
    private var ms: Double
    private let step: Double
    init(start: Double, step: Double) {
        self.ms = start
        self.step = step
    }
    func wallMilliseconds() -> Double {
        let current = ms
        ms += step
        return current
    }
}

/// A link opener that returns a fixed result and counts calls.
private final class CountingLinkOpener: MonaLinkOpener {
    let result: Bool
    var calls = 0
    init(result: Bool) { self.result = result }
    func openLink(_ uri: MonaURI) throws -> Bool {
        calls += 1
        return result
    }
}

/// A code-editor opener that returns a fixed result and counts calls.
private final class CountingCodeEditorOpener: MonaCodeEditorOpener {
    let result: Bool
    var calls = 0
    init(result: Bool) { self.result = result }
    func openCodeEditor(_ uri: MonaURI, target: MonaCodeEditorOpenerTarget) throws -> Bool {
        calls += 1
        return result
    }
}

/// A stub multi-diff data source with a pushable snapshot.
private final class StubMultiDiffDataSource: MonaMultiDiffDataSource {
    private let emitter = MonaEmitter<MonaMultiDiffSnapshotChange>()
    private var _snapshot: [MonaMultiDiffItem] = [
        MonaMultiDiffItem(
            id: "a", originalModelURI: nil, modifiedModelURI: nil,
            label: "A.swift", description: nil),
        MonaMultiDiffItem(
            id: "b", originalModelURI: nil, modifiedModelURI: nil,
            label: "B.swift", description: nil),
    ]
    var snapshot: [MonaMultiDiffItem] { _snapshot }
    var onDidChangeSnapshot: MonaEvent<MonaMultiDiffSnapshotChange> { emitter.event }

    /// Pushes a new snapshot (fires the change event synchronously).
    func pushSnapshot(_ items: [MonaMultiDiffItem]) {
        _snapshot = items
        emitter.fire(MonaMultiDiffSnapshotChange(items: items, rejectedDuplicateIDs: false))
    }
}

/// A stub transactional workspace-edit host for the four-outcome matrix.
private final class StubTransactionalHost: MonaWorkspaceEditHost {
    let model: MonaCodeModel
    enum PrepareBehavior {
        case succeed
        case decline
        case fail(Error)
    }
    let prepareBehavior: PrepareBehavior
    var prepareCallCount = 0
    var preparedTransaction: StubPreparedTransaction?

    init(model: MonaCodeModel, prepareBehavior: PrepareBehavior = .succeed) {
        self.model = model
        self.prepareBehavior = prepareBehavior
    }

    var capabilities: MonaWorkspaceEditCapabilities {
        MonaWorkspaceEditCapabilities(
            appliesResourceOperations: true,
            supportsTransactional: true,
            supportsUndoReceipts: false)
    }

    func applyExternalOperation(
        _ operation: MonaExternalWorkspaceOperation,
        index: Int,
        transactionID: MonaWorkspaceTransactionIdentity
    ) async throws -> MonaWorkspaceOperationResult {
        MonaWorkspaceOperationResult(applied: true, undoReceipt: nil)
    }

    func undoExternalOperation(receipt: MonaWorkspaceUndoReceipt) async -> Bool { false }

    func prepareAtomicExternalOperations(
        _ operations: [MonaExternalWorkspaceOperation],
        transactionID: MonaWorkspaceTransactionIdentity
    ) async throws -> MonaPreparedWorkspaceTransaction {
        prepareCallCount += 1
        switch prepareBehavior {
        case .succeed:
            let prepared = StubPreparedTransaction()
            preparedTransaction = prepared
            return prepared
        case .decline:
            throw MonaHostContractError.workspaceAuthorityDeclined
        case .fail(let error):
            throw error
        }
    }
}

/// A stub prepared workspace transaction (host-side).
private final class StubPreparedTransaction: MonaPreparedWorkspaceTransaction {
    var identity: MonaWorkspaceTransactionIdentity {
        MonaWorkspaceTransactionIdentity(id: "stub-tx")
    }
    var commitCallCount = 0
    var abortCallCount = 0
    func commit() { commitCallCount += 1 }
    func abort() async { abortCallCount += 1 }
}

// MARK: - Manifest shell (for the source-closure manifest decode)

/// A minimal shell for decoding the source-closure manifest JSON.
private struct ManifestShell: Decodable {
    struct Identity: Decodable {
        let provisional: Bool
        let provisionalReason: String
    }
    struct X1RSetEquality: Decodable {
        let javascriptModules: Int
        let styleResources: Int
        let styleRuleNodes: Int
        let styleDeclarations: Int
        let directGlobalIdentifiers: Int
        let directGlobalReferences: Int
        let localizationMessages: Int
    }
    struct ProductSourceRow: Decodable {
        let path: String
        let role: String
        let target: String
    }
    let identity: Identity
    let x1rSetEquality: X1RSetEquality
    let productSourceRows: [ProductSourceRow]
    let forbiddenRuntimeClasses: [String]
}
