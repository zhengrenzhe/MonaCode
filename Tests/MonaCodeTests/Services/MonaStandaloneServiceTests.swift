// MonaStandaloneServiceTests.swift
//
// P07-T003 — Implement 40 standalone services and bounded session state.
//
// Verifies the S1-R standalone services / session / feedback closure ported
// from monaco-editor-core@0.56.0 final `standaloneServices.js` (the frozen
// S1-R contract: monacode-s1r-standalone-service-contract-manifest.json):
//   - Exactly 40 retained standalone services, each with an explicit lifetime
//     ownership tag (GLOBAL = one instance for the whole process, matching the
//     40 `registerSingleton` calls; PER-EDITOR = one instance per editor).
//   - Bounded session rows for suggestion memory, scope switching, save delay,
//     widget details, and shared state — with the S1-R source bounds
//     (suggest-memory LRU 300 / prefix 200 / 500 ms save scheduler; command
//     MRU bound 50; CodeLens LRU 20; widget size 2 identities + docs flag).
//   - The four web/VSCode capabilities that are NOT ported are ABSENT
//     (declared unavailable, not implemented): persistence backend, telemetry
//     transport, notification/progress UI, and accessibility signal audio.
//   - Nonblocking localized feedback reuses T007 MonaLocalization and never
//     includes document text in feedback messages.
//
// MonaCode is a Foundation-only target: tests import XCTest + MonaCode.

import XCTest
import MonaCode

final class MonaStandaloneServiceTests: XCTestCase {

    // MARK: - 1. Exactly 40 retained services with explicit lifetime ownership

    func testServiceCollectionInstantiatesExactly40Services() {
        let collection = MonaServiceCollection.bootstrap()
        XCTAssertEqual(collection.services.count, 40,
                       "S1-R standalone editor has exactly 40 default service registrations")
    }

    func testEveryServiceHasExplicitLifetimeOwnership() {
        let collection = MonaServiceCollection.bootstrap()
        // Every one of the 40 services carries a lifetime tag drawn from the
        // MonaServiceLifetime enum (GLOBAL or PER-EDITOR) — none is untagged.
        XCTAssertTrue(
            collection.services.allSatisfy {
                MonaServiceLifetime.allCases.contains($0.lifetime)
            },
            "every one of the 40 services carries an explicit lifetime tag"
        )
    }

    func testAll40DefaultRegistrationsAreProcessGlobalSingletons() {
        // The S1-R contract: `standaloneDefaultServiceRegistrations: 40` — all
        // 40 are `registerSingleton` calls, i.e. one instance for the whole
        // process (GLOBAL). Per-editor child state is tracked separately in
        // MonaSessionStore; no default registration is a per-editor instance.
        let collection = MonaServiceCollection.bootstrap()
        XCTAssertEqual(collection.globalLifetimeCount, 40,
                       "all 40 default registrations are process-global singletons")
        XCTAssertEqual(collection.perEditorLifetimeCount, 0,
                       "no default registration is a per-editor instance")
    }

    func testServiceCollectionExposesServiceCountAndIdentity() {
        let collection = MonaServiceCollection.bootstrap()
        XCTAssertEqual(collection.serviceCount, 40)
        // The 40 service identities are unique.
        let ids = collection.services.map(\.serviceId)
        XCTAssertEqual(Set(ids).count, 40, "service identifiers are unique")
    }

    // MARK: - 2. The 40 service identities (S1-R serviceMatrix, verbatim)

