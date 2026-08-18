// MonaProcessMessageTransportTests.swift
//
// P06-T009 — Implement the macOS host byte-transport adapter outside Core.
//
// Verifies the macOS host byte-transport adapter (`MonaProcessMessageTransport`)
// — the concrete transport that bridges a launched process's stdin/stdout to
// the transport-neutral Core protocol (P06-T001 `MonaMessageTransport`).
//
// Test contract (P06-T009):
//   - Explicit-authorization launch: rejects without an explicit, absolute
//     executable path / working directory (no PATH lookup, no defaults).
//   - Byte bridging: process stdout → `.received`; `send(_:)` → process stdin.
//   - Partial writes, EOF, exit, cancellation, termination, and disposal are
//     serialized (terminals fire at most once; disposal is idempotent and
//     suppresses terminals; the first terminal wins).
//   - NO framing logic is embedded: the adapter is a raw byte pipe, not a
//     Content-Length frame parser (framing is T002, not this adapter).
//
// All tests launch only explicitly host-authorized, safe, absolute-path
// binaries (`/bin/echo`, `/bin/cat`, `/bin/sh`) — never arbitrary or untrusted
// executables, and never a PATH lookup.

import XCTest
import MonaCode
@testable import MonaCodeAppKit

final class MonaProcessMessageTransportTests: XCTestCase {

    // MARK: - Helpers

    /// A thread-safe recorder of `MonaTransportEvent`s, captured by the escaping
    /// event listener so tests can observe delivery order and counts across the
    /// background stdout read thread.
    private final class Recorder {
        private let lock = NSLock()
        private var _events: [MonaTransportEvent] = []

        func append(_ event: MonaTransportEvent) {
            lock.lock()
            _events.append(event)
            lock.unlock()
        }

        var events: [MonaTransportEvent] {
            lock.lock()
            defer { lock.unlock() }
            return _events
        }

        var receivedData: Data {
            lock.lock()
            defer { lock.unlock() }
            return _events.reduce(into: Data()) { acc, event in
                if case .received(let data) = event {
                    acc += data
                }
            }
        }

        var sentData: Data {
            lock.lock()
            defer { lock.unlock() }
            return _events.reduce(into: Data()) { acc, event in
                if case .sent(let data) = event {
                    acc += data
                }
            }
        }

        var terminalCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return _events.filter {
                if case .closed = $0 { return true }
                if case .errored = $0 { return true }
                return false
            }.count
        }

