// MonaCaretOperationsFeature.swift
//
// P05-T102 — Implement retained feature caretOperations.
//
// `MonaCaretOperationsFeature` is the Swift counterpart of Monaco's core caret
// / cursor-move commands (monaco-editor 0.56.0): `cursorMove` and the
// `cursorLeft` / `cursorRight` / `cursorUp` / `cursorDown` / `cursorHome` /
// `cursorEnd` / `cursorTop` / `cursorBottom` / `cursorPageUp` /
// `cursorPageDown` / `cursorLineStart` / `cursorLineEnd` family (plus their
// `...Select` and `cursorColumnSelect...` variants). It moves carets by line,
// wrapped line, column, page, viewport, and document boundaries.
//
// When no wrapping / tokenization is registered, wrapped-line movement
// degrades to plain line movement (the `MonaPlainTextLanguage` fallback).
//
// The feature is a Foundation-only Core surface (`import Foundation` only). It
// performs the three implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `moveCaret(_:target:lineCount:maxColumnOf:)`
//      and the multi-caret mover.
//   2. Register the exact feature identity `caretOperations` and its declared
//      commands, actions, contributions, options, menus, and keybindings,
//      referenced verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import Foundation

/// A caret-move target: how far and by which unit a caret moves. Covers line,
/// wrapped line, character (column), page, viewport, and document-boundary
/// movement.
public enum MonaCaretMoveTarget: Equatable {

    /// Move by `n` lines (signed: positive = down, negative = up). The column
    /// is clamped to the destination line's max column.
    case line(Int)

    /// Move by `n` wrapped lines (signed). Degrades to `.line(n)` when no
    /// wrapping / tokenization is registered.
    case wrappedLine(Int)

    /// Move by `n` characters (signed: positive = right, negative = left),
    /// wrapping across line boundaries.
    case character(Int)

    /// Move by `lines` pages of `pageSize` lines each (signed).
    case page(lines: Int, pageSize: Int)

    /// Move to the top line of the viewport (column preserved, clamped).
    case viewPortTop

    /// Move to the center line of the viewport (column preserved, clamped).
    case viewPortCenter

    /// Move to the bottom line of the viewport (column preserved, clamped).
    case viewPortBottom

    /// Move to the start of the document (line 1, column 1).
    case documentStart

    /// Move to the end of the document (last line, last column).
    case documentEnd

    /// Move to the start of the current line (column 1).
    case lineStart

    /// Move to the end of the current line (line's max column).
    case lineEnd
}

/// A caret-movement event: the resulting caret position.
public struct MonaCaretEvent: Equatable {
    /// The caret position after the move.
    public let position: MonaPosition
    public init(position: MonaPosition) {
        self.position = position
    }
}

/// The caretOperations feature: move carets by line, wrapped line, column,
/// page, viewport, and document boundaries.
///
/// The feature identity `caretOperations` and its declared slice are referenced
/// verbatim from the frozen registries. Model mutation is routed through
/// `MonaTransactionGateway`; asynchronous publication through
/// `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal through `MonaEmitter`;
/// localization through `MonaLocalization`; and degraded plain-text line
/// geometry through `MonaPlainTextLanguage`.
public final class MonaCaretOperationsFeature: MonaDisposable {

    /// The frozen feature identity (`"caretOperations"`).
    public static let featureId = "caretOperations"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared command IDs in source order (no rename / coalesce). These
    /// are the core caret / cursor-move commands. `cursorUndo` / `cursorRedo`
    /// belong to the separate `cursorUndo` feature and are excluded; the
    /// `cursorWord*` commands belong to `wordOperations` / `wordPartOperations`
    /// and are also excluded.
    public static let declaredCommandIds: [String] = [
        "cursorBottom",
        "cursorBottomSelect",
        "cursorColumnSelectDown",
        "cursorColumnSelectLeft",
        "cursorColumnSelectPageDown",
        "cursorColumnSelectPageUp",
        "cursorColumnSelectRight",
        "cursorColumnSelectUp",
        "cursorDown",
        "cursorDownSelect",
        "cursorEnd",
        "cursorEndSelect",
        "cursorHome",
        "cursorHomeSelect",
        "cursorLeft",
        "cursorLeftSelect",
        "cursorLineEnd",
        "cursorLineEndSelect",
        "cursorLineStart",
        "cursorLineStartSelect",
        "cursorMove",
        "cursorPageDown",
        "cursorPageDownSelect",
        "cursorPageUp",
        "cursorPageUpSelect",
        "cursorRight",
        "cursorRightSelect",
        "cursorTop",
        "cursorTopSelect",
        "cursorUp",
        "cursorUpSelect"
    ]

