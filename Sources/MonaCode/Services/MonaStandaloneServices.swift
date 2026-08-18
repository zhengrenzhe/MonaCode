// MonaStandaloneServices.swift
//
// P07-T003 — Implement 40 standalone services and bounded session state.
//
// Defines the 40 default standalone editor services ported verbatim from
// monaco-editor-core@0.56.0 final `standaloneServices.js` (the frozen S1-R
// contract: monacode-s1r-standalone-service-contract-manifest.json,
// `sourceClosure.standaloneDefaultServiceRegistrations: 40`).
//
// Each of the 40 services carries:
//   - a stable service identifier (the S1-R `serviceMatrix.service` string,
//     e.g. "IConfigurationService");
//   - an implementation identifier (the S1-R `serviceMatrix.implementation`
//     string, e.g. "StandaloneConfigurationService");
//   - an explicit disposition (the S1-R `serviceMatrix.disposition` enum);
//   - an explicit lifetime ownership tag (GLOBAL = one instance for the whole
//     process, matching the `registerSingleton` call; PER-EDITOR = one instance
//     per editor — none of the 40 *default* registrations are per-editor
//     instances; per-editor child state lives in `MonaSessionStore`).
//
// The disposition partition matches S1-R `serviceDispositionCounts` exactly:
//   retained-native-core: 14, fixed-standalone-semantic: 2,
//   native-adaptation: 10, host-adaptation: 2, session-memory: 1,
//   mixed-log-noop: 1, baseline-noop: 8, explicit-cut: 2 → total 40.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The S1-R disposition of a standalone service (verbatim from the contract
/// `serviceMatrix.disposition`).
public enum MonaServiceDisposition: String, Sendable, Equatable, CaseIterable {

    /// Retained native core: process-global native behavior with exact traces
    /// (configuration, model, marker, language, theme, context, bulk edit,
    /// command, menu, …). Count: 14.
    case retainedNativeCore = "retained-native-core"

    /// Fixed standalone semantic: a fixed standalone fact that never changes
    /// (workspace = one synthetic inmemory:// model; workspace trust = always
    /// true). Count: 2.
    case fixedStandaloneSemantic = "fixed-standalone-semantic"

    /// Native adaptation: AppKit domain replaces the browser/DOM original
    /// (label, dialog, environment, accessibility, list, keybinding, quick
    /// input, context view/menu, clipboard). Count: 10.
    case nativeAdaptation = "native-adaptation"

    /// Host adaptation: typed host contract only (log → MonaLogSink, opener →
    /// H1/MD1 registries); no host protocol is added. Count: 2.
    case hostAdaptation = "host-adaptation"

    /// Session memory: process-memory namespaces only (storage = four
    /// in-memory scopes; no disk/defaults/keychain/host). Count: 1.
    case sessionMemory = "session-memory"

    /// Mixed log + no-op: severity-tagged events route to MonaLogSink while
    /// prompt/status remain strict no-ops (notification). Count: 1.
    case mixedLogNoop = "mixed-log-noop"

    /// Baseline no-op: zero side effect, never reaches a host/file/socket
    /// (telemetry, two progress services, AX signal, logger resource, data
    /// channel, account, rename tracker). Count: 8.
    case baselineNoop = "baseline-noop"

    /// Explicit cut: capability is absent (WebWorker construction/execution;
    /// Tree-sitter library loading/tokenization). Count: 2.
    case explicitCut = "explicit-cut"
}

/// The explicit lifetime ownership of a standalone service instance.
///
/// S1-R `standaloneDefaultServiceRegistrations: 40` — every one of the 40
/// default services is a `registerSingleton` call, i.e. one instance for the
/// whole process (`.global`). Per-editor child state (e.g. a context-key
/// child scope, a context-view overlay for the focused editor) is tracked
/// separately in `MonaSessionStore`; it is NOT a per-editor default
/// registration. The `.perEditor` case exists because the lifetime model
/// supports per-editor overrides created by a child instantiator, but the
/// fixed standalone baseline instantiates none for the default 40.
public enum MonaServiceLifetime: String, Sendable, Equatable, CaseIterable {

    /// One instance for the whole process (the `registerSingleton` lifetime).
    case global = "GLOBAL"

    /// One instance per editor (created by a child instantiator override).
    /// No default registration uses this lifetime in S1-R.
    case perEditor = "PER-EDITOR"
}

/// A single standalone service definition: the (service, implementation,
/// disposition, lifetime) tuple for one of the 40 S1-R default registrations.
public struct MonaStandaloneService: Sendable, Equatable {

