// MonaSessionStore.swift
//
// P07-T003 — Implement 40 standalone services and bounded session state.
//
// The bounded session state: `MonaSessionStateStore` is a process-global,
// MainActor-free typed store with application, profile, workspace and
// applicationShared namespaces; it is initialized empty and destroyed with
// the process. This file implements the bounded rows for suggestion memory,
// scope switching, save delay, widget details, and shared state.
//
// S1-R contract: monacode-s1r-standalone-service-contract-manifest.json
//   - `sessionStorage.architecture`: process-global typed store, four scopes,
//     initialized empty, destroyed with the process.
//   - `sessionStorage.lifetime`: "Editor disposal does not clear session
//     state. Process termination clears every entry. A new process starts
//     empty. No public storage protocol or persistence opt-in exists."
//   - `sessionStorage.privacy`: "Find, replace, completion and resource-derived
//     values never leave process memory; logging and generated acceptance
//     artifacts must not serialize session values."
//   - C09: bounded states enforce 300/200/50/20 source bounds.
//   - C10: no persistence backend, telemetry transport, notification UI,
//     progress UI, signal audio, WebWorker or Tree-sitter implementation.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

// MARK: - Session scope

/// The four S1-R logical storage scopes.
///
/// Verbatim from `sessionStorage.groups[*].scope`: application, profile,
/// workspace, and the cross-service applicationShared namespace.
public enum MonaSessionScope: String, Sendable, Equatable, CaseIterable {

    /// Process-static application state (e.g. command MRU counter, inline-edit
    /// gutter indicator user kind).
    case application

    /// Per-profile state (e.g. suggest widget size, peek layout, expand-docs
    /// flag).
    case profile

    /// Per-workspace state (e.g. find flags, suggest memory, CodeLens cache).
    case workspace

    /// Cross-service shared state (the applicationShared namespace).
    case applicationShared
}

// MARK: - Absent capabilities

/// A web/VSCode capability that is NOT ported to MonaCode — declared absent,
/// not implemented (S1-R `feedbackChannels` + C10).
public enum MonaAbsentCapability: String, Sendable, Equatable, CaseIterable {

    /// No persistence backend: no IndexedDB, localStorage, UserDefaults,
    /// NSUbiquitousKeyValueStore, Keychain, filesystem, database, or host
    /// callback. (S1-R `sessionStorage.forbiddenBackends` + `feedbackChannels`.)
    case persistence

    /// No telemetry transport: all telemetry calls are strict no-ops and never
    /// reach a host, file, socket or generated report. (S1-R `feedbackChannels.telemetry`.)
    case telemetryTransport

    /// No notification-progress UI: no toast, no spinner, no progress bar, no
    /// cancellation button, no accessibility announcement.
    /// (S1-R `feedbackChannels.notification` + `feedbackChannels.progress`.)
    case notificationProgressUI

    /// No signal audio: `playSignal` is a strict no-op and no audio resource
    /// ships. (S1-R `feedbackChannels.accessibilitySignals`.)
    case signalAudio

    /// No WebWorker construction or execution. (S1-R explicit-cut
    /// `IWebWorkerService`.)
    case webWorker

    /// No Tree-sitter library loading or tokenization. (S1-R explicit-cut
    /// `ITreeSitterLibraryService`.)
    case treeSitterLibrary
}

// MARK: - Bounded rows

/// A single deferred-save timer entry. S1-R: the suggest-memory save scheduler
/// is 500 ms.
public struct MonaSaveDelayEntry: Sendable, Equatable {

    /// The logical key this deferred save schedules (e.g.
    /// "suggest/memories/recentlyUsed").
    public let key: String

    /// The deferred-save delay in milliseconds (always 500 in S1-R).
    public let delayMs: Int

    public init(key: String, delayMs: Int) {
        self.key = key
        self.delayMs = delayMs
    }
}

/// A single cross-service shared-state value (the applicationShared namespace).
public struct MonaSharedStateEntry: Sendable, Equatable {

    public let key: String

    /// The shared value boxed as `AnySendable` (string/number/boolean).
    public let value: AnySendable

    public init(key: String, value: AnySendable) {
        self.key = key
        self.value = value
    }
}

extension MonaSharedStateEntry {

    public static func == (lhs: MonaSharedStateEntry, rhs: MonaSharedStateEntry) -> Bool {
        lhs.key == rhs.key && lhs.value.isEqual(to: rhs.value)
    }
}

/// A type-erased sendable value used for shared-state boxing. Only the scalar
/// kinds Monaco's fixed consumers produce are supported: string, number
/// (Int/Double), and boolean. Any other kind is stored as `null`.
public struct AnySendable: Sendable, Equatable {

    private enum Storage: Sendable {
        case string(String)
        case int(Int)
        case double(Double)
        case bool(Bool)
        case null
    }

    private let storage: Storage

