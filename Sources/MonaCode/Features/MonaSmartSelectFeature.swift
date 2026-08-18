// MonaSmartSelectFeature.swift
//
// P05-T150 — Implement retained feature smartSelect.
//
// `MonaSmartSelectFeature` is the Swift counterpart of Monaco's `smartSelect`
// contribution (monaco-editor 0.56.0, registered as
// `editor.contrib.smartSelectController`): it expands and shrinks the provider's
// selection-range tree while retaining the selection orientation (a forward
// selection stays forward; a backward selection stays backward across expand /
// shrink).
//
// The provider returns a `SelectionRange` tree rooted at the user's current
// selection — `range` is the current selection and `parent` chains outward to
// progressively larger enclosing ranges. Expand walks one step outward (to the
// parent); shrink walks one step inward (back toward the original selection),
// popping the history the expand pass pushed.
//
// Orientation retention reuses `MonaSelection`'s `startPosition`/`endPosition`/
// `orientation` initializer (P01-T002): the expanded / shrunk selection is
// rebuilt from the new range with the SAME orientation the session began with,
// matching Monaco's `Selection.createWithDirection` behavior in the smart-select
// controller.
//
// The `smartSelect` editor option carries `selectLeadingAndTrailingWhitespace`
// and `selectSubwords` (both default `true`); the feature reads these from
// `MonaOptionStore` to decide whether leading/trailing whitespace is folded
// into the expanded range.
//
// The feature is a Foundation-only Core surface (`import Foundation` only). It
// performs the three implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `beginSession(selectionRanges:orientation:)`,
//      `expandedRange(using:)`, `expandSelection(gateway:)`,
//      `shrinkSelection(gateway:)`, `retainOrientation(_:orientation:)`, and
//      `readSmartSelectOptions(using:)`.
//   2. Register the exact feature identity `smartSelect` and its declared
//      commands, actions, contributions, options, menus, and keybindings,
//      referenced verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import Foundation

/// A node in the provider's selection-range tree: the range at this level and
/// its parent (the next-larger enclosing range). Mirrors Monaco's
/// `SelectionRange` (monaco-editor 0.56.0). A reference type so the `parent`
/// link can recurse without boxing.
public final class MonaSmartSelectSelectionRange: Equatable, Hashable {

    /// The range at this level of the tree.
    public let range: MonaRange

    /// The parent selection range (the next-larger enclosing range), or `nil`
    /// at the root of the tree.
    public let parent: MonaSmartSelectSelectionRange?

    public init(range: MonaRange, parent: MonaSmartSelectSelectionRange? = nil) {
        self.range = range
        self.parent = parent
    }

    public static func == (lhs: MonaSmartSelectSelectionRange, rhs: MonaSmartSelectSelectionRange) -> Bool {
        return lhs.range == rhs.range && lhs.parent == rhs.parent
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(range)
        hasher.combine(parent)
    }
}

/// The retained smart-select options read from the `smartSelect` editor option.
public struct MonaSmartSelectOptions: Equatable, Sendable {

    /// Whether to select leading and trailing whitespace when expanding (default
    /// `true`).
    public let selectLeadingAndTrailingWhitespace: Bool

    /// Whether to select subwords when expanding (default `true`).
    public let selectSubwords: Bool

    public init(selectLeadingAndTrailingWhitespace: Bool, selectSubwords: Bool) {
        self.selectLeadingAndTrailingWhitespace = selectLeadingAndTrailingWhitespace
        self.selectSubwords = selectSubwords
    }
}

/// A smart-select event: the current selection after a change.
public struct MonaSmartSelectEvent: Equatable {

    /// The current selection, or `nil` when no session is active.
    public let selection: MonaSelection?

    public init(selection: MonaSelection?) {
        self.selection = selection
    }
}

/// The smartSelect feature: expand and shrink provider selection ranges while
/// retaining orientation.
///
/// The feature identity `smartSelect` and its declared slice are referenced
/// verbatim from the frozen registries. Model mutation (the expanded / shrunk
/// selection) is routed through `MonaTransactionGateway`; asynchronous
/// publication through `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal
/// through `MonaEmitter`; localization through `MonaLocalization`; and degraded
/// plain-text behavior through `MonaPlainTextLanguage`. The orientation is
/// retained across every expand / shrink by rebuilding the selection from the
/// new range with the session's orientation.
public final class MonaSmartSelectFeature: MonaDisposable {