    /// The S1-R `serviceMatrix.service` identifier (e.g. "IConfigurationService").
    public let serviceId: String

    /// The S1-R `serviceMatrix.implementation` identifier (e.g.
    /// "StandaloneConfigurationService").
    public let implementationId: String

    /// The S1-R disposition of this service.
    public let disposition: MonaServiceDisposition

    /// The explicit lifetime ownership of this service's instance.
    public let lifetime: MonaServiceLifetime

    /// The S1-R `serviceMatrix.contract` text (verbatim).
    public let contract: String

    /// Creates a service definition from its verbatim S1-R tuple.
    public init(
        serviceId: String,
        implementationId: String,
        disposition: MonaServiceDisposition,
        lifetime: MonaServiceLifetime,
        contract: String
    ) {
        self.serviceId = serviceId
        self.implementationId = implementationId
        self.disposition = disposition
        self.lifetime = lifetime
        self.contract = contract
    }
}

/// The 40 S1-R standalone service definitions, in manifest order.
///
/// This enumeration is the verbatim projection of the S1-R
/// `serviceMatrix` array. It is the single source of truth for the 40 service
/// identities, implementations, dispositions, and lifetime tags. The service
/// collection (`MonaServiceCollection`) instantiates exactly these 40.
public enum MonaStandaloneServices: Sendable, Equatable {