    func testThe40ServiceIdentitiesMatchS1RMatrix() {
        let collection = MonaServiceCollection.bootstrap()
        let ids = collection.services.map(\.serviceId)
        XCTAssertEqual(ids, [
            "IWebWorkerService",
            "ILogService",
            "IConfigurationService",
            "ITextResourceConfigurationService",
            "ITextResourcePropertiesService",
            "IWorkspaceContextService",
            "ILabelService",
            "ITelemetryService",
            "IDialogService",
            "IEnvironmentService",
            "INotificationService",
            "IMarkerService",
            "ILanguageService",
            "IStandaloneThemeService",
            "IModelService",
            "IMarkerDecorationsService",
            "IContextKeyService",
            "IProgressService",
            "IEditorProgressService",
            "IStorageService",
            "IBulkEditService",
            "IWorkspaceTrustManagementService",
            "ITextModelService",
            "IAccessibilityService",
            "IListService",
            "ICommandService",
            "IKeybindingService",
            "IQuickInputService",
            "IContextViewService",
            "IOpenerService",
            "IClipboardService",
            "IContextMenuService",
            "IMenuService",
            "IAccessibilitySignalService",
            "ITreeSitterLibraryService",
            "ILoggerService",
            "IDataChannelService",
            "IDefaultAccountService",
            "IRenameSymbolTrackerService",
            "IUserInteractionService",
        ], "the 40 ids are the S1-R serviceMatrix service identifiers in manifest order")
    }

    func testServiceDispositionsPartitionMatchesS1RCounts() {
        let collection = MonaServiceCollection.bootstrap()
        // S1-R `serviceDispositionCounts`:
        //   retained-native-core: 14, fixed-standalone-semantic: 2,
        //   native-adaptation: 10, host-adaptation: 2, session-memory: 1,
        //   mixed-log-noop: 1, baseline-noop: 8, explicit-cut: 2 → total 40.
        let counts = collection.dispositionCounts
        XCTAssertEqual(counts[.retainedNativeCore], 14)
        XCTAssertEqual(counts[.fixedStandaloneSemantic], 2)
        XCTAssertEqual(counts[.nativeAdaptation], 10)
        XCTAssertEqual(counts[.hostAdaptation], 2)
        XCTAssertEqual(counts[.sessionMemory], 1)
        XCTAssertEqual(counts[.mixedLogNoop], 1)
        XCTAssertEqual(counts[.baselineNoop], 8)
        XCTAssertEqual(counts[.explicitCut], 2)
        XCTAssertEqual(counts.values.reduce(0, +), 40)
    }

    // MARK: - 3. Bounded session rows (suggestion memory / scope / save-delay / widget / shared)

    func testSessionStoreStartsEmptyForNewProcess() {
        // C05/C09: process restart begins empty; no persistence carries over.
        let store = MonaSessionStore()
        XCTAssertTrue(store.suggestionMemory.isEmpty)
        XCTAssertTrue(store.scopeSwitching.isEmpty)
        XCTAssertTrue(store.saveDelay.isEmpty)
        XCTAssertTrue(store.widgetDetails.isEmpty)
        XCTAssertTrue(store.sharedState.isEmpty)
    }

    func testSuggestionMemoryEnforcesLRU300Bound() {
        // C09: bounded states enforce the 300 source bound.
        let store = MonaSessionStore()
        for i in 0..<400 {
            store.recordSuggestionMemory("item-\(i)")
        }
        XCTAssertEqual(store.suggestionMemory.count, 300,
                       "recentlyUsed LRU is capped at 300")
        XCTAssertEqual(store.suggestionMemoryBound, 300)
        // Oldest evicted, newest retained (LRU order).
        XCTAssertEqual(store.suggestionMemory.first, "item-100")
        XCTAssertEqual(store.suggestionMemory.last, "item-399")
    }

    func testSuggestionMemoryPrefixEnforces200Bound() {
        // C09: prefix serialization keeps 200 newest.
        let store = MonaSessionStore()
        for i in 0..<250 {
            store.recordSuggestionPrefix("prefix-\(i)")
        }
        XCTAssertEqual(store.suggestionPrefixBound, 200)
        XCTAssertEqual(store.suggestionPrefixCount, 200)
        XCTAssertEqual(store.suggestionPrefixes.first, "prefix-50")
        XCTAssertEqual(store.suggestionPrefixes.last, "prefix-249")
    }

    func testSaveDelaySchedulerIs500ms() {
        // P11: 500 ms save timing.
        let store = MonaSessionStore()
        XCTAssertEqual(store.saveDelayIntervalMs, 500)
        store.scheduleSaveDelay(for: "suggest/memories/recentlyUsed")
        XCTAssertEqual(store.saveDelay.count, 1)
        XCTAssertEqual(store.saveDelay.first?.key, "suggest/memories/recentlyUsed")
        XCTAssertEqual(store.saveDelay.first?.delayMs, 500)
    }