    public init(_ value: String) { self.storage = .string(value) }
    public init(_ value: Int) { self.storage = .int(value) }
    public init(_ value: Double) { self.storage = .double(value) }
    public init(_ value: Bool) { self.storage = .bool(value) }
    public init() { self.storage = .null }

    /// Returns `true` when `other` is the same scalar kind and equal value.
    public func isEqual(to other: AnySendable) -> Bool {
        switch (storage, other.storage) {
        case (.string(let a), .string(let b)): return a == b
        case (.int(let a), .int(let b)): return a == b
        case (.double(let a), .double(let b)): return a == b
        case (.bool(let a), .bool(let b)): return a == b
        case (.null, .null): return true
        default: return false
        }
    }

    public static func == (lhs: AnySendable, rhs: AnySendable) -> Bool {
        lhs.isEqual(to: rhs)
    }

    /// The value as a string (used by consumers that only read strings).
    public var stringValue: String? {
        switch storage {
        case .string(let s): return s
        case .int(let i): return String(i)
        case .double(let d): return String(d)
        case .bool(let b): return b ? "true" : "false"
        case .null: return nil
        }
    }

    /// The value as a boolean, if it is one.
    public var boolValue: Bool? {
        switch storage {
        case .bool(let b): return b
        default: return nil
        }
    }
}

// MARK: - Session store

/// The process-global typed session-state store.
///
/// Holds bounded rows for the five categories the S1-R contract governs:
///   - suggestion memory (recent suggestions) — LRU bounded at 300, prefix
///     serialization bounded at 200, 500 ms save scheduler;
///   - scope switching (current scope);
///   - save delay (deferred-save timers);
///   - widget details (widget state — suggest-widget size identities and the
///     expand-docs flag);
///   - shared state (cross-service applicationShared namespace).
///
/// **Lifetime.** Editor disposal does NOT clear session state. Process
/// termination clears every entry. A new process starts empty. No public
/// storage protocol or persistence opt-in exists in this revision.
///
/// **Privacy.** Find, replace, completion and resource-derived values never
/// leave process memory; logging and generated acceptance artifacts must not
/// serialize session values.
public final class MonaSessionStore: @unchecked Sendable {

    // MARK: Bounds (S1-R C09: 300/200/50/20)

    /// The S1-R bound on the recentlyUsed suggestion-memory LRU.
    public static let suggestionMemoryBound: Int = 300

    /// The S1-R bound on the prefix-serialization suggestion memory.
    public static let suggestionPrefixBound: Int = 200

    /// The S1-R save-delay scheduler interval in milliseconds.
    public static let saveDelayIntervalMs: Int = 500

    /// The S1-R command-MRU runtime bound.
    public static let commandMRUBound: Int = 50

    /// The S1-R live CodeLens LRU bound.
    public static let codeLensLRUBound: Int = 20

    // MARK: Forbidden backends (C10)

    /// The S1-R `sessionStorage.forbiddenBackends` list — backends that must
    /// never be reachable.
    public static let forbiddenBackends: [String] = [
        "UserDefaults",
        "NSUbiquitousKeyValueStore",
        "Keychain",
        "filesystem",
        "database",
        "network",
        "host callback",
    ]

    // MARK: Absent capabilities (C10)

    /// The web/VSCode capabilities that are NOT ported — declared absent, not
    /// implemented.
    public static let absentCapabilities: [MonaAbsentCapability] = [
        .persistence,
        .telemetryTransport,
        .notificationProgressUI,
        .signalAudio,
        .webWorker,
        .treeSitterLibrary,
    ]

    // MARK: State (process-memory only)

    /// Recently-used suggestions, LRU-bounded at 300. Insertion order is
    /// newest-last; the head is the oldest surviving entry.
    private var _suggestionMemory: [String] = []
    /// Prefix-serialized suggestions, bounded at 200.
    private var _suggestionPrefixes: [String] = []
    /// The current scope (the single scope-switching row).
    private var _currentScope: MonaSessionScope = .workspace
    private var _hasCurrentScope: Bool = false
    /// Deferred-save timer entries, keyed by logical key.
    private var _saveDelay: [String: MonaSaveDelayEntry] = [:]
    /// Widget details (suggest-widget size identities + expand-docs flag).
    private var _widgetDetails: [String: AnySendable] = [:]
    /// Cross-service shared state (applicationShared namespace).
    private var _sharedState: [String: AnySendable] = [:]

    /// Lock-free is unnecessary: this Foundation-only store is single-threaded
    /// by construction (the editor MainActor in AppKit drives it). A simple
    /// unfair mutex guards the rows for Sendable correctness.
    private var lock = NSLock()

    public init() {
        // S1-R lifetime: "A new process starts empty." Nothing to do.
    }

    // MARK: Suggestion memory (LRU 300)

    /// The recently-used suggestion memory, bounded at 300.
    public var suggestionMemory: [String] {
        lock.lock(); defer { lock.unlock() }
        return _suggestionMemory
    }

