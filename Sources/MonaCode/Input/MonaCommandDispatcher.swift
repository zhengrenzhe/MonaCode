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
}
