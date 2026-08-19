// Sources/MonaCode/Input/MonaCommandDispatcher.swift
import Foundation

public struct MonaCommandContext {
    public let model: MonaCodeModel
    public let inputBarrier: MonaModelInputBarrier
    public let transactionGateway: MonaTransactionGateway
    public let caretOps: MonaCaretOperationsFeature
    public let args: Any?
    public init(model: MonaCodeModel, inputBarrier: MonaModelInputBarrier,
                transactionGateway: MonaTransactionGateway,
                caretOps: MonaCaretOperationsFeature, args: Any?) {
        self.model = model; self.inputBarrier = inputBarrier
        self.transactionGateway = transactionGateway; self.caretOps = caretOps; self.args = args
    }
}

public final class MonaCommandDispatcher {
    private let model: MonaCodeModel
    private let inputBarrier: MonaModelInputBarrier
    private let transactionGateway: MonaTransactionGateway
    private let caretOps: MonaCaretOperationsFeature
    private var handlers: [String: (MonaCommandContext, Any?) -> Void] = [:]

    public init(model: MonaCodeModel, inputBarrier: MonaModelInputBarrier,
                transactionGateway: MonaTransactionGateway,
                caretOps: MonaCaretOperationsFeature) {
        self.model = model; self.inputBarrier = inputBarrier
        self.transactionGateway = transactionGateway; self.caretOps = caretOps
        registerCoreCommands()
    }
    public func register(_ commandId: String, handler: @escaping (MonaCommandContext, Any?) -> Void) {
        handlers[commandId] = handler
    }
    public func contains(_ commandId: String) -> Bool { handlers[commandId] != nil }
    @discardableResult
    public func execute(_ commandId: String, args: Any? = nil) -> Bool {
        guard let handler = handlers[commandId] else { return false }
        handler(MonaCommandContext(model: model, inputBarrier: inputBarrier,
                                  transactionGateway: transactionGateway,
                                  caretOps: caretOps, args: args), args)
        return true
    }

    // MARK: - Core command registration

    /// Registers the built-in core commands. Called once from `init`. Task 3
    /// registers `type`; the remaining core commands are registered by their
    /// owning tasks (T4–T8).
    private func registerCoreCommands() {
        register("type") { ctx, args in Self.typeCommand(ctx, args: args) }
        register("deleteLeft") { ctx, _ in Self.deleteLeft(ctx) }
        register("deleteRight") { ctx, _ in Self.deleteRight(ctx) }
        register("cursorLeft")  { ctx, _ in Self.cursorMove(ctx, target: .character(-1)) }
        register("cursorRight") { ctx, _ in Self.cursorMove(ctx, target: .character(1)) }
    }

    // MARK: - type

    /// The `type` command: inserts `args["text"]` at every active cursor,
    /// replacing each selection's range. The first selection is the primary
    /// cursor; the rest are secondary. Mirrors Monaco's `type` command, which
    /// routes a typed character through the cursor controller's edit batch.
    private static func typeCommand(_ ctx: MonaCommandContext, args: Any?) {
        guard let text = (args as? [String: String])?["text"] else { return }
        let sels = currentSelections(ctx)
        guard let primary = sels.first.map({ MonaCursorInputEdit(range: MonaRange(startPosition: $0.anchor, endPosition: $0.activePosition), text: text) }) else { return }
        let secondary = sels.dropFirst().map { MonaCursorInputEdit(range: MonaRange(startPosition: $0.anchor, endPosition: $0.activePosition), text: text) }
        _ = ctx.inputBarrier.commit(MonaMultiCursorInputPlan(primary: primary, secondary: secondary), overlapPolicy: .reject)
    }

    // MARK: - deleteLeft

    /// The `deleteLeft` command: deletes the character or selection to the left
    /// of each active cursor. An empty selection at `(line, col)` deletes the
    /// previous column on the same line; at column 1 with `line > 1` it joins
    /// the previous line (deletes from the previous line's max column to the
    /// current line's column 1, removing the newline); at line 1 column 1 it is
    /// a no-op. A non-empty selection deletes its content. Mirrors Monaco's
    /// `deleteLeft` command, which routes a backward delete through the cursor
    /// controller's edit batch.
    private static func deleteLeft(_ ctx: MonaCommandContext) {
        let sels = currentSelections(ctx)
        let lineCount = ctx.model.getLineCount()
        let maxCol = { ctx.model.getLineMaxColumn($0) }
        let edits = sels.compactMap { sel -> MonaCursorInputEdit? in
            guard let range = deleteLeftRange(sel, lineCount: lineCount, maxColumnOf: maxCol) else { return nil }
            return MonaCursorInputEdit(range: range, text: "")
        }
        guard let primary = edits.first else { return }
        _ = ctx.inputBarrier.commit(
            MonaMultiCursorInputPlan(primary: primary, secondary: Array(edits.dropFirst())),
            overlapPolicy: .reject)
    }