    /// The declared action IDs. caretOperations declares pure navigation
    /// commands (no `editor.action.*` entries).
    public static let declaredActionIds: [String] = []

    /// The declared contribution IDs. caretOperations has no contribution
    /// controller (its commands are core navigation commands).
    public static let declaredContributionIds: [String] = []

    /// The declared keybinding commands — every declared command except
    /// `cursorMove`, which carries no default keybinding.
    public static let declaredKeybindingCommands: [String] = {
        return declaredCommandIds.filter { $0 != "cursorMove" }
    }()

    /// The declared option IDs. caretOperations declares no options.
    public static let declaredOptionIds: [String] = []

    /// The declared menu IDs. caretOperations declares no menus.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    private let emitter = MonaEmitter<MonaCaretEvent>()

    /// The event stream for caret movements. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the
    /// listener.
    public var onChange: MonaEvent<MonaCaretEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the caretOperations feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    // MARK: - 1. Feature-specific behavior

    /// Moves `position` according to `target`, using `lineCount` and
    /// `maxColumnOf` (which returns the max 1-based UTF-16 column for a line)
    /// for line geometry, and `viewportTopLine` / `viewportBottomLine` for
    /// viewport movement.
    ///
    /// Returns the resulting caret position. Fires a caret event when not
    /// disposed.
    @discardableResult
    public func moveCaret(
        _ position: MonaPosition,
        target: MonaCaretMoveTarget,
        lineCount: Int,
        maxColumnOf: (Int) -> Int,
        viewportTopLine: Int = 1,
        viewportBottomLine: Int = 1
    ) -> MonaPosition {
        let moved = computeCaretMove(
            position,
            target: target,
            lineCount: lineCount,
            maxColumnOf: maxColumnOf,
            viewportTopLine: viewportTopLine,
            viewportBottomLine: viewportBottomLine
        )
        if !isDisposed {
            emitter.fire(MonaCaretEvent(position: moved))
        }
        return moved
    }

    /// Moves every selection's active position by `target`, preserving each
    /// selection's anchor (for `...Select`-style movement). Returns the new
    /// selections.
    public func moveSelections(
        _ selections: [MonaSelection],
        target: MonaCaretMoveTarget,
        lineCount: Int,
        maxColumnOf: (Int) -> Int,
        viewportTopLine: Int = 1,
        viewportBottomLine: Int = 1
    ) -> [MonaSelection] {
        return selections.map { selection in
            let moved = computeCaretMove(
                selection.activePosition,
                target: target,
                lineCount: lineCount,
                maxColumnOf: maxColumnOf,
                viewportTopLine: viewportTopLine,
                viewportBottomLine: viewportBottomLine
            )
            return MonaSelection(anchor: selection.anchor, activePosition: moved)
        }
    }

    // MARK: - 3a. Model mutation → MonaTransactionGateway