        var closedCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return _events.filter { if case .closed = $0 { return true }; return false }.count
        }

        var erroredCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return _events.filter { if case .errored = $0 { return true }; return false }.count
        }

        var sentCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return _events.filter { if case .sent = $0 { return true }; return false }.count
        }
    }

    /// Subscribes `recorder` to `transport`, fulfilling `terminal` on the first
    /// `.closed`/`.errored`, and (if non-nil) `receivedAll` once `predicate`
    /// holds over the accumulated received bytes.
    private func subscribe(
        _ transport: MonaMessageTransport,
        recorder: Recorder,
        terminal: XCTestExpectation,
        receivedPredicate: ((Data) -> Bool)? = nil,
        receivedAll: XCTestExpectation? = nil
    ) {
        _ = transport.onEvent { event in
            recorder.append(event)
            switch event {
            case .closed, .errored:
                terminal.fulfill()
            case .received:
                if let pred = receivedPredicate, let exp = receivedAll,
                   pred(recorder.receivedData) {
                    exp.fulfill()
                }
            default:
                break
            }
        }
    }

    // MARK: - Explicit-authorization launch

    func testRejectsEmptyExecutable() {
        XCTAssertThrowsError(
            try MonaProcessMessageTransport(
                executable: "",
                arguments: [],
                environment: [:],
                workingDirectory: "/"
            )
        ) { error in
            guard case .unauthorizedExecutable = error as? MonaProcessTransportError else {
                XCTFail("expected unauthorizedExecutable, got \(error)")
                return
            }
        }
    }

    func testRejectsRelativeExecutablePathNoPATHLookup() {
        // A relative executable must be rejected — the adapter performs NO PATH
        // lookup of arbitrary executables. Only host-authorized absolute paths.
        XCTAssertThrowsError(
            try MonaProcessMessageTransport(
                executable: "echo",
                arguments: [],
                environment: [:],
                workingDirectory: "/"
            )
        ) { error in
            guard case .unauthorizedExecutable = error as? MonaProcessTransportError else {
                XCTFail("expected unauthorizedExecutable, got \(error)")
                return
            }
        }
    }

    func testRejectsEmptyWorkingDirectory() {
        XCTAssertThrowsError(
            try MonaProcessMessageTransport(
                executable: "/bin/echo",
                arguments: [],
                environment: [:],
                workingDirectory: ""
            )
        ) { error in
            guard case .unauthorizedWorkingDirectory = error as? MonaProcessTransportError else {
                XCTFail("expected unauthorizedWorkingDirectory, got \(error)")
                return
            }
        }
    }

    func testRejectsRelativeWorkingDirectory() {
        XCTAssertThrowsError(
            try MonaProcessMessageTransport(
                executable: "/bin/echo",
                arguments: [],
                environment: [:],
                workingDirectory: "tmp"
            )
        ) { error in
            guard case .unauthorizedWorkingDirectory = error as? MonaProcessTransportError else {
                XCTFail("expected unauthorizedWorkingDirectory, got \(error)")
                return
            }
        }
    }

    // MARK: - Byte bridging: stdout → received, send → stdin

    func testStdoutReceivedInOrder() throws {
        let transport = try MonaProcessMessageTransport(
            executable: "/bin/echo",
            arguments: ["hello", "world"],
            environment: [:],
            workingDirectory: "/"
        )
        let recorder = Recorder()
        let terminal = expectation(description: "terminal")
        subscribe(transport, recorder: recorder, terminal: terminal)

        wait(for: [terminal], timeout: 10)

        // stdout produced exactly "hello world\n" — received verbatim.
        XCTAssertEqual(
            String(data: recorder.receivedData, encoding: .utf8),
            "hello world\n"
        )
        // Exactly one terminal (clean close from stdout EOF / exit 0).
        XCTAssertEqual(recorder.terminalCount, 1)
        transport.dispose()
    }

    func testSendWritesToStdinAndStdoutEchoes() throws {
        let transport = try MonaProcessMessageTransport(
            executable: "/bin/cat",
            arguments: [],
            environment: [:],
            workingDirectory: "/"
        )
        let recorder = Recorder()
        let terminal = expectation(description: "terminal")
        let receivedEcho = expectation(description: "received echo")
        subscribe(
            transport,
            recorder: recorder,
            terminal: terminal,
            receivedPredicate: { $0 == Data("ping\n".utf8) },
            receivedAll: receivedEcho
        )

        transport.send(Data("ping\n".utf8))
        wait(for: [receivedEcho], timeout: 10)

        transport.close()  // clean terminal + close stdin → cat exits
        wait(for: [terminal], timeout: 10)

        // send → stdin (cat echoed it); stdout → received.
        XCTAssertEqual(recorder.receivedData, Data("ping\n".utf8))
        XCTAssertEqual(recorder.sentData, Data("ping\n".utf8))
        XCTAssertEqual(recorder.terminalCount, 1)
        XCTAssertEqual(recorder.closedCount, 1)
        transport.dispose()
    }

    func testExplicitEnvironmentPassedToProcessNoInheritedDefaults() throws {
        // The adapter sets process.environment to the EXACT host-provided dict
        // (never inherits the host process's environment by default). The
        // process observes MONA_TEST=42 and echoes it back.
        let transport = try MonaProcessMessageTransport(
            executable: "/bin/sh",
            arguments: ["-c", "printf '%s' \"$MONA_TEST\""],
            environment: ["MONA_TEST": "42"],
            workingDirectory: "/"
        )
        let recorder = Recorder()
        let terminal = expectation(description: "terminal")
        subscribe(transport, recorder: recorder, terminal: terminal)

        wait(for: [terminal], timeout: 10)

        XCTAssertEqual(
            String(data: recorder.receivedData, encoding: .utf8),
            "42"
        )
        transport.dispose()
    }

    // MARK: - Partial writes

    func testPartialWritesFullyBridged() throws {
        // A payload larger than PIPE_BUF exercises the send path's partial-write
        // loop: stdin accepts the data in pieces, and the full payload is
        // bridged back through stdout.
        let transport = try MonaProcessMessageTransport(
            executable: "/bin/cat",
            arguments: [],
            environment: [:],
            workingDirectory: "/"
        )
        let payload = Data(repeating: 0x61, count: 65_536)  // 64 KB of 'a'
        let recorder = Recorder()
        let terminal = expectation(description: "terminal")
        let receivedAll = expectation(description: "received all")
        subscribe(
            transport,
            recorder: recorder,
            terminal: terminal,
            receivedPredicate: { $0.count >= payload.count },
            receivedAll: receivedAll
        )

        transport.send(payload)
        wait(for: [receivedAll], timeout: 15)

        transport.close()
        wait(for: [terminal], timeout: 10)

        XCTAssertEqual(recorder.receivedData.count, payload.count)
        XCTAssertEqual(recorder.receivedData, payload)
        XCTAssertEqual(recorder.sentData, payload)
        transport.dispose()
    }

    // MARK: - No framing logic embedded

    func testNoFramingLogicRawBytePipe() throws {
        // The adapter is a byte pipe, NOT a frame parser. Bytes that LOOK like a
        // Content-Length frame must pass through verbatim — no header parsing,
        // no length extraction, no reassembly. (Framing is T002, not T009.)
        let frameLike = Data("Content-Length: 2\r\n\r\nhi".utf8)
        let transport = try MonaProcessMessageTransport(
            executable: "/bin/cat",
            arguments: [],
            environment: [:],
            workingDirectory: "/"
        )
        let recorder = Recorder()
        let terminal = expectation(description: "terminal")
        let receivedAll = expectation(description: "received frame-like verbatim")
        subscribe(
            transport,
            recorder: recorder,
            terminal: terminal,
            receivedPredicate: { $0 == frameLike },
            receivedAll: receivedAll
        )

        transport.send(frameLike)
        wait(for: [receivedAll], timeout: 10)

        transport.close()
        wait(for: [terminal], timeout: 10)

        // Received == sent, byte-for-byte. No framing logic touched the stream.
        XCTAssertEqual(recorder.receivedData, frameLike)
        XCTAssertEqual(recorder.sentData, frameLike)
        transport.dispose()
    }

    // MARK: - EOF / exit drive a clean terminal

    func testEOFDrivesClosedTerminalExactlyOnce() throws {
        let transport = try MonaProcessMessageTransport(
            executable: "/bin/echo",
            arguments: ["done"],
            environment: [:],
            workingDirectory: "/"
        )
        let recorder = Recorder()
        let terminal = expectation(description: "terminal")
        subscribe(transport, recorder: recorder, terminal: terminal)

        wait(for: [terminal], timeout: 10)

        // stdout EOF → clean terminal (.closed). Fires exactly once.
        XCTAssertEqual(recorder.closedCount, 1)
        XCTAssertEqual(recorder.erroredCount, 0)
        XCTAssertEqual(recorder.terminalCount, 1)
        transport.dispose()
    }

    // MARK: - Cancellation, termination, disposal serialized

    func testCancelTokenTerminatesProcessAndSerializesTerminal() throws {
        // /bin/cat blocks on stdin (no data). Cancelling the token terminates the
        // process; exactly one terminal fires (first-terminal-wins serializes
        // the EOF and exit paths).
        let cts = MonaCancellationTokenSource()
        let transport = try MonaProcessMessageTransport(
            executable: "/bin/cat",
            arguments: [],
            environment: [:],
            workingDirectory: "/",
            cancellationToken: cts.token
        )
        let recorder = Recorder()
        let terminal = expectation(description: "terminal")
        subscribe(transport, recorder: recorder, terminal: terminal)

        cts.cancel()  // → terminate the process → exit → terminal
        wait(for: [terminal], timeout: 10)

        XCTAssertEqual(recorder.terminalCount, 1)
        transport.dispose()
    }

    func testTerminateForceTerminatesAndSerializesTerminal() throws {
        let transport = try MonaProcessMessageTransport(
            executable: "/bin/cat",
            arguments: [],
            environment: [:],
            workingDirectory: "/"
        )
        let recorder = Recorder()
        let terminal = expectation(description: "terminal")
        subscribe(transport, recorder: recorder, terminal: terminal)

        transport.terminate()  // force-terminate → exit → terminal
        wait(for: [terminal], timeout: 10)

        XCTAssertEqual(recorder.terminalCount, 1)
        transport.dispose()
    }

    func testDisposeIsIdempotentAndDoesNotFireTerminal() throws {
        let transport = try MonaProcessMessageTransport(
            executable: "/bin/cat",
            arguments: [],
            environment: [:],
            workingDirectory: "/"
        )
        let recorder = Recorder()
        // Subscribe directly (no terminal expectation): disposal must NOT fire
        // a terminal, so there is nothing to wait for on the terminal path.
        _ = transport.onEvent { recorder.append($0) }

        transport.dispose()
        transport.dispose()  // idempotent
        transport.dispose()  // idempotent

        // Give the background read loop a moment to observe process teardown
        // (process.terminate → stdout EOF → read loop checks `_isDisposed` →
        // exits WITHOUT calling `close()`).
        let grace = expectation(description: "grace")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { grace.fulfill() }
        wait(for: [grace], timeout: 5)

        // Disposal tore down without firing a terminal (mirrors
        // MonaCancellationTokenSource.dispose vs cancel). Only `.received`/
        // `.sent` (non-terminal) events may be present.
        XCTAssertEqual(recorder.terminalCount, 0)
        XCTAssertTrue(recorder.events.allSatisfy {
            if case .received = $0 { return true }
            if case .sent = $0 { return true }
            return false
        })
    }

    func testFirstTerminalWinsCloseBeforeFail() throws {
        let transport = try MonaProcessMessageTransport(
            executable: "/bin/cat",
            arguments: [],
            environment: [:],
            workingDirectory: "/"
        )
        let recorder = Recorder()
        let terminal = expectation(description: "terminal")
        subscribe(transport, recorder: recorder, terminal: terminal)

        transport.close()  // fires .closed
        transport.fail(MonaProcessTransportError.processExitedNonZero(1))  // suppressed
        wait(for: [terminal], timeout: 10)

        XCTAssertEqual(recorder.terminalCount, 1)
        XCTAssertEqual(recorder.closedCount, 1)
        XCTAssertEqual(recorder.erroredCount, 0)
        transport.dispose()
    }

    func testSendAfterCloseIsNoOp() throws {
        let transport = try MonaProcessMessageTransport(
            executable: "/bin/cat",
            arguments: [],
            environment: [:],
            workingDirectory: "/"
        )
        let recorder = Recorder()
        let terminal = expectation(description: "terminal")
        subscribe(transport, recorder: recorder, terminal: terminal)

        transport.close()
        let sentBefore = recorder.sentCount
        transport.send(Data("after-close".utf8))  // no-op after terminal
        wait(for: [terminal], timeout: 10)

        XCTAssertEqual(recorder.sentCount - sentBefore, 0)
        transport.dispose()
    }

    // MARK: - Protocol surface is exactly five operations

    func testConformsToMonaMessageTransportProtocolSurface() throws {
        // The adapter conforms to `MonaMessageTransport` — the protocol surface
        // is exactly five operations (onEvent, send, close, fail, dispose). This
        // is a compile-time witness that the adapter IS-A byte channel and
        // exposes no framing/launch/session surface through the protocol.
        let transport: MonaMessageTransport = try MonaProcessMessageTransport(
            executable: "/bin/echo",
            arguments: [],
            environment: [:],
            workingDirectory: "/"
        )
        _ = transport.onEvent { _ in MonaDisposableImpl({ }) }  // 1. receive
        transport.send(Data([0x01]))                            // 2. byte send
        transport.close()                                      // 3. close
        transport.fail(MonaProcessTransportError.processExitedNonZero(1))  // 4. error
        transport.dispose()                                    // 5. disposal
    }
}