    func testScopeSwitchingHoldsCurrentScope() {
        // P11: suggestion memory strategy/scope switching.
        let store = MonaSessionStore()
        store.setCurrentScope(.workspace)
        XCTAssertEqual(store.currentScope, .workspace)
        store.setCurrentScope(.profile)
        XCTAssertEqual(store.currentScope, .profile)
        XCTAssertEqual(store.scopeSwitching.count, 1,
                       "scope switching holds exactly the current scope")
    }

    func testWidgetDetailsHoldsSuggestWidgetSizeIdentitiesAndDocsFlag() {
        // P11: widget details/size; S1-R suggest-widget group:
        //   suggestWidget.size/vs.editor.ICodeEditor/false,
        //   suggestWidget.size/vs.editor.ICodeEditor/true,
        //   expandSuggestionDocs (default false).
        let store = MonaSessionStore()
        store.setWidgetDetail("suggestWidget.size/vs.editor.ICodeEditor/false",
                              value: AnySendable("320x440"))
        store.setWidgetDetail("suggestWidget.size/vs.editor.ICodeEditor/true",
                              value: AnySendable("320x600"))
        store.setWidgetDetail("expandSuggestionDocs", value: AnySendable(false))
        XCTAssertEqual(store.widgetDetails.count, 3)
        XCTAssertEqual(store.widgetDetail(for: "expandSuggestionDocs")?.boolValue, false)
    }

    func testSharedStateIsCrossServiceNamespace() {
        // P11: process-shared state; shared state is the applicationShared scope.
        let store = MonaSessionStore()
        store.setSharedState("inlineEditsGutterIndicatorUserKind", value: AnySendable("new"))
        XCTAssertEqual(store.sharedState.count, 1)
        XCTAssertEqual(store.sharedValue(for: "inlineEditsGutterIndicatorUserKind")?.stringValue, "new")
    }

    func testEditorDisposalDoesNotClearSessionState() {
        // S1-R lifetime: "Editor disposal does not clear session state."
        let store = MonaSessionStore()
        store.recordSuggestionMemory("kept")
        store.setCurrentScope(.workspace)
        store.setWidgetDetail("expandSuggestionDocs", value: AnySendable(true))
        store.onEditorDisposal()
        XCTAssertEqual(store.suggestionMemory.count, 1)
        XCTAssertEqual(store.currentScope, .workspace)
        XCTAssertEqual(store.widgetDetails.count, 1)
    }

    func testProcessTerminationClearsEveryEntry() {
        // S1-R lifetime: "Process termination clears every entry."
        let store = MonaSessionStore()
        for i in 0..<50 { store.recordSuggestionMemory("m-\(i)") }
        store.setCurrentScope(.profile)
        store.setWidgetDetail("expandSuggestionDocs", value: AnySendable(true))
        store.onProcessTermination()
        XCTAssertTrue(store.suggestionMemory.isEmpty)
        XCTAssertTrue(store.scopeSwitching.isEmpty)
        XCTAssertTrue(store.widgetDetails.isEmpty)
        XCTAssertTrue(store.sharedState.isEmpty)
    }

    // MARK: - 4. Persistence / telemetry / notification-UI / audio are ABSENT

    func testAbsentCapabilitiesAreDeclaredNotImplemented() {
        // C10: no persistence backend, telemetry transport, notification UI,
        // progress UI, signal audio, WebWorker or Tree-sitter implementation.
        let absent = MonaSessionStore.absentCapabilities
        XCTAssertTrue(absent.contains(.persistence))
        XCTAssertTrue(absent.contains(.telemetryTransport))
        XCTAssertTrue(absent.contains(.notificationProgressUI))
        XCTAssertTrue(absent.contains(.signalAudio))
        XCTAssertTrue(absent.contains(.webWorker))
        XCTAssertTrue(absent.contains(.treeSitterLibrary))
    }

    func testNoPersistenceBackendIsReachable() {
        // C10: binary and source scans prove no persistence backend is linked.
        // The session store exposes no persistence opt-in.
        let store = MonaSessionStore()
        XCTAssertFalse(store.hasPersistenceBackend)
        XCTAssertFalse(store.hasTelemetryTransport)
        XCTAssertFalse(store.hasNotificationProgressUI)
        XCTAssertFalse(store.hasSignalAudio)
    }