    /// Commits a caret-move transaction through `gateway` as one ordered unit.
    /// The moved caret is recorded as a collapsed selection (anchor == active)
    /// in the gateway's committed selections; the model's text is untouched.
    ///
    /// Returns the gateway's committed selections, or an empty array when the
    /// transaction could not be committed.
    @discardableResult
    public func commitCaretMove(
        _ position: MonaPosition,
        target: MonaCaretMoveTarget,
        gateway: MonaTransactionGateway,
        lineCount: Int,
        maxColumnOf: (Int) -> Int,
        viewportTopLine: Int = 1,
        viewportBottomLine: Int = 1
    ) -> [MonaSelection] {
        let moved = computeCaretMove(
            position,
            target: target,
            lineCount: lineCount,
            maxColumnOf: maxColumnOf,
            viewportTopLine: viewportTopLine,
            viewportBottomLine: viewportBottomLine
        )
        let selection = MonaSelection(anchor: moved, activePosition: moved)
        let transaction = gateway.beginTransaction()
        transaction.prepareSelections([selection])
        let outcome = gateway.commit(transaction)
        switch outcome {
        case .applied, .reconciled:
            return gateway.lastCommittedSelections
        case .dropped, .rolledBack:
            return []
        }
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `position` through the shared provider executor, normalized
    /// onto the deterministic microtask queue. `receive` runs ONLY when the
    /// queue is drained (FIFO), after the publication ticket is validated.
    @discardableResult
    public func publishCaretMove(
        _ position: MonaPosition,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaPosition) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(position),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped and caret events are no longer fired
    /// (movement remains pure and still returns the moved position).
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

    /// Returns the declared command IDs formatted through the shared
    /// `MonaLocalization` surface under `profile`. caretOperations declares no
    /// actions, so its localization surface is its command IDs.
    public func localizedCommandLabels(profile: MonaCodeEnvironmentProfile) -> [String] {
        return Self.declaredCommandIds.map { id in
            MonaLocalization.format(id, args: [], profile: profile)
        }
    }

    // MARK: - 3e. Degraded plain-text → MonaPlainTextLanguage

    /// The plain-text fallback language. caretOperations degrades to plain-text
    /// line geometry (no wrapping) when no tokenization / wrapping is
    /// registered.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — the feature uses plain-text line geometry (no wrapping) until a
    /// wrapping / tokenization provider supplies wrapped-line geometry in a
    /// later phase.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private: caret-move computation (pure)

    /// Computes the moved caret position without firing any event. Pure.
    private func computeCaretMove(
        _ position: MonaPosition,
        target: MonaCaretMoveTarget,
        lineCount: Int,
        maxColumnOf: (Int) -> Int,
        viewportTopLine: Int,
        viewportBottomLine: Int
    ) -> MonaPosition {
        switch target {
        case .line(let n), .wrappedLine(let n):
            // Wrapped-line movement degrades to line movement in plain text.
            let newLine = clamp(position.line + n, lower: 1, upper: max(lineCount, 1))
            let newColumn = min(position.column, maxColumnOf(newLine))
            return MonaPosition(line: newLine, column: newColumn)

        case .character(let n):
            return moveByCharacter(position, delta: n, lineCount: lineCount, maxColumnOf: maxColumnOf)

        case .page(let lines, let pageSize):
            let newLine = clamp(position.line + lines * pageSize, lower: 1, upper: max(lineCount, 1))
            let newColumn = min(position.column, maxColumnOf(newLine))
            return MonaPosition(line: newLine, column: newColumn)

        case .viewPortTop:
            let line = clamp(viewportTopLine, lower: 1, upper: max(lineCount, 1))
            return MonaPosition(line: line, column: min(position.column, maxColumnOf(line)))

        case .viewPortCenter:
            let center = (viewportTopLine + viewportBottomLine) / 2
            let line = clamp(center, lower: 1, upper: max(lineCount, 1))
            return MonaPosition(line: line, column: min(position.column, maxColumnOf(line)))

        case .viewPortBottom:
            let line = clamp(viewportBottomLine, lower: 1, upper: max(lineCount, 1))
            return MonaPosition(line: line, column: min(position.column, maxColumnOf(line)))

        case .documentStart:
            return MonaPosition(line: 1, column: 1)

        case .documentEnd:
            let line = max(lineCount, 1)
            return MonaPosition(line: line, column: maxColumnOf(line))

        case .lineStart:
            return MonaPosition(line: position.line, column: 1)

        case .lineEnd:
            return MonaPosition(line: position.line, column: maxColumnOf(position.line))
        }
    }

    /// Moves `position` by `delta` characters, wrapping across line boundaries.
    /// Positive delta moves right (wrapping to the next line at end-of-line);
    /// negative delta moves left (wrapping to the previous line at
    /// start-of-line). Clamps at the document start and end.
    private func moveByCharacter(
        _ position: MonaPosition,
        delta: Int,
        lineCount: Int,
        maxColumnOf: (Int) -> Int
    ) -> MonaPosition {
        var line = position.line
        var column = position.column
        if delta >= 0 {
            for _ in 0..<delta {
                let maxColumn = maxColumnOf(line)
                if column < maxColumn {
                    column += 1
                } else if line < lineCount {
                    line += 1
                    column = 1
                } else {
                    // At the end of the document; stay.
                    break
                }
            }
        } else {
            let steps = -delta
            for _ in 0..<steps {
                if column > 1 {
                    column -= 1
                } else if line > 1 {
                    line -= 1
                    column = maxColumnOf(line)
                } else {
                    // At the start of the document; stay.
                    break
                }
            }
        }
        return MonaPosition(line: line, column: column)
    }

    /// Clamps `value` to `[lower, upper]`.
    private func clamp(_ value: Int, lower: Int, upper: Int) -> Int {
        return min(max(value, lower), upper)
    }
}
