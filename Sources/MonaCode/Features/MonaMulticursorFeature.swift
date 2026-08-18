// MonaMulticursorFeature.swift
//
// P05-T139 — Implement retained feature multicursor.
//
// `MonaMulticursorFeature` is the Swift counterpart of Monaco's `multicursor`
// contribution (monaco-editor 0.56.0): it manages a stable, ascending-ordered
// collection of cursors and replicates a single edit across every cursor as ONE
// all-or-none transaction. Add records a cursor (merging duplicates when
// `multiCursorMergeOverlapping` is on, the default), remove drops a cursor,
// merge deduplicates cursors at the same position, select replaces the cursor
// set with a sorted-unique batch, and edit replicates a plain-text insertion at
// every cursor through `MonaMultiCursorInputPlan.replicateText` committed by
// `MonaModelInputBarrier` (P04-T005) — the multi-cursor all-or-none transaction
// gateway. Any overlap / validation failure rolls back the whole batch, leaving
// the model untouched.
//
// The cursor list is kept in stable ascending (line, column) order at all
// times, so 1, 100, and 10000 cursors observe a deterministic ordering with no
// O(n²) catastrophe: `select` / `addCursor` use binary-searched insertion, and
// the edit path delegates ordering to the plan + barrier (O(n log n)).
//
// The feature is a Foundation-only Core surface (`import Foundation` only). It
// performs the three implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `addCursor`, `removeCursor`,
//      `removeSecondaryCursors`, `mergeOverlappingCursors`, `select`, and
//      `editAll`, with stable ascending cursor order.
//   2. Register the exact feature identity `multicursor` and its declared
//      commands, actions, contributions, options, menus, and keybindings,
//      referenced verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaModelInputBarrier` + `MonaMultiCursorInputPlan` (mutation),
//      `MonaProviderExecutor` + `MonaMicrotaskQueue` (async publication),
//      `MonaEmitter` (disposal), `MonaLocalization` (localization), and
//      `MonaPlainTextLanguage` (degraded plain text). No parallel mechanisms
//      are introduced.

import Foundation

/// A multicursor change event: the stable ascending cursor list after a
/// change, and the number of cursors affected by the change.
public struct MonaMulticursorEvent: Equatable {

    /// The cursor positions after the change, in ascending (line, column) order.
    public let cursors: [MonaPosition]

    /// The number of cursors affected by this change (added, removed, or
    /// retained depending on the operation).
    public let affectedCount: Int

    public init(cursors: [MonaPosition], affectedCount: Int) {
        self.cursors = cursors
        self.affectedCount = affectedCount
    }
}

/// The multicursor feature: a stable, ascending-ordered cursor collection plus
/// all-or-none replicated edits across every cursor.
///
/// The feature identity `multicursor` and its declared slice are referenced
/// verbatim from the frozen registries. Model mutation is routed through
/// `MonaModelInputBarrier` + `MonaMultiCursorInputPlan` (the all-or-none
/// multi-cursor transaction gateway, P04-T005); asynchronous publication
/// through `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal through
/// `MonaEmitter`; localization through `MonaLocalization`; and degraded
/// plain-text behavior through `MonaPlainTextLanguage`.
public final class MonaMulticursorFeature: MonaDisposable {

