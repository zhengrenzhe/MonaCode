// Tests/MonaCodeTests/Input/MonaCommandDispatcherTests.swift
import XCTest
import MonaCode

final class MonaCommandDispatcherTests: XCTestCase {
    func makeDispatcher(text: String = "") -> (MonaCommandDispatcher, MonaCodeModel, MonaModelInputBarrier, MonaTransactionGateway) {
        let model = MonaCodeModel(text: text, uri: MonaURI(scheme: "inmemory", path: "/t"))
        let barrier = MonaModelInputBarrier(model: model)
        let dispatcher = MonaCommandDispatcher(model: model, inputBarrier: barrier,
                                               transactionGateway: barrier.gateway,
                                               caretOps: MonaCaretOperationsFeature())
        return (dispatcher, model, barrier, barrier.gateway)
    }

    func testExecuteUnknownCommandReturnsFalse() {
        let (dispatcher, _, _, _) = makeDispatcher()
        XCTAssertFalse(dispatcher.execute("nope"))
        XCTAssertFalse(dispatcher.contains("nope"))
    }

    func testRegisterAndExecuteCustomCommand() {
        var called = false
        let (dispatcher, model, _, _) = makeDispatcher()
        dispatcher.register("test.echo") { ctx, _ in called = true; _ = ctx }
        XCTAssertTrue(dispatcher.contains("test.echo"))
        XCTAssertTrue(dispatcher.execute("test.echo"))
        XCTAssertTrue(called)
        _ = model
    }
}