    /// Pure: the range `deleteLeft` removes at the given selection, or `nil`
    /// when it is a no-op.
    ///
    /// - Non-empty selection (`!range.isFolded`) → delete its content.
    /// - Caret at `column > 1` → delete the previous column on the same line.
    /// - Caret at column 1, `line > 1` → join the previous line: delete from
    ///   the previous line's max column (EOL position, `length + 1`) to the
    ///   current line's column 1, removing the newline.
    /// - Caret at line 1 column 1 → `nil` (no-op).
    static func deleteLeftRange(
        _ sel: MonaSelection,
        lineCount: Int,
        maxColumnOf: (Int) -> Int
    ) -> MonaRange? {
        let range = MonaRange(startPosition: sel.anchor, endPosition: sel.activePosition)   // normalized
        if !range.isFolded { return range }                                                 // delete selection content
        let pos = sel.activePosition
        if pos.column > 1 {
            return MonaRange(startLine: pos.line, startColumn: pos.column - 1,
                             endLine: pos.line, endColumn: pos.column)
        }
        if pos.line > 1 {
            let prevMaxCol = maxColumnOf(pos.line - 1)                                       // length+1 (EOL position)
            return MonaRange(startLine: pos.line - 1, startColumn: prevMaxCol,
                             endLine: pos.line, endColumn: 1)
        }
        return nil                                                                            // line 1 col 1: no-op
    }

    // MARK: - deleteRight

    /// The `deleteRight` command: deletes the character or selection to the
    /// right of each active cursor. An empty selection at `(line, col)` deletes
    /// the next column on the same line; at the line's max column (`length + 1`)
    /// with `line < lineCount` it joins the next line (deletes from the caret
    /// to the next line's column 1, removing the newline); at the last line's
    /// end it is a no-op. A non-empty selection deletes its content. Mirrors
    /// Monaco's `deleteRight` command, which routes a forward delete through
    /// the cursor controller's edit batch.
    private static func deleteRight(_ ctx: MonaCommandContext) {
        let sels = currentSelections(ctx)
        let lineCount = ctx.model.getLineCount()
        let maxCol = { ctx.model.getLineMaxColumn($0) }
        let edits = sels.compactMap { sel -> MonaCursorInputEdit? in
            guard let range = deleteRightRange(sel, lineCount: lineCount, maxColumnOf: maxCol) else { return nil }
            return MonaCursorInputEdit(range: range, text: "")
        }
        guard let primary = edits.first else { return }
        _ = ctx.inputBarrier.commit(
            MonaMultiCursorInputPlan(primary: primary, secondary: Array(edits.dropFirst())),
            overlapPolicy: .reject)
    }

    /// Pure: the range `deleteRight` removes at the given selection, or `nil`
    /// when it is a no-op.
    ///
    /// - Non-empty selection (`!range.isFolded`) → delete its content.
    /// - Caret at `column < maxCol` → delete the next column on the same line.
    /// - Caret at max column, `line < lineCount` → join the next line: delete
    ///   from the current line's max column (EOL position, `length + 1`) to
    ///   the next line's column 1, removing the newline.
    /// - Caret at last line end (`line == lineCount` && `column == maxCol`)
    ///   → `nil` (no-op).
    static func deleteRightRange(
        _ sel: MonaSelection,
        lineCount: Int,
        maxColumnOf: (Int) -> Int
    ) -> MonaRange? {
        let range = MonaRange(startPosition: sel.anchor, endPosition: sel.activePosition)   // normalized
        if !range.isFolded { return range }                                                 // delete selection content
        let pos = sel.activePosition
        let maxCol = maxColumnOf(pos.line)                                                  // length+1 (EOL position)
        if pos.column < maxCol {
            return MonaRange(startLine: pos.line, startColumn: pos.column,
                             endLine: pos.line, endColumn: pos.column + 1)
        }
        if pos.line < lineCount {
            return MonaRange(startLine: pos.line, startColumn: maxCol,
                             endLine: pos.line + 1, endColumn: 1)
        }
        return nil                                                                            // last line end: no-op
    }

    // MARK: - Shared selection helpers (reused by T4–T8 handlers)

    /// Returns the selections the command should operate on: the gateway's
    /// last committed selections, or a single collapsed caret at `(1,1)` when
    /// none are committed. Other core handlers call this as
    /// `Self.currentSelections(ctx)`.
    static func currentSelections(_ ctx: MonaCommandContext) -> [MonaSelection] {
        let s = ctx.transactionGateway.lastCommittedSelections
        return s.isEmpty
            ? [MonaSelection(anchor: MonaPosition(line: 1, column: 1), activePosition: MonaPosition(line: 1, column: 1))]
            : s
    }

    // MARK: - cursorMove (reused by T7 cursorUp/Down + T8 cursorEnd/Home)

    /// Moves the primary cursor's active position by `target` and commits the
    /// resulting selection-only transaction on the gateway. v1 supports a
    /// single cursor: only the first (primary) selection's active position is
    /// moved; secondary selections are not yet carried. The actual movement
    /// (including line wrapping and clamping) is delegated to
    /// `caretOps.commitCaretMove`, which begins a transaction, prepares the
    /// moved selection, and commits it, updating
    /// `gateway.lastCommittedSelections`. Selection commands do NOT route
    /// through `inputBarrier` — they commit a selection-only transaction
    /// directly on the gateway.
    private static func cursorMove(_ ctx: MonaCommandContext, target: MonaCaretMoveTarget) {
        let sels = currentSelections(ctx)
        guard let pos = sels.first?.activePosition else { return }       // v1: primary cursor only
        _ = ctx.caretOps.commitCaretMove(
            pos,
            target: target,
            gateway: ctx.transactionGateway,
            lineCount: ctx.model.getLineCount(),
            maxColumnOf: { ctx.model.getLineMaxColumn($0) })
    }
}
