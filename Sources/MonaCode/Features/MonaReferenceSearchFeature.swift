// MonaReferenceSearchFeature.swift
//
// P05-T146 — Implement retained feature referenceSearch.
//
// `MonaReferenceSearchFeature` is the Swift counterpart of Monaco's
// `referenceSearch` contribution (monaco-editor 0.56.0, the peek references
// widget registered as `editor.contrib.referencesController`): it streams,
// groups, navigates, and cancels reference provider results.
//
// Streaming publishes a grouped reference result through the shared
// `MonaProviderExecutor` (P05-T013) on the deterministic `MonaMicrotaskQueue`,
// with the result's publication guarded by a `MonaCancellationToken` — when
// cancellation is requested, the pending publication is suppressed. Grouping
// clusters locations by URI (preserving source order). Navigation advances the
// active reference forward / backward with wrap-around. Cancelling requests
// cancellation on the active token source and closes the peek.
//
// The feature is a Foundation-only Core surface (`import Foundation` only). It
// performs the three implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `groupReferences(_:)`,
//      `openReferences(_:modelVersion:)`, `navigateNext()` /
//      `navigatePrevious()`, `revealReference(at:)`, `streamReferences(...)`,
//      `closeReferenceSearch()`, and `cancelReferenceSearch()`.
//   2. Register the exact feature identity `referenceSearch` and its declared
//      commands, actions, contributions, options, menus, and keybindings,
//      referenced verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import Foundation

/// A single reference location: the URI of the file and the range of the
/// reference. Mirrors Monaco's `Location` (monaco-editor 0.56.0).
public struct MonaReferenceLocation: Equatable {

    /// The URI of the file containing the reference.
    public let uri: String

    /// The range of the reference within the file.
    public let range: MonaRange

    public init(uri: String, range: MonaRange) {
        self.uri = uri
        self.range = range
    }
}

/// A group of reference locations that share a URI. Mirrors Monaco's file
/// reference group (the peek references tree's per-file clustering).
public struct MonaReferenceGroup: Equatable {

    /// The URI of the file this group clusters.
    public let uri: String

    /// The reference locations within this file, in source order.
    public let locations: [MonaReferenceLocation]

    public init(uri: String, locations: [MonaReferenceLocation]) {
        self.uri = uri
        self.locations = locations
    }
}

/// A reference-search result: the flattened locations, the per-URI groups, and
/// the index of the active reference.
public struct MonaReferenceSearchResult: Equatable {

    /// The flattened reference locations, in source order.
    public let locations: [MonaReferenceLocation]

    /// The per-URI groups (derived from `locations`).
    public let groups: [MonaReferenceGroup]

    /// The index of the active reference within `locations`.
    public let currentIndex: Int

    public init(locations: [MonaReferenceLocation], groups: [MonaReferenceGroup], currentIndex: Int) {
        self.locations = locations
        self.groups = groups
        self.currentIndex = currentIndex
    }
}

/// A reference-search event: the current result (or `nil` when closed),
/// visibility, and the active reference index.
public struct MonaReferenceSearchEvent: Equatable {

    /// The current reference-search result, or `nil` when the peek is closed.
    public let result: MonaReferenceSearchResult?

    /// `true` when the peek references widget is visible.
    public let visible: Bool

    /// The active reference index (0 when no result).
    public let currentIndex: Int

    public init(result: MonaReferenceSearchResult?, visible: Bool, currentIndex: Int) {
        self.result = result
        self.visible = visible
        self.currentIndex = currentIndex
    }
}

/// The referenceSearch feature: stream, group, navigate, and cancel
/// reference provider results.
///
/// The feature identity `referenceSearch` and its declared slice are referenced
/// verbatim from the frozen registries. Model mutation (a rename edit at a
/// reference's range) is routed through `MonaTransactionGateway`; asynchronous
/// publication through `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal
/// through `MonaEmitter`; localization through `MonaLocalization`; and degraded
/// plain-text behavior through `MonaPlainTextLanguage`. Cancellation reuses
/// `MonaCancellationToken` / `MonaCancellationTokenSource`.
public final class MonaReferenceSearchFeature: MonaDisposable {