    public var suggestionMemoryBound: Int { Self.suggestionMemoryBound }

    /// Records a suggestion into the recentlyUsed LRU, evicting the oldest
    /// entry when the bound is exceeded.
    public func recordSuggestionMemory(_ suggestion: String) {
        lock.lock(); defer { lock.unlock() }
        // De-duplicate (LRU moves to the back).
        _suggestionMemory.removeAll { $0 == suggestion }
        _suggestionMemory.append(suggestion)
        let bound = Self.suggestionMemoryBound
        while _suggestionMemory.count > bound {
            _suggestionMemory.removeFirst()
        }
    }

    // MARK: Suggestion prefix (200)

    public var suggestionPrefixBound: Int { Self.suggestionPrefixBound }

    public var suggestionPrefixCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _suggestionPrefixes.count
    }

    public var suggestionPrefixes: [String] {
        lock.lock(); defer { lock.unlock() }
        return _suggestionPrefixes
    }

    public func recordSuggestionPrefix(_ prefix: String) {
        lock.lock(); defer { lock.unlock() }
        _suggestionPrefixes.removeAll { $0 == prefix }
        _suggestionPrefixes.append(prefix)
        let bound = Self.suggestionPrefixBound
        while _suggestionPrefixes.count > bound {
            _suggestionPrefixes.removeFirst()
        }
    }

    // MARK: Scope switching (current scope)

    /// The current scope (workspace by default per S1-R suggest-memory group).
    public var currentScope: MonaSessionScope {
        lock.lock(); defer { lock.unlock() }
        return _hasCurrentScope ? _currentScope : .workspace
    }

    /// The scope-switching rows (always exactly one — the current scope).
    public var scopeSwitching: [MonaSessionScope] {
        lock.lock(); defer { lock.unlock() }
        return _hasCurrentScope ? [_currentScope] : []
    }

    public func setCurrentScope(_ scope: MonaSessionScope) {
        lock.lock(); defer { lock.unlock() }
        _currentScope = scope
        _hasCurrentScope = true
    }

    // MARK: Save delay (500 ms scheduler)

    public var saveDelayIntervalMs: Int { Self.saveDelayIntervalMs }

    public var saveDelay: [MonaSaveDelayEntry] {
        lock.lock(); defer { lock.unlock() }
        return Array(_saveDelay.values)
    }

    public func scheduleSaveDelay(for key: String) {
        lock.lock(); defer { lock.unlock() }
        _saveDelay[key] = MonaSaveDelayEntry(
            key: key,
            delayMs: Self.saveDelayIntervalMs
        )
    }

    // MARK: Widget details (suggest-widget size identities + docs flag)

    public var widgetDetails: [String: AnySendable] {
        lock.lock(); defer { lock.unlock() }
        return _widgetDetails
    }

    public func setWidgetDetail(_ key: String, value: AnySendable) {
        lock.lock(); defer { lock.unlock() }
        _widgetDetails[key] = value
    }

    public func widgetDetail(for key: String) -> AnySendable? {
        lock.lock(); defer { lock.unlock() }
        return _widgetDetails[key]
    }

    // MARK: Shared state (applicationShared namespace)

    public var sharedState: [String: AnySendable] {
        lock.lock(); defer { lock.unlock() }
        return _sharedState
    }

    public func setSharedState(_ key: String, value: AnySendable) {
        lock.lock(); defer { lock.unlock() }
        _sharedState[key] = value
    }

    public func sharedValue(for key: String) -> AnySendable? {
        lock.lock(); defer { lock.unlock() }
        return _sharedState[key]
    }

    // MARK: Lifetime (editor disposal / process termination)

    /// S1-R: "Editor disposal does not clear session state." This method is a
    /// no-op that exists only to make the lifetime contract explicit and
    /// exercisable by tests.
    public func onEditorDisposal() {
        // Intentionally does nothing — fixed services are process eager
        // singletons; find/history/widget/peek/quick state survives editor
        // disposal and is only cleared by process termination.
    }

    /// S1-R: "Process termination clears every entry." Clears every bounded
    /// row and resets the store to its empty new-process state.
    public func onProcessTermination() {
        lock.lock(); defer { lock.unlock() }
        _suggestionMemory.removeAll()
        _suggestionPrefixes.removeAll()
        _hasCurrentScope = false
        _currentScope = .workspace
        _saveDelay.removeAll()
        _widgetDetails.removeAll()
        _sharedState.removeAll()
    }

    // MARK: Capability flags (C10 — absent, not implemented)

    /// `false` — no persistence backend is reachable (C10).
    public var hasPersistenceBackend: Bool { false }
    /// `false` — no telemetry transport is reachable (C10).
    public var hasTelemetryTransport: Bool { false }
    /// `false` — no notification/progress UI is reachable (C10).
    public var hasNotificationProgressUI: Bool { false }
    /// `false` — no signal audio is reachable (C10).
    public var hasSignalAudio: Bool { false }
}