    /// The frozen feature identity (`"smartSelect"`).
    public static let featureId = "smartSelect"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce). The two
    /// labeled smart-select actions: expand and shrink.
    public static let declaredActionIds: [String] = [
        "editor.action.smartSelect.expand",
        "editor.action.smartSelect.shrink"
    ]

    /// The declared command IDs in source order. The smart-select command set:
    /// the expand / grow / shrink commands (`grow` is the internal command
    /// expand delegates to; it carries no action / keybinding of its own).
    public static let declaredCommandIds: [String] = [
        "editor.action.smartSelect.expand",
        "editor.action.smartSelect.grow",
        "editor.action.smartSelect.shrink"
    ]

    /// The declared contribution ID (`editor.contrib.smartSelectController`).
    public static let declaredContributionIds: [String] = [
        "editor.contrib.smartSelectController"
    ]

    /// The declared keybinding commands — the smart-select commands that carry
    /// a default keybinding in `MonaBuiltinKeybindings`, in source order.
    public static let declaredKeybindingCommands: [String] = [
        "editor.action.smartSelect.expand",
        "editor.action.smartSelect.shrink"
    ]

    /// The declared option name — the `smartSelect` option (whether to select
    /// leading/trailing whitespace and subwords, both default `true`).
    public static let declaredOptionIds: [String] = [
        "smartSelect"
    ]

    /// The declared menu IDs — the menus that carry smart-select menu items (the
    /// expand / shrink actions appear in `MenubarSelectionMenu`).
    public static let declaredMenuIds: [String] = [
        "MenubarSelectionMenu"
    ]

    // MARK: - Routing state

    private var _currentNode: MonaSmartSelectSelectionRange? = nil
    private var _orientation: MonaSelectionOrientation = .forward
    private var _history: [MonaSmartSelectSelectionRange] = []
    private let emitter = MonaEmitter<MonaSmartSelectEvent>()

    /// The event stream for smart-select changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaSmartSelectEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the smartSelect feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    /// The current selection range, or `nil` before `beginSession(...)`.
    public var currentRange: MonaRange? {
        _lock.lock(); defer { _lock.unlock() }
        return _currentNode?.range
    }

    /// The current selection (range + retained orientation), or `nil` before
    /// `beginSession(...)`.
    public var currentSelection: MonaSelection? {
        _lock.lock(); defer { _lock.unlock() }
        guard let node = _currentNode else { return nil }
        return MonaSelection(
            startPosition: node.range.startPosition,
            endPosition: node.range.endPosition,
            orientation: _orientation
        )
    }

    // MARK: - 1. Feature-specific behavior: expand / shrink while retaining orientation

    /// Reads the `smartSelect` editor option's sub-fields. A pure query: it
    /// reads the option and never mutates the model. When the option is absent
    /// or a sub-field is missing, the corresponding default is used.
    public func readSmartSelectOptions(using options: MonaOptionStore) -> MonaSmartSelectOptions {
        let object = options.value(for: "smartSelect")?.objectValue ?? [:]
        return MonaSmartSelectOptions(
            selectLeadingAndTrailingWhitespace: object["selectLeadingAndTrailingWhitespace"]?.boolValue ?? true,
            selectSubwords: object["selectSubwords"]?.boolValue ?? true
        )
    }

    /// Begins a smart-select session at `selectionRanges.range` with `orientation`,
    /// clearing the shrink history. Fires an event with the initial selection.
    /// A no-op after `dispose()`.
    public func beginSession(
        selectionRanges: MonaSmartSelectSelectionRange,
        orientation: MonaSelectionOrientation
    ) {
        guard !isDisposed else { return }
        _lock.lock()
        _currentNode = selectionRanges
        _orientation = orientation
        _history = []
        let selection = MonaSelection(
            startPosition: selectionRanges.range.startPosition,
            endPosition: selectionRanges.range.endPosition,
            orientation: orientation
        )
        _lock.unlock()
        emitter.fire(MonaSmartSelectEvent(selection: selection))
    }

    /// Returns the next-larger (parent) range from `selectionRanges`, or `nil`
    /// when `selectionRanges` is at the root. A pure query: it never mutates
    /// state or the model.
    public func expandedRange(
        using selectionRanges: MonaSmartSelectSelectionRange
    ) -> MonaRange? {
        return selectionRanges.parent?.range
    }

    /// Rebuilds a selection from `range` with `orientation`, retaining the
    /// orientation across expand / shrink. Ported from Monaco's
    /// `Selection.createWithDirection` / `fromRange`.
    public func retainOrientation(
        _ range: MonaRange,
        orientation: MonaSelectionOrientation
    ) -> MonaSelection {
        return MonaSelection(
            startPosition: range.startPosition,
            endPosition: range.endPosition,
            orientation: orientation
        )
    }

    /// Expands the selection one step outward through the shared transaction
    /// gateway: pushes the current node onto the shrink history, advances to the
    /// parent, prepares a selection with the retained orientation, and commits.
    /// Returns `.dropped(reason: "at root")` when the current node has no parent;
    /// `.dropped(reason: "disposed")` after `dispose()` or when no session is
    /// active.
    @discardableResult
    public func expandSelection(gateway: MonaTransactionGateway) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        _lock.lock()
        guard let current = _currentNode, let parent = current.parent else {
            _lock.unlock()
            return .dropped(reason: "at root")
        }
        _history.append(current)
        _currentNode = parent
        let orientation = _orientation
        let selection = MonaSelection(
            startPosition: parent.range.startPosition,
            endPosition: parent.range.endPosition,
            orientation: orientation
        )
        _lock.unlock()
        let transaction = gateway.beginTransaction()
        transaction.prepareSelections([selection])
        let outcome = gateway.commit(transaction)
        if case .applied = outcome {
            emitter.fire(MonaSmartSelectEvent(selection: selection))
        }
        return outcome
    }

    /// Shrinks the selection one step inward through the shared transaction
    /// gateway: pops the shrink history, advances back to the previous node,
    /// prepares a selection with the retained orientation, and commits. Returns
    /// `.dropped(reason: "at innermost")` when the history is empty (already at
    /// the original selection); `.dropped(reason: "disposed")` after `dispose()`.
    @discardableResult
    public func shrinkSelection(gateway: MonaTransactionGateway) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        _lock.lock()
        guard let previous = _history.popLast(), let _ = _currentNode else {
            _lock.unlock()
            return .dropped(reason: "at innermost")
        }
        _currentNode = previous
        let orientation = _orientation
        let selection = MonaSelection(
            startPosition: previous.range.startPosition,
            endPosition: previous.range.endPosition,
            orientation: orientation
        )
        _lock.unlock()
        let transaction = gateway.beginTransaction()
        transaction.prepareSelections([selection])
        let outcome = gateway.commit(transaction)
        if case .applied = outcome {
            emitter.fire(MonaSmartSelectEvent(selection: selection))
        }
        return outcome
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `selectionRanges` through the shared provider executor,
    /// normalized onto the deterministic microtask queue. `receive` runs ONLY
    /// when the queue is drained (FIFO), after the publication ticket is
    /// validated. After `dispose()`, returns `false` and publishes nothing.
    @discardableResult
    public func publishSmartSelect(
        _ selectionRanges: MonaSmartSelectSelectionRange,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaSmartSelectSelectionRange) -> Void
    ) -> Bool {
        guard !isDisposed else { return false }
        return executor.publish(
            .synchronous(selectionRanges),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, the session is cleared, and
    /// `beginSession` / `expandSelection` / `shrinkSelection` /
    /// `publishSmartSelect` are no-ops.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        _currentNode = nil
        _history.removeAll()
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

    /// The plain-text fallback language. smartSelect needs no tokenization; it
    /// degrades to plain text for its tokenization needs.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — smartSelect performs no tokenization-dependent work and degrades
    /// gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }
}
