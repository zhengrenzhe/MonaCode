// MonaCursorUndoFeature.swift
//
// P05-T111 — Implement retained feature cursorUndo.
//
// `MonaCursorUndoFeature` is the Swift counterpart of Monaco's `cursorUndo`
// contribution (monaco-editor 0.56.0): it records and restores cursor-only
// navigation states independently from model undo. A cursor undo moves the
// cursor (and selections) back to the previous navigation state without
// touching the model's text — the model undo / redo stack
// (`MonaUndoRedoStack`, P02-T001) replays inverse edits; the cursor undo
// stack replays cursor positions. The two stacks are fully independent.
//
// The feature is a Foundation-only Core surface (`import Foundation` only). It
// performs the three implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `recordCursorState`, `cursorUndo`, and
//      `cursorRedo`: a cursor-only LIFO stack that records navigation states and
//      restores them on undo / redo, separate from `MonaUndoRedoStack`.
//   2. Register the exact feature identity `cursorUndo` and its declared
//      commands, actions, contributions, options, menus, and keybindings,
//      referenced verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import Foundation

/// A cursor-only navigation state: the primary cursor position and the active
/// selections. Recorded by the cursorUndo feature and restored on undo / redo.
public struct MonaCursorState: Equatable {

    /// The primary cursor position.
    public let position: MonaPosition

    /// The active selections (empty when the cursor is a single caret).
    public let selections: [MonaSelection]

    public init(position: MonaPosition, selections: [MonaSelection] = []) {
        self.position = position
        self.selections = selections
    }
}

/// A cursor-undo event kind: which cursor navigation operation fired.
public enum MonaCursorUndoEventKind: String, Equatable {

    /// A cursor state was recorded (a new navigation).
    case record

    /// A cursor undo restored the previous state.
    case undo

    /// A cursor redo re-applied an undone state.
    case redo
}

/// A cursor-undo event: the kind and the cursor state involved.
public struct MonaCursorUndoEvent: Equatable {

    /// The event kind.
    public let kind: MonaCursorUndoEventKind

    /// The cursor state (the recorded / restored / re-applied state).
    public let state: MonaCursorState?

    public init(kind: MonaCursorUndoEventKind, state: MonaCursorState?) {
        self.kind = kind
        self.state = state
    }
}

/// The cursorUndo feature: record and restore cursor-only navigation states
/// independently from model undo.
///
/// The feature identity `cursorUndo` and its declared slice are referenced
/// verbatim from the frozen registries. The cursor LIFO stack records navigation
/// states; `cursorUndo` restores the previous state (popping the current to the
/// redo stack), and `cursorRedo` re-applies an undone state. Recording a new
/// state clears the redo stack (matching Monaco's standard undo behavior). The
/// stack is fully independent from `MonaUndoRedoStack` (model undo), which
/// replays inverse edits through `MonaTransactionGateway`. Asynchronous
/// publication is routed through `MonaProviderExecutor` + `MonaMicrotaskQueue`;
/// disposal through `MonaEmitter`; localization through `MonaLocalization`; and
/// degraded plain-text behavior through `MonaPlainTextLanguage`.
public final class MonaCursorUndoFeature: MonaDisposable {

