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
}