    /// The frozen feature identity (`"referenceSearch"`).
    public static let featureId = "referenceSearch"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce).
    /// referenceSearch declares no labeled actions, so this slice is empty.
    public static let declaredActionIds: [String] = []

    /// The declared command IDs in source order. These are the peek references
    /// command set: the trigger, the close commands, the navigation commands,
    /// and the reveal / open commands.
    public static let declaredCommandIds: [String] = [
        "editor.action.referenceSearch.trigger",
        "closeReferenceSearch",
        "closeReferenceSearchEditor",
        "goToNextReference",
        "goToPreviousReference",
        "openReference",
        "openReferenceToSide",
        "revealReference",
        "togglePeekWidgetFocus"
    ]

    /// The declared contribution ID (`editor.contrib.referencesController`).
    public static let declaredContributionIds: [String] = [
        "editor.contrib.referencesController"
    ]

    /// The declared keybinding commands — the referenceSearch commands that
    /// carry a default keybinding in `MonaBuiltinKeybindings`, in source order.
    public static let declaredKeybindingCommands: [String] = [
        "closeReferenceSearch",
        "goToNextReference",
        "goToPreviousReference",
        "openReferenceToSide",
        "revealReference",
        "togglePeekWidgetFocus"
    ]

    /// The declared option names. referenceSearch declares no options.
    public static let declaredOptionIds: [String] = []

    /// The declared menu IDs — the menus that carry referenceSearch menu items
    /// (the trigger command appears in `CommandPalette` + `EditorContextPeek`).
    public static let declaredMenuIds: [String] = [
        "CommandPalette",
        "EditorContextPeek"
    ]

    // MARK: - Routing state

    /// The retained reference-search result, or `nil` when the peek is closed.
    private var _result: MonaReferenceSearchResult? = nil

    /// `true` when the peek references widget is visible.
    private var _isVisible: Bool = false

    /// The active cancellation source for the in-flight reference stream. When
    /// `cancelReferenceSearch()` is called, this source is cancelled (suppressing
    /// the pending publication) and disposed.
    private var _cancellationSource: MonaCancellationTokenSource? = nil

    private let emitter = MonaEmitter<MonaReferenceSearchEvent>()

    /// The event stream for reference-search changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaReferenceSearchEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the referenceSearch feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    /// `true` when the peek references widget is visible.
    public var isVisible: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isVisible
    }

    /// The current reference-search result, or `nil` when the peek is closed.
    public var currentResult: MonaReferenceSearchResult? {
        _lock.lock(); defer { _lock.unlock() }
        return _result
    }

    /// The active reference index (0 when no result).
    public var currentIndex: Int {
        _lock.lock(); defer { _lock.unlock() }
        return _result?.currentIndex ?? 0
    }

    /// The cancellation token for the in-flight reference stream. Subscribers
    /// pass this to `streamReferences(...)` so `cancelReferenceSearch()` can
    /// suppress the pending publication. `MonaCancellationToken.none` when no
    /// stream is in flight.
    public var currentCancellationToken: MonaCancellationToken {
        _lock.lock(); defer { _lock.unlock() }
        return _cancellationSource?.token ?? .none
    }

    // MARK: - 1. Feature-specific behavior: group / open / navigate / cancel

    /// Groups `locations` by URI, preserving source order within each group and
    /// the order of first appearance across groups. A pure query.
    public func groupReferences(_ locations: [MonaReferenceLocation]) -> [MonaReferenceGroup] {
        var order: [String] = []
        var buckets: [String: [MonaReferenceLocation]] = [:]
        for location in locations {
            if buckets[location.uri] == nil {
                order.append(location.uri)
                buckets[location.uri] = []
            }
            buckets[location.uri]?.append(location)
        }
        return order.map { uri in
            MonaReferenceGroup(uri: uri, locations: buckets[uri] ?? [])
        }
    }

    /// Opens the peek references widget with `locations`, retained against
    /// `modelVersion`. Groups the locations, sets the active reference to 0,
    /// and fires an event. Returns the result, or `nil` when `locations` is
    /// empty (a no-reference result dismisses the peek) or after `dispose()`.
    @discardableResult
    public func openReferences(
        _ locations: [MonaReferenceLocation],
        modelVersion: Int
    ) -> MonaReferenceSearchResult? {
        guard !isDisposed else { return nil }
        guard !locations.isEmpty else {
            _lock.lock()
            _result = nil
            _isVisible = false
            _lock.unlock()
            fire(result: nil, visible: false, currentIndex: 0)
            return nil
        }
        let groups = groupReferences(locations)
        let result = MonaReferenceSearchResult(locations: locations, groups: groups, currentIndex: 0)
        _lock.lock()
        _result = result
        _isVisible = true
        // Arm a fresh cancellation source for the new search.
        _cancellationSource = MonaCancellationTokenSource()
        _lock.unlock()
        fire(result: result, visible: true, currentIndex: 0)
        return result
    }

    /// Navigates to the next reference, wrapping around to 0 at the end. Returns
    /// the updated result, or `nil` when the peek is not visible (or disposed).
    @discardableResult
    public func navigateNext() -> MonaReferenceSearchResult? {
        return navigate(by: 1)
    }

    /// Navigates to the previous reference, wrapping around to the last at 0.
    /// Returns the updated result, or `nil` when the peek is not visible (or
    /// disposed).
    @discardableResult
    public func navigatePrevious() -> MonaReferenceSearchResult? {
        return navigate(by: -1)
    }

    /// Returns the reference location at `index`, or `nil` when the peek is not
    /// open or `index` is out of range.
    public func revealReference(at index: Int) -> MonaReferenceLocation? {
        guard !isDisposed else { return nil }
        _lock.lock(); defer { _lock.unlock() }
        guard let result = _result else { return nil }
        guard result.locations.indices.contains(index) else { return nil }
        return result.locations[index]
    }

    /// Cancels the in-flight reference stream (requesting cancellation on the
    /// active token source, which suppresses the pending publication) and
    /// closes the peek. Returns `true` when the peek was visible and is now
    /// cancelled + closed. After `dispose()`, returns `false` and fires no
    /// event.
    @discardableResult
    public func cancelReferenceSearch() -> Bool {
        guard !isDisposed else { return false }
        _lock.lock()
        let wasVisible = _isVisible
        let source = _cancellationSource
        _cancellationSource = nil
        _isVisible = false
        _result = nil
        _lock.unlock()
        source?.cancel()
        if wasVisible {
            fire(result: nil, visible: false, currentIndex: 0)
        }
        return wasVisible
    }

    /// Closes the peek references widget: hides and clears the result. Returns
    /// `true` when the peek was visible and is now closed. After `dispose()`,
    /// returns `false` and fires no event.
    @discardableResult
    public func closeReferenceSearch() -> Bool {
        guard !isDisposed else { return false }
        _lock.lock()
        let wasVisible = _isVisible
        let source = _cancellationSource
        _cancellationSource = nil
        _isVisible = false
        _result = nil
        _lock.unlock()
        source?.dispose()
        if wasVisible {
            fire(result: nil, visible: false, currentIndex: 0)
        }
        return wasVisible
    }

    // MARK: - 3a. Mutation → MonaTransactionGateway

    /// Commits `text` as a replacement at `range` through `gateway` as one
    /// ordered unit (the rename edit applied at a reference's range). Returns
    /// the reconciliation outcome. A no-op after `dispose()` (returns `.dropped`).
    @discardableResult
    public func commitReferenceEdit(
        at range: MonaRange,
        text: String,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let transaction = gateway.beginTransaction()
        transaction.prepareEdits([
            MonaModelEditOperation(range: range, text: text)
        ])
        return gateway.commit(transaction)
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Streams the grouped reference result for `locations` through the shared
    /// provider executor, normalized onto the deterministic microtask queue.
    /// Publication is guarded by `token`: when cancellation is requested on
    /// `token` before publication, `receive` is never invoked. `receive` runs
    /// ONLY when the queue is drained (FIFO), after the publication ticket is
    /// validated. After `dispose()`, returns `false` and publishes nothing.
    @discardableResult
    public func streamReferences(
        _ locations: [MonaReferenceLocation],
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        token: MonaCancellationToken,
        receive: @escaping (MonaReferenceSearchResult) -> Void
    ) -> Bool {
        guard !isDisposed else { return false }
        let result = MonaReferenceSearchResult(
            locations: locations,
            groups: groupReferences(locations),
            currentIndex: 0
        )
        return executor.publish(
            .cancelable(token, result),
            ticket: ticket,
            receive: receive
        )
    }

    /// Publishes `result` through the shared provider executor, normalized onto
    /// the deterministic microtask queue. `receive` runs ONLY when the queue is
    /// drained (FIFO), after the publication ticket is validated. After
    /// `dispose()`, returns `false` and publishes nothing.
    @discardableResult
    public func publishReferences(
        _ result: MonaReferenceSearchResult,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaReferenceSearchResult) -> Void
    ) -> Bool {
        guard !isDisposed else { return false }
        return executor.publish(
            .synchronous(result),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, the result is cleared, the in-flight
    /// cancellation source is disposed, and `openReferences` / `navigateNext` /
    /// `navigatePrevious` / `streamReferences` / `cancelReferenceSearch` /
    /// `closeReferenceSearch` are no-ops.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        let source = _cancellationSource
        _cancellationSource = nil
        _result = nil
        _isVisible = false
        _lock.unlock()
        source?.dispose()
        if !already {
            emitter.dispose()
        }
    }

    // MARK: - 3d. Localization → MonaLocalization

    /// Returns the declared action labels formatted through the shared
    /// `MonaLocalization` surface under `profile`. referenceSearch declares no
    /// actions, so this returns an empty array under every profile.
    public func localizedActionLabels(profile: MonaCodeEnvironmentProfile) -> [String] {
        let registry = MonaActionRegistry()
        return Self.declaredActionIds.map { id in
            let label = registry.identity(for: id)?.label ?? id
            return MonaLocalization.format(label, args: [], profile: profile)
        }
    }

    // MARK: - 3e. Degraded plain-text → MonaPlainTextLanguage

    /// The plain-text fallback language. referenceSearch needs no tokenization;
    /// it degrades to plain text for its tokenization needs.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — referenceSearch performs no tokenization-dependent work and
    /// degrades gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Fires a reference-search event when not disposed.
    private func fire(result: MonaReferenceSearchResult?, visible: Bool, currentIndex: Int) {
        guard !isDisposed else { return }
        emitter.fire(MonaReferenceSearchEvent(
            result: result,
            visible: visible,
            currentIndex: currentIndex
        ))
    }

    /// Navigates the active reference by `delta` (wrapping). Returns the updated
    /// result, or `nil` when the peek is not visible.
    private func navigate(by delta: Int) -> MonaReferenceSearchResult? {
        guard !isDisposed else { return nil }
        _lock.lock()
        guard var current = _result, _isVisible, !current.locations.isEmpty else {
            _lock.unlock()
            return nil
        }
        _lock.unlock()
        let count = current.locations.count
        let nextIndex = ((current.currentIndex + delta) % count + count) % count
        current = MonaReferenceSearchResult(
            locations: current.locations,
            groups: current.groups,
            currentIndex: nextIndex
        )
        _lock.lock()
        _result = current
        _lock.unlock()
        fire(result: current, visible: true, currentIndex: nextIndex)
        return current
    }
}