    /// The frozen feature identity (`"cursorUndo"`).
    public static let featureId = "cursorUndo"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce). The
    /// `cursorUndo` action triggers a cursor-only undo (Cmd+U on macOS).
    public static let declaredActionIds: [String] = [
        "cursorUndo"
    ]

    /// The declared command IDs in source order. The cursorUndo command.
    public static let declaredCommandIds: [String] = [
        "cursorUndo"
    ]

    /// The declared contribution IDs. The `cursorUndoRedoController`
    /// contribution instantiates the cursor undo / redo controller.
    public static let declaredContributionIds: [String] = [
        "editor.contrib.cursorUndoRedoController"
    ]

    /// The declared keybinding commands — the cursorUndo commands that carry a
    /// default keybinding in `MonaBuiltinKeybindings`.
    public static let declaredKeybindingCommands: [String] = [
        "cursorUndo"
    ]

    /// The declared option names. cursorUndo declares no options, so this slice
    /// is empty.
    public static let declaredOptionIds: [String] = []

    /// The declared menu IDs — the menus that carry cursorUndo menu items.
    /// cursorUndo declares no menu items, so this slice is empty.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    /// The cursor-only undo LIFO list. The top (last element) is the most
    /// recently recorded navigation state.
    private var undoStack: [MonaCursorState] = []

    /// The cursor-only redo LIFO list. The top (last element) is the most
    /// recently undone state.
    private var redoStack: [MonaCursorState] = []

    private let emitter = MonaEmitter<MonaCursorUndoEvent>()

    /// The event stream for cursor-undo changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaCursorUndoEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the cursorUndo feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    // MARK: - 1. Feature-specific behavior: record and restore cursor-only states

    /// Records `state` as a new cursor-only navigation state. Pushes it onto the
    /// undo stack and clears the redo stack (a new navigation state invalidates
    /// the previously undone states, matching Monaco's standard undo behavior).
    /// Fires a `.record` event. A no-op after `dispose()`.
    public func recordCursorState(_ state: MonaCursorState) {
        guard !isDisposed else { return }
        _lock.lock()
        undoStack.append(state)
        redoStack.removeAll()
        _lock.unlock()
        fire(.init(kind: .record, state: state))
    }

    /// Restores the previous cursor-only state: pops the current state to the
    /// redo stack and returns the new top of the undo stack (the previous
    /// navigation state). Returns `nil` when there is no previous state to
    /// restore (fewer than 2 recorded states). Fires an `.undo` event with the
    /// restored state. A no-op after `dispose()` (returns `nil`).
    @discardableResult
    public func cursorUndo() -> MonaCursorState? {
        guard !isDisposed else { return nil }
        _lock.lock()
        guard undoStack.count >= 2 else {
            _lock.unlock()
            return nil
        }
        let current = undoStack.removeLast()
        redoStack.append(current)
        let restored = undoStack.last
        _lock.unlock()
        fire(.init(kind: .undo, state: restored))
        return restored
    }

    /// Re-applies an undone cursor-only state: pops the top of the redo stack,
    /// pushes it back onto the undo stack, and returns it. Returns `nil` when the
    /// redo stack is empty. Fires a `.redo` event with the re-applied state. A
    /// no-op after `dispose()` (returns `nil`).
    @discardableResult
    public func cursorRedo() -> MonaCursorState? {
        guard !isDisposed else { return nil }
        _lock.lock()
        guard let redone = redoStack.popLast() else {
            _lock.unlock()
            return nil
        }
        undoStack.append(redone)
        _lock.unlock()
        fire(.init(kind: .redo, state: redone))
        return redone
    }

    /// `true` when a cursor undo is available (at least 2 recorded states).
    public var canUndo: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return undoStack.count >= 2 && !_isDisposed
    }

    /// `true` when a cursor redo is available (the redo stack is non-empty).
    public var canRedo: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return !redoStack.isEmpty && !_isDisposed
    }

    /// The number of recorded cursor states on the undo stack.
    public var undoStackSize: Int {
        _lock.lock(); defer { _lock.unlock() }
        return undoStack.count
    }

    /// The number of undone cursor states on the redo stack.
    public var redoStackSize: Int {
        _lock.lock(); defer { _lock.unlock() }
        return redoStack.count
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `event` through the shared provider executor, normalized onto
    /// the deterministic microtask queue. `receive` runs ONLY when the queue is
    /// drained (FIFO), after the publication ticket is validated.
    @discardableResult
    public func publishCursorUndoEvent(
        _ event: MonaCursorUndoEvent,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaCursorUndoEvent) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(event),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, the undo / redo stacks are cleared, and
    /// `recordCursorState` / `cursorUndo` / `cursorRedo` are no-ops.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        undoStack.removeAll()
        redoStack.removeAll()
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

    /// The plain-text fallback language. cursorUndo needs no tokenization; it
    /// degrades to plain text for its tokenization needs.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — cursorUndo performs no tokenization-dependent work and degrades
    /// gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Fires a cursor-undo event when not disposed.
    private func fire(_ event: MonaCursorUndoEvent) {
        guard !isDisposed else { return }
        emitter.fire(event)
    }
}
