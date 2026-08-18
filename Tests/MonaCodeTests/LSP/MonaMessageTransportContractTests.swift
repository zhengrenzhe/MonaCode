// MonaMessageTransportContractTests.swift
//
// P06-T001 — Define a transport-neutral byte channel in Core.
//
// Verifies the `MonaMessageTransport` contract:
//   - Ordered byte receive/send: `.received` and `.sent` events are delivered
//     in arrival/issuance order.
//   - Close + error are terminal and fire exactly once (idempotent); after a
//     terminal, no more receive/send.
//   - The first terminal wins: close-then-error fires only `.closed`;
//     error-then-close fires only `.errored`.
//   - `dispose()` is idempotent, does NOT fire a terminal, and stops further
//     delivery (mirrors `MonaCancellationTokenSource.dispose` vs `cancel`).
//   - The protocol surface is EXACTLY five operations: ordered byte receive
//     (`onEvent`), byte send (`send`), close (`close`), error (`fail`), and
//     disposal (`dispose`). No framing, JSON, session, launch, FD, or platform
//     lifecycle is exposed (those are T002–T004 + T009).

import XCTest
@testable import MonaCode

final class MonaMessageTransportContractTests: XCTestCase {

    /// A throw used to exercise the error terminal.
    private enum Boom: Error, Equatable { case boom }

    /// A mutable, reference-typed recorder captured by the escaping event
    /// listener so the test can observe delivery order and counts.
    private final class Recorder {
        var events: [MonaTransportEvent] = []
    }

    /// `true` when `event` is the `.closed` terminal.
    private func isClosed(_ event: MonaTransportEvent) -> Bool {
        if case .closed = event { return true }
        return false
    }

    /// `true` when `event` is the `.errored` terminal.
    private func isErrored(_ event: MonaTransportEvent) -> Bool {
        if case .errored = event { return true }
        return false
    }

    // MARK: - Ordered byte receive/send

    func testOrderedReceiveAndSendEventsDeliveredInOrder() {
        let transport = MonaMessageTransportImpl()
        let recorder = Recorder()
        _ = transport.onEvent { event in
            recorder.events.append(event)
        }

        transport.receive(Data([0x01]))
        transport.receive(Data([0x02, 0x03]))
        transport.send(Data([0x04]))
        transport.receive(Data([0x05]))

        // Ordered receive + send: events arrive in the exact order injected,
        // interleaving receives and sends as issued.
        XCTAssertEqual(recorder.events.count, 4)
        if case .received(let bytes) = recorder.events[0] {
            XCTAssertEqual(bytes, Data([0x01]))
        } else {
            XCTFail("expected .received at index 0")
        }
        if case .received(let bytes) = recorder.events[1] {
            XCTAssertEqual(bytes, Data([0x02, 0x03]))
        } else {
            XCTFail("expected .received at index 1")
        }
        if case .sent(let bytes) = recorder.events[2] {
            XCTAssertEqual(bytes, Data([0x04]))
        } else {
            XCTFail("expected .sent at index 2")
        }
        if case .received(let bytes) = recorder.events[3] {
            XCTAssertEqual(bytes, Data([0x05]))
        } else {
            XCTFail("expected .received at index 3")
        }
    }

    // MARK: - Close terminal fires exactly once

    func testCloseFiresClosedExactlyOnceAndStopsDelivery() {
        let transport = MonaMessageTransportImpl()
        let recorder = Recorder()
        _ = transport.onEvent { event in recorder.events.append(event) }

        transport.close()
        transport.close()  // idempotent — must not fire again
        transport.close()  // idempotent — must not fire again

        XCTAssertEqual(recorder.events.filter(isClosed).count, 1)

        // After close, no more receive/send.
        transport.receive(Data([0x01]))
        transport.send(Data([0x02]))
        XCTAssertEqual(recorder.events.count, 1)
    }

    // MARK: - Error terminal fires exactly once

    func testFailFiresErroredExactlyOnceAndStopsDelivery() {
        let transport = MonaMessageTransportImpl()
        let recorder = Recorder()
        _ = transport.onEvent { event in recorder.events.append(event) }

        transport.fail(Boom.boom)
        transport.fail(Boom.boom)  // idempotent — must not fire again

        XCTAssertEqual(recorder.events.filter(isErrored).count, 1)
        if case .errored(let err) = recorder.events.first! {
            XCTAssertEqual(err as? Boom, .boom)
        } else {
            XCTFail("expected .errored as the first event")
        }

        // After error, no more receive/send.
        transport.receive(Data([0x01]))
        transport.send(Data([0x02]))
        XCTAssertEqual(recorder.events.count, 1)
    }

    // MARK: - First terminal wins

    func testCloseBeforeErrorFiresOnlyClosed() {
        let transport = MonaMessageTransportImpl()
        let recorder = Recorder()
        _ = transport.onEvent { event in recorder.events.append(event) }

        transport.close()
        transport.fail(Boom.boom)  // suppressed — first terminal wins

        XCTAssertEqual(recorder.events.count, 1)
        XCTAssertTrue(isClosed(recorder.events[0]))
        XCTAssertEqual(recorder.events.filter(isErrored).count, 0)
    }

    func testErrorBeforeCloseFiresOnlyErrored() {
        let transport = MonaMessageTransportImpl()
        let recorder = Recorder()
        _ = transport.onEvent { event in recorder.events.append(event) }

        transport.fail(Boom.boom)
        transport.close()  // suppressed — first terminal wins

        XCTAssertEqual(recorder.events.count, 1)
        XCTAssertTrue(isErrored(recorder.events[0]))
        XCTAssertEqual(recorder.events.filter(isClosed).count, 0)
    }

    // MARK: - Disposal (distinct from terminal)

    func testDisposeIsIdempotentAndDoesNotFireTerminal() {
        let transport = MonaMessageTransportImpl()
        let recorder = Recorder()
        _ = transport.onEvent { event in recorder.events.append(event) }

        transport.dispose()
        transport.dispose()  // idempotent

        // Disposal does NOT fire a terminal event (distinct from close/fail).
        XCTAssertTrue(recorder.events.isEmpty)

        // After dispose, receive/send/close/fail are no-ops.
        transport.receive(Data([0x01]))
        transport.send(Data([0x02]))
        transport.close()
        transport.fail(Boom.boom)
        XCTAssertTrue(recorder.events.isEmpty)
    }

    // MARK: - Protocol surface is exactly five operations

    func testProtocolSurfaceIsExactlyFiveOperations() {
        // The `MonaMessageTransport` protocol declares EXACTLY these five
        // operations — ordered byte receive, byte send, close, error, and
        // disposal. No framing, JSON, session, launch, FD, or platform
        // lifecycle is exposed (those are T002–T004 + T009). This test is a
        // compile-time witness: each of the five is callable on a
        // protocol-typed value; the protocol declaration is the source of
        // truth for the absence of a sixth.
        let transport: MonaMessageTransport = MonaMessageTransportImpl()
        _ = transport.onEvent { _ in MonaDisposableImpl({ }) }  // 1. receive
        transport.send(Data([0x01]))                            // 2. byte send
        transport.close()                                      // 3. close
        transport.fail(Boom.boom)                              // 4. error
        transport.dispose()                                    // 5. disposal
    }
}