    /// The 40 S1-R default service registrations, in manifest order.
    ///
    /// Every entry's `lifetime` is `.global` because S1-R
    /// `standaloneDefaultServiceRegistrations: 40` are all `registerSingleton`
    /// calls (one instance for the whole process). Per-editor child state is
    /// tracked in `MonaSessionStore`, not as a per-editor default registration.
    public static let services: [MonaStandaloneService] = [
        MonaStandaloneService(
            serviceId: "IWebWorkerService",
            implementationId: "StandaloneWebWorkerService",
            disposition: .explicitCut,
            lifetime: .global,
            contract: "WebWorker construction and execution are absent."
        ),
        MonaStandaloneService(
            serviceId: "ILogService",
            implementationId: "StandaloneLogService",
            disposition: .hostAdaptation,
            lifetime: .global,
            contract: "Routes sanitized nonblocking events to MonaLogSink; nil drops them."
        ),
        MonaStandaloneService(
            serviceId: "IConfigurationService",
            implementationId: "StandaloneConfigurationService",
            disposition: .retainedNativeCore,
            lifetime: .global,
            contract: "Process-memory configuration, default model, editor/diff updates and synchronous change events are retained."
        ),
        MonaStandaloneService(
            serviceId: "ITextResourceConfigurationService",
            implementationId: "StandaloneResourceConfigurationService",
            disposition: .retainedNativeCore,
            lifetime: .global,
            contract: "Resource and language override lookup is retained."
        ),
        MonaStandaloneService(
            serviceId: "ITextResourcePropertiesService",
            implementationId: "StandaloneResourcePropertiesService",
            disposition: .retainedNativeCore,
            lifetime: .global,
            contract: "files.eol override and macOS LF fallback are retained."
        ),
        MonaStandaloneService(
            serviceId: "IWorkspaceContextService",
            implementationId: "StandaloneWorkspaceContextService",
            disposition: .fixedStandaloneSemantic,
            lifetime: .global,
            contract: "One synthetic inmemory://model/ workspace is retained; no host filesystem workspace is inferred."
        ),
        MonaStandaloneService(
            serviceId: "ILabelService",
            implementationId: "StandaloneUriLabelService",
            disposition: .nativeAdaptation,
            lifetime: .global,
            contract: "file URI uses fsPath semantics; other schemes use URI path; basename behavior is retained."
        ),
        MonaStandaloneService(
            serviceId: "ITelemetryService",
            implementationId: "StandaloneTelemetryService",
            disposition: .baselineNoop,
            lifetime: .global,
            contract: "publicLog2 emits nothing and never reaches MonaLogSink or a network."
        ),
        MonaStandaloneService(
            serviceId: "IDialogService",
            implementationId: "StandaloneDialogService",
            disposition: .nativeAdaptation,
            lifetime: .global,
            contract: "Exactly four reachable dialog call sites use the S1-R AppKit dialog outcomes and validity rules."
        ),
        MonaStandaloneService(
            serviceId: "IEnvironmentService",
            implementationId: "StandaloneEnvironmentService",
            disposition: .nativeAdaptation,
            lifetime: .global,
            contract: "Standalone fixed flags and MonaCodeEnvironment initialization are retained without browser globals."
        ),
        MonaStandaloneService(
            serviceId: "INotificationService",
            implementationId: "StandaloneNotificationService",
            disposition: .mixedLogNoop,
            lifetime: .global,
            contract: "info, warn, error and notify route to MonaLogSink only; prompt and status remain strict no-ops with no toast, choice execution or AX output."
        ),
        MonaStandaloneService(
            serviceId: "IMarkerService",
            implementationId: "MarkerService",
            disposition: .retainedNativeCore,
            lifetime: .global,
            contract: "Process-global marker ownership, reads and change events are retained."
        ),
        MonaStandaloneService(
            serviceId: "ILanguageService",
            implementationId: "StandaloneLanguageService",
            disposition: .retainedNativeCore,
            lifetime: .global,
            contract: "Language metadata lookup is retained with N1/L2 language-content cuts."
        ),
        MonaStandaloneService(
            serviceId: "IStandaloneThemeService",
            implementationId: "StandaloneThemeService",
            disposition: .retainedNativeCore,
            lifetime: .global,
            contract: "T1 global theme and token behavior is retained."
        ),
        MonaStandaloneService(
            serviceId: "IModelService",
            implementationId: "ModelService",
            disposition: .retainedNativeCore,
            lifetime: .global,
            contract: "M1/H2 model registry, creation and lifecycle behavior is retained."
        ),
        MonaStandaloneService(
            serviceId: "IMarkerDecorationsService",
            implementationId: "MarkerDecorationsService",
            disposition: .retainedNativeCore,
            lifetime: .global,
            contract: "Marker-to-decoration projection and updates are retained."
        ),
        MonaStandaloneService(
            serviceId: "IContextKeyService",
            implementationId: "ContextKeyService",
            disposition: .retainedNativeCore,
            lifetime: .global,
            contract: "Process root and per-editor child scopes are retained."
        ),
        MonaStandaloneService(
            serviceId: "IProgressService",
            implementationId: "StandaloneProgressService",
            disposition: .baselineNoop,
            lifetime: .global,
            contract: "Runs the task and discards progress reports; exposes no progress UI or cancellation control."
        ),
        MonaStandaloneService(
            serviceId: "IEditorProgressService",
            implementationId: "StandaloneEditorProgressService",
            disposition: .baselineNoop,
            lifetime: .global,
            contract: "show returns inert runner and showWhile only awaits; exposes no editor progress UI."
        ),
        MonaStandaloneService(
            serviceId: "IStorageService",
            implementationId: "InMemoryStorageService",
            disposition: .sessionMemory,
            lifetime: .global,
            contract: "Four logical scopes are process-memory namespaces only; no disk, defaults, keychain, host storage or cross-process recovery exists."
        ),
        MonaStandaloneService(
            serviceId: "IBulkEditService",
            implementationId: "StandaloneBulkEditService",
            disposition: .retainedNativeCore,
            lifetime: .global,
            contract: "Open-model text edits, version checks, undo stops and summary are retained; resource edits remain governed by H1."
        ),
        MonaStandaloneService(
            serviceId: "IWorkspaceTrustManagementService",
            implementationId: "StandaloneWorkspaceTrustManagementService",
            disposition: .fixedStandaloneSemantic,
            lifetime: .global,
            contract: "Workspace trust is always true and never changes."
        ),
        MonaStandaloneService(
            serviceId: "ITextModelService",
            implementationId: "StandaloneTextModelService",
            disposition: .retainedNativeCore,
            lifetime: .global,
            contract: "Only existing registered models resolve; missing resources reject Model not found; references never own model disposal."
        ),
        MonaStandaloneService(
            serviceId: "IAccessibilityService",
            implementationId: "AccessibilityService",
            disposition: .nativeAdaptation,
            lifetime: .global,
            contract: "A1/A2 AppKit accessibility state and events replace browser media queries and DOM."
        ),
        MonaStandaloneService(
            serviceId: "IListService",
            implementationId: "ListService",
            disposition: .nativeAdaptation,
            lifetime: .global,
            contract: "Retained widget list identity, selection, focus and lifecycle use AppKit controls."
        ),
        MonaStandaloneService(
            serviceId: "ICommandService",
            implementationId: "StandaloneCommandService",
            disposition: .retainedNativeCore,
            lifetime: .global,
            contract: "Component command lookup, will/did order, sync handler invocation and async result normalization are retained."
        ),
        MonaStandaloneService(
            serviceId: "IKeybindingService",
            implementationId: "StandaloneKeybindingService",
            disposition: .nativeAdaptation,
            lifetime: .global,
            contract: "I3 native event mapping feeds the retained resolver and command semantics."
        ),
        MonaStandaloneService(
            serviceId: "IQuickInputService",
            implementationId: "StandaloneQuickInputService",
            disposition: .nativeAdaptation,
            lifetime: .global,
            contract: "Retained quick-access data and action traces use native controls."
        ),
        MonaStandaloneService(
            serviceId: "IContextViewService",
            implementationId: "StandaloneContextViewService",
            disposition: .nativeAdaptation,
            lifetime: .global,
            contract: "Overlay ownership, placement and focused-editor fallback use AppKit view/window coordinates."
        ),
        MonaStandaloneService(
            serviceId: "IOpenerService",
            implementationId: "OpenerService",
            disposition: .hostAdaptation,
            lifetime: .global,
            contract: "H1/MD1 link and code-editor opener registries replace window navigation."
        ),
        MonaStandaloneService(
            serviceId: "IClipboardService",
            implementationId: "BrowserClipboardService",
            disposition: .nativeAdaptation,
            lifetime: .global,
            contract: "I4 NSPasteboard transport and metadata semantics replace browser clipboard APIs."
        ),
        MonaStandaloneService(
            serviceId: "IContextMenuService",
            implementationId: "StandaloneContextMenuService",
            disposition: .nativeAdaptation,
            lifetime: .global,
            contract: "Retained menu groups, actions, key labels, focus and dismissal use NSMenu."
        ),
        MonaStandaloneService(
            serviceId: "IMenuService",
            implementationId: "MenuService",
            disposition: .retainedNativeCore,
            lifetime: .global,
            contract: "F1 menu IDs, ordering, context rules and in-session hidden state are retained."
        ),
        MonaStandaloneService(
            serviceId: "IAccessibilitySignalService",
            implementationId: "StandaloneAccessbilitySignalService",
            disposition: .baselineNoop,
            lifetime: .global,
            contract: "Audio and other accessibility signals emit nothing."
        ),
        MonaStandaloneService(
            serviceId: "ITreeSitterLibraryService",
            implementationId: "StandaloneTreeSitterLibraryService",
            disposition: .explicitCut,
            lifetime: .global,
            contract: "Tree-sitter library loading and tokenization are absent."
        ),
        MonaStandaloneService(
            serviceId: "ILoggerService",
            implementationId: "NullLoggerService",
            disposition: .baselineNoop,
            lifetime: .global,
            contract: "No logger resources or output are created."
        ),
        MonaStandaloneService(
            serviceId: "IDataChannelService",
            implementationId: "NullDataChannelService",
            disposition: .baselineNoop,
            lifetime: .global,
            contract: "No data channel is created or opened."
        ),
        MonaStandaloneService(
            serviceId: "IDefaultAccountService",
            implementationId: "StandaloneDefaultAccountService",
            disposition: .baselineNoop,
            lifetime: .global,
            contract: "Default account is always null and its change event never fires."
        ),
        MonaStandaloneService(
            serviceId: "IRenameSymbolTrackerService",
            implementationId: "NullRenameSymbolTrackerService",
            disposition: .baselineNoop,
            lifetime: .global,
            contract: "Rename tracking has no external side effect or state."
        ),
        MonaStandaloneService(
            serviceId: "IUserInteractionService",
            implementationId: "UserInteractionService",
            disposition: .retainedNativeCore,
            lifetime: .global,
            contract: "Retained user-interaction epochs and events follow native input/action commits."
        ),
    ]

    /// The count of default registrations (always 40 in S1-R).
    public static let count: Int = services.count

    /// The number of services with GLOBAL lifetime (always 40 in S1-R — all
    /// `registerSingleton` calls are process-global).
    public static let globalLifetimeCount: Int =
        services.lazy.filter { $0.lifetime == .global }.count

    /// The number of services with PER-EDITOR lifetime (always 0 in S1-R — no
    /// default registration is a per-editor instance).
    public static let perEditorLifetimeCount: Int =
        services.lazy.filter { $0.lifetime == .perEditor }.count

    /// A per-disposition count dictionary, matching S1-R
    /// `serviceDispositionCounts` exactly.
    public static var dispositionCounts: [MonaServiceDisposition: Int] {
        var counts: [MonaServiceDisposition: Int] = [:]
        for service in services {
            counts[service.disposition, default: 0] += 1
        }
        return counts
    }
}
