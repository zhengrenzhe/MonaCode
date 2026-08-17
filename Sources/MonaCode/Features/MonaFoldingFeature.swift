// MonaFoldingFeature.swift
//
// P05-T119 — Implement retained feature folding.
//
// `MonaFoldingFeature` is the Swift counterpart of Monaco's `folding`
// contribution (monaco-editor 0.56.0): it combines the four folding-range
// sources — manual, indentation, marker, and provider — with exact precedence,
// and projects the collapsed ranges onto the view graph's folding API.
//
// Folding is a projection concern: the feature computes the combined foldable
// ranges and the collapsed subset, and emits the collapsed ranges as a
// `[MonaRange]` — the exact shape `MonaViewGraph.setFoldedRanges(_:)` (P03-T001)
// consumes. The Foundation-only feature does not import the AppKit view graph;
// the host wires `graph.setFoldedRanges(feature.foldedRangesProjection())`.
//
// Range precedence (frozen, derived from Monaco's `FoldingController` /
// `HiddenModel`):
//   1. Manual ranges (highest) — always retained; a base or marker range that
//      strictly overlaps a manual range is dropped.
//   2. The strategy-selected base — `foldingStrategy == "indentation"` selects
//      the indentation source; `"auto"` selects the provider source when it is
//      non-empty, otherwise it falls back to indentation.
//   3. Marker ranges (lowest) — always added, except where they strictly
//      overlap a manual or already-added base range.
//
// The feature is a Foundation-only surface (`import Foundation` only — the
// folding types live in the MonaCode module). It performs the three
// implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `combineRanges` / `collapse` / `expand` /
//      `toggleFold` / `foldedRangesProjection`: combine the four sources with
//      exact precedence, track the collapsed subset, and project it as the
//      `[MonaRange]` shape the view graph consumes.
//   2. Register the exact feature identity `folding` and its declared commands,
//      actions, contributions, options, menus, and keybindings, referenced
//      verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import Foundation

/// The source of a folding range.
public enum MonaFoldingRangeSource: String, Equatable, Hashable, Sendable {

    /// A user-created manual range (from `editor.createFoldingRangeFromSelection`).
    case manual

    /// A range computed from line indentation (the indentation strategy or the
    /// auto-strategy fallback when no provider is registered).
    case indentation

    /// A marker region (`#region` / `#endregion`).
    case marker

    /// A range from a registered `FoldingRangeProvider` (the auto strategy).
    case provider
}

/// A foldable range paired with its source.
public struct MonaFoldingRange: Equatable, Hashable {

    /// The foldable range.
    public let range: MonaRange

    /// The source the range came from.
    public let source: MonaFoldingRangeSource

    public init(range: MonaRange, source: MonaFoldingRangeSource) {
        self.range = range
        self.source = source
    }
}

/// A folding event: the combined range count and the collapsed count.
public struct MonaFoldingEvent: Equatable {

    /// The number of combined foldable ranges.
    public let rangeCount: Int

    /// The number of currently-collapsed ranges.
    public let collapsedCount: Int

    public init(rangeCount: Int, collapsedCount: Int) {
        self.rangeCount = rangeCount
        self.collapsedCount = collapsedCount
    }
}

/// The folding feature: combine manual, indentation, marker, and provider
/// folding ranges with exact precedence, and project the collapsed subset.
///
/// The feature identity `folding` and its declared slice are referenced verbatim
/// from the frozen registries. The combined ranges are computed by
/// `combineRanges(manual:indentation:marker:provider:strategy:)`; the collapsed
/// subset is tracked by `collapse` / `expand` / `toggleFold` and projected by
/// `foldedRangesProjection()` as the `[MonaRange]` shape
/// `MonaViewGraph.setFoldedRanges(_:)` consumes. Model mutation is routed
/// through `MonaTransactionGateway`; asynchronous publication through
/// `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal through `MonaEmitter`;
/// localization through `MonaLocalization`; and degraded plain-text behavior
/// through `MonaPlainTextLanguage`.
public final class MonaFoldingFeature: MonaDisposable {