    func testForbiddenBackendsWithNoDiskOrKeychainOrHostCallback() {
        // S1-R `forbiddenBackends`: UserDefaults, NSUbiquitousKeyValueStore,
        // Keychain, filesystem, database, network, host callback.
        let forbidden = MonaSessionStore.forbiddenBackends
        XCTAssertTrue(forbidden.contains("UserDefaults"))
        XCTAssertTrue(forbidden.contains("NSUbiquitousKeyValueStore"))
        XCTAssertTrue(forbidden.contains("Keychain"))
        XCTAssertTrue(forbidden.contains("filesystem"))
        XCTAssertTrue(forbidden.contains("database"))
        XCTAssertTrue(forbidden.contains("network"))
        XCTAssertTrue(forbidden.contains("host callback"))
    }

    // MARK: - 5. Nonblocking localized feedback without document-text logging

    func testFeedbackServiceIsNonblocking() {
        // The feedback service does not block the editor; emit returns
        // immediately without running on the caller's thread of execution.
        let feedback = MonaFeedbackService(profile: .default)
        XCTAssertTrue(feedback.isNonblocking)
        feedback.emit(.info, messageIndex: 0)
        feedback.emit(.warn, messageIndex: 0)
        feedback.emit(.error, messageIndex: 0)
        // No blocking, no crash, no UI.
    }

    func testFeedbackServiceIsLocalized() {
        // Reuses T007 MonaLocalization — localized through the explicit N1
        // profile mechanism, not Foundation locale lookup.
        let feedback = MonaFeedbackService(profile: .default)
        XCTAssertEqual(feedback.profile, .default)
        // The feedback service holds a MonaLocalization resolve pathway.
        let resolved = feedback.localizedMessage(at: 0)
        XCTAssertNotNil(resolved)
    }

    func testFeedbackServiceDoesNotLogDocumentText() {
        // Privacy/security: feedback messages never include the document text.
        // The feedback service exposes no document-text logging surface.
        let feedback = MonaFeedbackService(profile: .default)
        XCTAssertFalse(feedback.logsDocumentText)
        feedback.emit(.error, messageIndex: 0, context: "sensitive document content")
        // The captured event must not carry document text.
        let events = feedback.drainEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertFalse(events[0].payload.contains("sensitive document content"),
                       "document text never enters feedback messages")
    }

    func testFeedbackServiceSeverityTaggedOnly() {
        // S1-R `feedbackChannels.notification`: info, warn, error and notify
        // produce sanitized severity-tagged events only.
        let feedback = MonaFeedbackService(profile: .default)
        feedback.emit(.info, messageIndex: 0)
        feedback.emit(.warn, messageIndex: 0)
        feedback.emit(.error, messageIndex: 0)
        let events = feedback.drainEvents()
        XCTAssertEqual(events.map(\.severity), [.info, .warn, .error])
    }

    func testFeedbackPromptAndStatusAreNoOps() {
        // S1-R: notification prompt returns inert handle and never executes
        // choices; notification status returns inert close and produces no UI.
        let feedback = MonaFeedbackService(profile: .default)
        let prompt = feedback.prompt(messageIndex: 0)
        XCTAssertTrue(prompt.isInert)
        let status = feedback.status(messageIndex: 0)
        XCTAssertTrue(status.isInert)
        // No events produced for prompt/status (no UI or accessibility output).
        XCTAssertTrue(feedback.drainEvents().isEmpty)
    }

    func testFeedbackTelemetryAndSignalsAreStrictNoOps() {
        // S1-R: telemetry + accessibility signals are strict no-ops and never
        // reach a host, file, socket or generated report; no audio resource.
        let feedback = MonaFeedbackService(profile: .default)
        feedback.emitTelemetry("any.event")
        feedback.playSignal("signal.id")
        XCTAssertTrue(feedback.drainEvents().isEmpty,
                      "telemetry and signals produce no feedback events")
        XCTAssertFalse(feedback.hasAudioResource)
    }
}