    /// The frozen feature identity (`"multicursor"`).
    public static let featureId = "multicursor"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce). These are
    /// the labeled multi-cursor actions registered by the multiCursorController
    /// contribution (ordinals 140–152).
    public static let declaredActionIds: [String] = [
        "editor.action.insertCursorAbove",
        "editor.action.insertCursorBelow",
        "editor.action.insertCursorAtEndOfEachLineSelected",
        "editor.action.addSelectionToNextFindMatch",
        "editor.action.addSelectionToPreviousFindMatch",
        "editor.action.moveSelectionToNextFindMatch",
        "editor.action.moveSelectionToPreviousFindMatch",
        "editor.action.selectHighlights",
        "editor.action.changeAll",
        "editor.action.addCursorsToBottom",
        "editor.action.addCursorsToTop",
        "editor.action.focusNextCursor",
        "editor.action.focusPreviousCursor"
    ]

    /// The declared command IDs in source order. The multi-cursor command set is
    /// the 13 labeled actions plus `removeSecondaryCursors` (a command that
    /// carries no action label).
    public static let declaredCommandIds: [String] = declaredActionIds + [
        "removeSecondaryCursors"
    ]

    /// The declared contribution ID (`editor.contrib.multiCursorController`).
    public static let declaredContributionIds: [String] = [
        "editor.contrib.multiCursorController"
    ]

    /// The declared keybinding commands — the multi-cursor commands that carry a
    /// default keybinding in `MonaBuiltinKeybindings`, in source order.
    public static let declaredKeybindingCommands: [String] = [
        "editor.action.insertCursorAbove",
        "editor.action.insertCursorBelow",
        "editor.action.insertCursorAtEndOfEachLineSelected",
        "editor.action.addSelectionToNextFindMatch",
        "editor.action.moveSelectionToNextFindMatch",
        "editor.action.selectHighlights",
        "editor.action.changeAll",
        "removeSecondaryCursors"
    ]

    /// The declared option names — the four multi-cursor editor options
    /// (`multiCursorMergeOverlapping`, `multiCursorModifier`, `multiCursorPaste`,
    /// `multiCursorLimit`).
    public static let declaredOptionIds: [String] = [
        "multiCursorMergeOverlapping",
        "multiCursorModifier",
        "multiCursorPaste",
        "multiCursorLimit"
    ]

    /// The declared menu IDs — the menus that carry multi-cursor menu items.
    /// The add-cursor / add-selection actions appear in `MenubarSelectionMenu`
    /// (group `3_multi`); `changeAll` appears in `EditorContext`.
    public static let declaredMenuIds: [String] = [
        "MenubarSelectionMenu",
        "EditorContext"
    ]

    // MARK: - Routing state

    /// The cursor positions in stable ascending (line, column) order. Kept
    /// sorted + de-duplicated (when merging is on) at all times.
    private var _cursors: [MonaPosition] = []

    /// `true` when overlapping cursors at the same position merge (the
    /// `multiCursorMergeOverlapping` option default is `true`).
    private let mergeOverlapping: Bool

    private let emitter = MonaEmitter<MonaMulticursorEvent>()

    /// The event stream for cursor changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaMulticursorEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the multicursor feature.
    /// - Parameter mergeOverlapping: `true` to merge cursors at the same
    ///   position (the `multiCursorMergeOverlapping` option default is `true`).
    public init(mergeOverlapping: Bool = true) {
        self.mergeOverlapping = mergeOverlapping
    }

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    /// The cursor positions in stable ascending (line, column) order.
    public var cursors: [MonaPosition] {
        _lock.lock(); defer { _lock.unlock() }
        return _cursors
    }

    /// The number of cursors.
    public var cursorCount: Int {
        _lock.lock(); defer { _lock.unlock() }
        return _cursors.count
    }

    /// The primary cursor — the first (smallest-position) cursor, or `nil` when
    /// there are no cursors.
    public var primaryCursor: MonaPosition? {
        _lock.lock(); defer { _lock.unlock() }
        return _cursors.first
    }

    // MARK: - 1. Feature-specific behavior: add / remove / merge / select / edit

    /// Adds a cursor at `position`, keeping the cursor list in stable ascending
    /// order. When `mergeOverlapping` is on (the default), a cursor already at
    /// `position` is merged (no duplicate inserted). Fires a change event.
    /// Returns the cursor list after the add. After `dispose()`, this is a
    /// no-op returning an empty array.
    @discardableResult
    public func addCursor(_ position: MonaPosition) -> [MonaPosition] {
        guard !isDisposed else { return [] }
        _lock.lock()
        let inserted = insertSorted(_cursors, position: position, merge: mergeOverlapping)
        _cursors = inserted.list
        let affected = inserted.added ? 1 : 0
        let snapshot = _cursors
        _lock.unlock()
        fire(snapshot, affected: affected)
        return snapshot
    }

    /// Removes the cursor at `position` (exact match). Returns `true` when a
    /// cursor was removed. Fires a change event. After `dispose()`, returns
    /// `false` and fires no event.
    @discardableResult
    public func removeCursor(at position: MonaPosition) -> Bool {
        guard !isDisposed else { return false }
        _lock.lock()
        guard let idx = _cursors.firstIndex(of: position) else {
            _lock.unlock()
            return false
        }
        _cursors.remove(at: idx)
        let snapshot = _cursors
        _lock.unlock()
        fire(snapshot, affected: 1)
        return true
    }

    /// Removes every cursor except the primary (the first / smallest-position
    /// cursor). Returns the number of secondary cursors removed. After
    /// `dispose()`, returns `0` and fires no event.
    @discardableResult
    public func removeSecondaryCursors() -> Int {
        guard !isDisposed else { return 0 }
        _lock.lock()
        let removed = max(_cursors.count - 1, 0)
        if !_cursors.isEmpty {
            _cursors = [_cursors[0]]
        }
        let snapshot = _cursors
        _lock.unlock()
        if removed > 0 {
            fire(snapshot, affected: removed)
        }
        return removed
    }

    /// Merges cursors at the same position (deduplicates), keeping the stable
    /// ascending order. Returns the number of duplicate cursors removed. After
    /// `dispose()`, returns `0` and fires no event.
    @discardableResult
    public func mergeOverlappingCursors() -> Int {
        guard !isDisposed else { return 0 }
        _lock.lock()
        let unique = dedupeSorted(_cursors)
        let removed = _cursors.count - unique.count
        _cursors = unique
        let snapshot = _cursors
        _lock.unlock()
        if removed > 0 {
            fire(snapshot, affected: removed)
        }
        return removed
    }

    /// Replaces the cursor set with `positions`, sorted ascending and (when
    /// merging is on) de-duplicated. Fires a change event. After `dispose()`,
    /// this is a no-op. Returns the cursor list after the select.
    @discardableResult
    public func select(_ positions: [MonaPosition]) -> [MonaPosition] {
        guard !isDisposed else { return [] }
        _lock.lock()
        let sorted = positions.sorted()
        _cursors = mergeOverlapping ? dedupeSorted(sorted) : sorted
        let snapshot = _cursors
        _lock.unlock()
        fire(snapshot, affected: snapshot.count)
        return snapshot
    }

    /// Replicates a plain-text insertion at every cursor, committing ALL cursor
    /// edits as ONE all-or-none transaction through `MonaModelInputBarrier`
    /// (P04-T005) + `MonaMultiCursorInputPlan`. Any overlap rejection or
    /// validation failure rolls back the whole batch, leaving the model
    /// untouched. Returns the barrier outcome. After `dispose()`, or when there
    /// are no cursors, returns `.dropped`.
    @discardableResult
    public func editAll(
        text: String,
        model: MonaCodeModel,
        overlapPolicy: MonaOverlapPolicy = .reject
    ) -> MonaModelInputBarrierOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let positions = cursors
        guard !positions.isEmpty else { return .dropped(reason: "no cursors") }
        let plan = MonaMultiCursorInputPlan.replicateText(
            cursorPositions: positions,
            text: text
        )
        let barrier = MonaModelInputBarrier(model: model)
        return barrier.commit(plan, overlapPolicy: overlapPolicy)
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `cursors` through the shared provider executor, normalized onto
    /// the deterministic microtask queue. `receive` runs ONLY when the queue is
    /// drained (FIFO), after the publication ticket is validated. After
    /// `dispose()`, returns `false` and publishes nothing.
    @discardableResult
    public func publishCursors(
        _ cursors: [MonaPosition],
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping ([MonaPosition]) -> Void
    ) -> Bool {
        guard !isDisposed else { return false }
        return executor.publish(
            .synchronous(cursors),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, the cursor list is cleared, and
    /// `addCursor` / `select` / `editAll` / `publishCursors` are no-ops.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        _cursors.removeAll()
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

    /// The plain-text fallback language. multicursor needs no tokenization; it
    /// degrades to plain text for its tokenization needs.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — multicursor performs no tokenization-dependent work and degrades
    /// gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Fires a multicursor event when not disposed.
    private func fire(_ cursors: [MonaPosition], affected: Int) {
        guard !isDisposed else { return }
        emitter.fire(MonaMulticursorEvent(cursors: cursors, affectedCount: affected))
    }

    /// Binary-searched insertion of `position` into a sorted list. When `merge`
    /// is `true` and `position` is already present, no duplicate is inserted
    /// (`added` = `false`). Returns the new list and whether an entry was added.
    private func insertSorted(
        _ list: [MonaPosition],
        position: MonaPosition,
        merge: Bool
    ) -> (list: [MonaPosition], added: Bool) {
        // Binary search for the insertion point (first element > position).
        var lo = 0
        var hi = list.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if list[mid] < position {
                lo = mid + 1
            } else {
                hi = mid
            }
        }
        // lo == insertion point. If the element at lo equals position, merge.
        if lo < list.count && list[lo] == position {
            return (list, false) // merged / already present
        }
        var copy = list
        copy.insert(position, at: lo)
        return (copy, true)
    }

    /// De-duplicates a sorted list in place (keeping the first of each run).
    private func dedupeSorted(_ list: [MonaPosition]) -> [MonaPosition] {
        guard list.count > 1 else { return list }
        var result: [MonaPosition] = []
        result.reserveCapacity(list.count)
        var last: MonaPosition? = nil
        for position in list {
            if position != last {
                result.append(position)
                last = position
            }
        }
        return result
    }
}