    /// The frozen feature identity (`"folding"`).
    public static let featureId = "folding"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce). The 26
    /// folding actions registered by the folding contribution (ordinals 37–62).
    public static let declaredActionIds: [String] = [
        "editor.unfold",
        "editor.unfoldRecursively",
        "editor.fold",
        "editor.foldRecursively",
        "editor.toggleFoldRecursively",
        "editor.foldAll",
        "editor.unfoldAll",
        "editor.foldAllBlockComments",
        "editor.foldAllMarkerRegions",
        "editor.unfoldAllMarkerRegions",
        "editor.foldAllExcept",
        "editor.unfoldAllExcept",
        "editor.toggleFold",
        "editor.gotoParentFold",
        "editor.gotoPreviousFold",
        "editor.gotoNextFold",
        "editor.createFoldingRangeFromSelection",
        "editor.removeManualFoldingRanges",
        "editor.toggleImportFold",
        "editor.foldLevel1",
        "editor.foldLevel2",
        "editor.foldLevel3",
        "editor.foldLevel4",
        "editor.foldLevel5",
        "editor.foldLevel6",
        "editor.foldLevel7"
    ]

    /// The declared command IDs in source order. The 26 folding actions are all
    /// registered as editor commands, so this slice equals `declaredActionIds`.
    public static let declaredCommandIds: [String] = declaredActionIds

    /// The declared contribution ID. The `editor.contrib.folding` contribution
    /// instantiates the folding controller.
    public static let declaredContributionIds: [String] = [
        "editor.contrib.folding"
    ]

    /// The declared keybinding commands — the 22 folding commands that carry a
    /// default keybinding in `MonaBuiltinKeybindings`. The four navigation /
    /// import-toggle commands (`editor.gotoParentFold`,
    /// `editor.gotoPreviousFold`, `editor.gotoNextFold`,
    /// `editor.toggleImportFold`) carry no default keybinding.
    public static let declaredKeybindingCommands: [String] = [
        "editor.unfold",
        "editor.unfoldRecursively",
        "editor.fold",
        "editor.foldRecursively",
        "editor.toggleFoldRecursively",
        "editor.foldAll",
        "editor.unfoldAll",
        "editor.foldAllBlockComments",
        "editor.foldAllMarkerRegions",
        "editor.unfoldAllMarkerRegions",
        "editor.foldAllExcept",
        "editor.unfoldAllExcept",
        "editor.toggleFold",
        "editor.createFoldingRangeFromSelection",
        "editor.removeManualFoldingRanges",
        "editor.foldLevel1",
        "editor.foldLevel2",
        "editor.foldLevel3",
        "editor.foldLevel4",
        "editor.foldLevel5",
        "editor.foldLevel6",
        "editor.foldLevel7"
    ]

    /// The declared option names — the five folding options.
    public static let declaredOptionIds: [String] = [
        "folding",
        "foldingStrategy",
        "foldingHighlight",
        "foldingImportsByDefault",
        "foldingMaximumRegions"
    ]

    /// The declared menu IDs — folding registers no menu items in any builtin
    /// menu, so this slice is empty.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    private let emitter = MonaEmitter<MonaFoldingEvent>()

    /// The event stream for folding changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaFoldingEvent> { emitter.event }

    /// The combined foldable ranges from the most recent `combineRanges` call.
    private var combinedRanges: [MonaFoldingRange] = []

    /// The currently-collapsed ranges (insertion order ignored; projected sorted).
    private var collapsedRanges: Set<MonaRange> = []

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the folding feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    // MARK: - 1. Feature-specific behavior: combine ranges with exact precedence

    /// Combines the four folding-range sources with exact precedence:
    /// manual > strategy-selected base > marker.
    ///
    /// - Parameters:
    ///   - manual: user-created manual ranges (highest precedence).
    ///   - indentation: indentation-computed ranges (the indentation strategy or
    ///     the auto-strategy fallback).
    ///   - marker: marker-region ranges (`#region` / `#endregion`).
    ///   - provider: provider-supplied ranges (the auto strategy).
    ///   - strategy: `"auto"` (provider if non-empty, else indentation) or
    ///     `"indentation"` (indentation only).
    /// - Returns: the combined ranges sorted by start position. A base or marker
    ///   range that strictly overlaps a higher-precedence range is dropped.
    ///   Empty when the feature is disposed.
    public func combineRanges(
        manual: [MonaRange],
        indentation: [MonaRange],
        marker: [MonaRange],
        provider: [MonaRange],
        strategy: String
    ) -> [MonaFoldingRange] {
        guard !isDisposed else { return [] }

        // 1. Select the strategy base.
        let base: [MonaRange]
        if strategy == "indentation" {
            base = indentation
        } else {
            // "auto": provider when non-empty, else indentation fallback.
            base = provider.isEmpty ? indentation : provider
        }

        // 2. Compose with precedence: manual (highest) > base > marker (lowest).
        var result: [MonaFoldingRange] = []
        result.reserveCapacity(manual.count + base.count + marker.count)
        for r in manual {
            result.append(MonaFoldingRange(range: r, source: .manual))
        }
        // Base ranges that do not strictly overlap any manual range.
        for r in base where !overlapsHigherPrecedence(r, higher: result) {
            result.append(MonaFoldingRange(range: r, source: baseSource(for: strategy, provider: provider)))
        }
        // Marker ranges that do not strictly overlap any manual or base range.
        for r in marker where !overlapsHigherPrecedence(r, higher: result) {
            result.append(MonaFoldingRange(range: r, source: .marker))
        }

        // 3. Sort by start position (stable for equal starts).
        result.sort {
            if $0.range.startPosition != $1.range.startPosition {
                return $0.range.startPosition < $1.range.startPosition
            }
            return $0.range.endPosition < $1.range.endPosition
        }

        _lock.lock()
        combinedRanges = result
        _lock.unlock()
        return result
    }

    /// Returns the source label for the strategy-selected base ranges.
    private func baseSource(for strategy: String, provider: [MonaRange]) -> MonaFoldingRangeSource {
        if strategy == "indentation" { return .indentation }
        return provider.isEmpty ? .indentation : .provider
    }

    /// Returns `true` when `range` strictly overlaps any range in `higher`
    /// (the higher-precedence ranges already added).
    private func overlapsHigherPrecedence(_ range: MonaRange, higher: [MonaFoldingRange]) -> Bool {
        for entry in higher where range.areIntersecting(entry.range) {
            return true
        }
        return false
    }

    // MARK: - Collapse / expand / toggle (projection onto MonaViewGraph)

    /// Collapses `range` (marks it as folded). A no-op after `dispose()`. Fires
    /// a folding event.
    public func collapse(_ range: MonaRange) {
        guard !isDisposed else { return }
        _lock.lock()
        let inserted = collapsedRanges.insert(range).inserted
        let rangeCount = combinedRanges.count
        let collapsedCount = collapsedRanges.count
        _lock.unlock()
        if inserted {
            fire(.init(rangeCount: rangeCount, collapsedCount: collapsedCount))
        }
    }

    /// Expands `range` (un-marks it as folded). A no-op after `dispose()`. Fires
    /// a folding event when the range was collapsed.
    public func expand(_ range: MonaRange) {
        guard !isDisposed else { return }
        _lock.lock()
        let removed = collapsedRanges.remove(range) != nil
        let rangeCount = combinedRanges.count
        let collapsedCount = collapsedRanges.count
        _lock.unlock()
        if removed {
            fire(.init(rangeCount: rangeCount, collapsedCount: collapsedCount))
        }
    }

    /// Toggles the collapsed state of `range`. A no-op after `dispose()`. Fires
    /// a folding event.
    public func toggleFold(_ range: MonaRange) {
        guard !isDisposed else { return }
        _lock.lock()
        if collapsedRanges.contains(range) {
            collapsedRanges.remove(range)
        } else {
            collapsedRanges.insert(range)
        }
        let rangeCount = combinedRanges.count
        let collapsedCount = collapsedRanges.count
        _lock.unlock()
        fire(.init(rangeCount: rangeCount, collapsedCount: collapsedCount))
    }

    /// The collapsed ranges projected as a `[MonaRange]` — the exact shape
    /// `MonaViewGraph.setFoldedRanges(_:)` (P03-T001) consumes. Sorted by start
    /// position so the projection is deterministic across insertion order.
    public func foldedRangesProjection() -> [MonaRange] {
        _lock.lock()
        let snapshot = collapsedRanges
        _lock.unlock()
        return snapshot.sorted {
            if $0.startPosition != $1.startPosition {
                return $0.startPosition < $1.startPosition
            }
            return $0.endPosition < $1.endPosition
        }
    }

    // MARK: - 3a. Mutation → MonaTransactionGateway

    /// Routes a fold-toggle through the shared transaction gateway: begins a
    /// transaction, prepares a collapsed selection at the range's start position
    /// (the fold anchor), and commits the unit. Returns the committed
    /// selections (empty when the feature is disposed or the commit dropped).
    @discardableResult
    public func commitFoldToggle(
        gateway: MonaTransactionGateway,
        range: MonaRange
    ) -> [MonaSelection] {
        guard !isDisposed else { return [] }
        let tx = gateway.beginTransaction()
        let selection = MonaSelection(anchor: range.startPosition, activePosition: range.startPosition)
        tx.prepareSelections([selection])
        _ = gateway.commit(tx)
        return gateway.lastCommittedSelections
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `ranges` through the shared provider executor, normalized onto
    /// the deterministic microtask queue. `receive` runs ONLY when the queue is
    /// drained (FIFO), after the publication ticket is validated.
    @discardableResult
    public func publishFoldingRanges(
        _ ranges: [MonaFoldingRange],
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping ([MonaFoldingRange]) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(ranges),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped and `combineRanges` / `collapse` /
    /// `expand` / `toggleFold` / `commitFoldToggle` are no-ops.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        _lock.unlock()
        if !already {
            emitter.dispose()
        }
    }

    // MARK: - 3d. Localization → MonaLocalization

    /// Returns the declared action labels formatted through the shared
    /// `MonaLocalization` surface under `profile`.
    public func localizedActionLabels(profile: MonaCodeEnvironmentProfile) -> [String] {
        let registry = MonaActionRegistry()
        return Self.declaredActionIds.map { id in
            let label = registry.identity(for: id)?.label ?? id
            return MonaLocalization.format(label, args: [], profile: profile)
        }
    }

    // MARK: - 3e. Degraded plain-text → MonaPlainTextLanguage

    /// The plain-text fallback language. folding degrades to the indentation
    /// (plain-text) strategy when no provider is registered — the indentation
    /// fallback is the plain-text folding strategy.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — folding degrades gracefully to the indentation (plain-text)
    /// strategy when no `FoldingRangeProvider` is registered.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Fires a folding event when not disposed.
    private func fire(_ event: MonaFoldingEvent) {
        guard !isDisposed else { return }
        emitter.fire(event)
    }
}
