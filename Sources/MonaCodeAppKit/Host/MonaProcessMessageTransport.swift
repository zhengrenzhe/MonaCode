// MonaProcessMessageTransport.swift
//
// P06-T009 — Implement the macOS host byte-transport adapter outside Core.
//
// `MonaProcessMessageTransport` is the concrete macOS host byte-transport
// adapter — the bridge between a launched process's stdin/stdout and the
// transport-neutral Core protocol `MonaMessageTransport` (P06-T001). It is the
// Swift counterpart of the host-side process spawning + pipe wiring that sits
// beneath Monaco's JSON-RPC message reader/writer (monaco-editor 0.56.0).
//
// This adapter lives OUTSIDE Core (in `MonaCodeAppKit`) because process
// launching is platform-specific: `Process`, `Pipe`, and file-descriptor
// lifecycle are macOS/FoundFoundation host concerns, not transport-neutral Core
// concerns. Core (P06-T001) owns the byte-channel protocol; this adapter is
// what T001's `internal receive(_:)` hook + `send` wire to in production.
//
// Responsibilities (per the G6-R contract):
//
//   1. Launch ONLY an explicitly host-authorized executable with an EXPLICIT
//      environment and working directory. The executable path and working
//      directory must be absolute (no PATH lookup of arbitrary executables —
//      host-authorized only). The environment is set to the EXACT host-provided
//      dict (never inherited by default). Rejects (throws) without explicit
//      authorization.
//   2. Bridge standard input and output bytes to the transport-neutral Core
//      protocol. The process's stdout → `.received` (via the private
//      `receive(_:)` hook, reusing T001's pattern). `send(_:)` → process's
//      stdin, with a partial-write loop (stdin accepts partial data).
//   3. Serialize partial writes, end-of-file, exit, cancellation, termination,
//      and disposal WITHOUT embedding framing logic. The terminal/disposal
//      state machine is reused verbatim from T001's `MonaMessageTransportImpl`
//      (first-terminal-wins; `dispose()` is idempotent and suppresses
//      terminals without firing one, mirroring
//      `MonaCancellationTokenSource.dispose` vs `cancel`). NO framing
//      (Content-Length) logic lives here — the byte channel is
//      transport-neutral; framing is T002, not this adapter.
//
// `MonaCodeAppKit` may `import AppKit`, `import Foundation`, and `import MonaCode`.

import AppKit
import Foundation
import MonaCode

/// Errors raised by `MonaProcessMessageTransport`.
public enum MonaProcessTransportError: Error {
    /// The executable path was empty or relative. The adapter performs NO PATH
    /// lookup — only an explicit, absolute, host-authorized path is accepted.
    case unauthorizedExecutable(String)
    /// The working directory was empty or relative. An explicit, absolute
    /// working directory is required.
    case unauthorizedWorkingDirectory(String)
    /// `Process.run()` failed (binary not found, permission denied, …).
    case launchFailed(String)
    /// Writing to the process's stdin failed (broken pipe / closed).
    case writeFailed(String)
    /// The process exited with a non-zero status.
    case processExitedNonZero(Int32)
}

/// The macOS host byte-transport adapter — bridges a launched process's
/// stdin/stdout to the transport-neutral Core protocol `MonaMessageTransport`.
///
/// Construct with an explicit, absolute `executable`, an explicit
/// `environment`, and an absolute `workingDirectory` (authorization is
/// rejected without them). Subscribe via `onEvent` (the process launches in
/// `init`; the stdout read loop starts on the first subscription so no
/// `.received` bytes are lost before a listener is attached). Send bytes with
/// `send(_:)` (writes to stdin). Close cleanly with `close()`. Force-terminate
/// with `terminate()`. Tear down without firing a terminal with `dispose()`.
///
/// The terminal/disposal semantics are reused verbatim from
/// `MonaMessageTransportImpl` (P06-T001): `close()`/`fail(_:)` are terminal and
/// idempotent (first-terminal-wins); `dispose()` is distinct — it tears down
/// the event sink WITHOUT firing `.closed`/`.errored`. A `MonaCancellationToken`
/// may be supplied; when cancelled it force-terminates the process (whose exit
/// then drives a terminal through the serialized state machine).
public final class MonaProcessMessageTransport: MonaMessageTransport {

    // MARK: - Private state

    /// The launched process. Set once in `init`.
    private let process: Process
    /// The process's stdin (host writes here via `send`).
    private let stdinPipe: Pipe
    /// The process's stdout (host reads here → `.received`).
    private let stdoutPipe: Pipe

    /// The event emitter — reused from Core (P01-T005). The stdout read loop
    /// drives `.received` via the private `receive(_:)` hook; `send(_:)` fires
    /// `.sent`; `close()`/`fail(_:)` fire the terminals. The read loop starts
    /// on the first listener subscription (so bytes produced before
    /// subscription are buffered by the OS pipe and drained once a listener
    /// attaches — no `.received` is lost).
    private let _emitter: MonaEmitter<MonaTransportEvent>

    /// The cancellation registration (removed on `dispose`). When the token
    /// fires, the process is force-terminated (its exit drives a terminal).
    private var cancellationRegistration: MonaDisposable?

    /// `nil` while open; set once by the first of `close()`/`fail(_:)` — the
    /// first terminal wins and subsequent terminal/send/receive calls no-op.
    private var _terminal: Terminal? = nil
    /// `true` once `dispose()` has torn down the transport. After dispose,
    /// `send`/`close`/`fail`/`receive` are no-ops and `fireTerminal` is a
    /// no-op (no terminal is fired by disposal).
    private var _disposed = false
    private let _lock = NSLock()

    /// The background stdout read thread. Retained so `dispose()` can mark it
    /// for teardown (the thread exits when the process closes stdout).
    private var _readThread: Thread?
    /// `true` once `startReadLoopOnce()` has started the read thread. Guarded
    /// by `_lock` so the first subscription starts the loop exactly once.
    private var _readLoopStarted = false

    // MARK: - Init

    /// Creates and launches a process byte-transport adapter.
    ///
    /// - Parameters:
    ///   - executable: An explicit, ABSOLUTE path to a host-authorized
    ///     executable. Relative or empty paths are rejected (no PATH lookup).
    ///   - arguments: The arguments to pass to the executable. Defaults to
    ///     empty (explicit choice).
    ///   - environment: The EXACT environment for the process. Never inherited
    ///     from the host process — pass `[:]` for an explicit empty
    ///     environment. Presence is type-enforced (no default).
    ///   - workingDirectory: An ABSOLUTE working directory for the process.
    ///     Relative or empty paths are rejected.
    ///   - cancellationToken: When cancelled, the process is force-terminated
    ///     (its exit drives a terminal). Defaults to `.none`.
    /// - Throws: `MonaProcessTransportError.unauthorizedExecutable` /
    ///   `unauthorizedWorkingDirectory` if the path is empty/relative;
    ///   `launchFailed` if `Process.run()` fails.
    public init(
        executable: String,
        arguments: [String] = [],
        environment: [String: String],
        workingDirectory: String,
        cancellationToken: MonaCancellationToken = .none
    ) throws {
        // 1. Explicit-authorization: executable + working directory must be
        //    absolute (no PATH lookup of arbitrary executables). The
        //    environment is required by the type signature (no default — the
        //    host must provide it; `[:]` is an explicit empty environment).
        guard !executable.isEmpty, executable.hasPrefix("/") else {
            throw MonaProcessTransportError.unauthorizedExecutable(executable)
        }
        guard !workingDirectory.isEmpty, workingDirectory.hasPrefix("/") else {
            throw MonaProcessTransportError.unauthorizedWorkingDirectory(workingDirectory)
        }

        // Ignore SIGPIPE once per process: writing to a stdin whose read end
        // (the process) has closed must NOT kill the host process — the adapter
        // handles the broken-pipe as a transport error via `fail(_:)`.
        Self.installSIGPIPEIgnore()

        self.process = Process()
        self.process.executableURL = URL(fileURLWithPath: executable)
        self.process.arguments = arguments
        // Explicit environment — NEVER inherit. The host's dict is the truth.
        self.process.environment = environment
        self.process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)

        let stdin = Pipe()
        let stdout = Pipe()
        self.stdinPipe = stdin
        self.stdoutPipe = stdout
        self.process.standardInput = stdin
        self.process.standardOutput = stdout
        // stderr is not bridged — this adapter is a byte channel for the
        // transport stream only; stderr is a host concern outside this scope.

        // Reuse T001's pattern: an in-memory emitter drives `.received`/`.sent`
        // and the terminals. The read loop starts on the FIRST listener
        // subscription (via the custom `onEvent` getter below) so bytes produced
        // before subscription drain from the OS pipe buffer afterward — no
        // `.received` is lost.
        self._emitter = MonaEmitter<MonaTransportEvent>()

        // Launch the explicitly-authorized process.
        do {
            try self.process.run()
        } catch {
            throw MonaProcessTransportError.launchFailed(String(describing: error))
        }

        // Cancellation → force-terminate the process. The process's exit then
        // drives a terminal through the serialized state machine (first-
        // terminal-wins; suppressed if already disposed).
        self.cancellationRegistration = cancellationToken.onCancellationRequested {
            [weak self] in
            self?.terminate()
        }

        // Process exit → terminal. Exit 0 → clean close; non-zero → error. The
        // first terminal wins, so if stdout EOF already fired `.closed` this is
        // a no-op. Suppressed entirely after `dispose()`.
        self.process.terminationHandler = { [weak self] proc in
            guard let self = self else { return }
            if proc.terminationStatus == 0 {
                self.close()
            } else {
                self.fail(MonaProcessTransportError.processExitedNonZero(proc.terminationStatus))
            }
        }
    }

    // MARK: - MonaMessageTransport conformance

    public var onEvent: MonaEvent<MonaTransportEvent> {
        // Custom subscribe: register the listener, then start the stdout read
        // loop on the first subscription so bytes produced before subscription
        // are buffered by the OS pipe and drained afterward (no `.received` is
        // lost). The read loop is started at most once (idempotent).
        return { [weak self] listener in
            guard let self = self else {
                return MonaDisposableImpl({ })
            }
            let disposable = self._emitter.event(listener)
            self.startReadLoopOnce()
            return disposable
        }
    }

    public func send(_ bytes: Data) {
        // No-op once terminal or disposed (first-terminal-wins / disposal).
        guard isOpen else { return }

        // Partial-write loop: stdin accepts data in pieces. Write until the
        // full payload is delivered or the pipe closes (→ fail). SIGPIPE is
        // ignored (see init) so a broken pipe surfaces as a write error.
        let fd = stdinPipe.fileHandleForWriting.fileDescriptor
        let total = bytes.count
        if total == 0 {
            _emitter.fire(.sent(bytes))
            return
        }
        var written = 0
        let writeError: Error? = bytes.withUnsafeBytes { (buf: UnsafeRawBufferPointer) -> Error? in
            guard let base = buf.baseAddress else { return nil }
            while written < total {
                let n = write(fd, base.advanced(by: written), total - written)
                if n < 0 {
                    let msg = String(cString: strerror(errno))
                    return MonaProcessTransportError.writeFailed(msg)
                }
                if n == 0 {
                    return MonaProcessTransportError.writeFailed("stdin closed")
                }
                written += n
            }
            return nil
        }
        if let error = writeError {
            fail(error)
            return
        }
        // Fire `.sent` once with the full payload — issuance order, one per
        // `send` (mirrors T001's `MonaMessageTransportImpl.send`).
        _emitter.fire(.sent(bytes))
    }

    public func close() {
        // Clean terminal: fires `.closed` exactly once (first-terminal-wins;
        // no-op after dispose). When this call fires the terminal, also signal
        // EOF to the process's stdin so a peer reading stdin exits cleanly.
        if fireTerminal(.closed) != nil {
            try? stdinPipe.fileHandleForWriting.close()
        }
    }

    public func fail(_ error: Error) {
        _ = fireTerminal(.errored(error))
    }

    public func dispose() {
        // Idempotent. Distinct from `close()`/`fail(_:)`: disposal tears down
        // WITHOUT firing a terminal (mirrors
        // `MonaCancellationTokenSource.dispose` vs `cancel`). After dispose,
        // `send`/`close`/`fail`/`receive` and `fireTerminal` are no-ops.
        var shouldTearDown = false
        _lock.lock()
        if !_disposed {
            _disposed = true
            shouldTearDown = true
        }
        _lock.unlock()
        guard shouldTearDown else { return }

        // Detach the cancellation listener (no more token-driven terminate).
        cancellationRegistration?.dispose()
        cancellationRegistration = nil

        // Force-terminate the process. Its stdout then closes (EOF), which
        // unblocks the read loop; the read loop and terminationHandler call
        // `close()`/`fail(_:)`, both no-ops now (disposed → fireTerminal
        // no-ops). NO terminal is fired by disposal.
        if process.isRunning {
            process.terminate()
        }
        // Close the stdin write end so any blocked `send` write returns.
        try? stdinPipe.fileHandleForWriting.close()
        // The stdout read handle is closed by the read loop on EOF (process
        // termination closes stdout). Closing it here could race with a
        // blocked `availableData`; relying on process termination is safe.

        // Tear down the event sink (no further delivery; `fire` is a no-op).
        _emitter.dispose()
    }

    // MARK: - Force-terminate

    /// Force-terminates the process (SIGTERM). The process's exit then drives a
    /// terminal through the serialized state machine (`close()` for exit 0,
    /// `fail(_:)` for non-zero) — the first terminal wins, so this is a no-op
    /// if a terminal has already fired or the transport has been disposed.
    public func terminate() {
        let proc = process
        if proc.isRunning {
            proc.terminate()
        }
    }

    // MARK: - Private

    /// The terminal state — which terminal fired first.
    private enum Terminal {
        case closed
        case errored(Error)
    }

    /// `true` while the transport is open (no terminal fired and not disposed).
    private var isOpen: Bool {
        _lock.lock()
        let open = (_terminal == nil) && !_disposed
        _lock.unlock()
        return open
    }

    /// Sets the terminal state and fires the terminal event exactly once. The
    /// first terminal wins; subsequent calls are no-ops. No-op after
    /// `dispose()`. Returns the fired event, or `nil` if this call was a
    /// no-op. (Reused verbatim from `MonaMessageTransportImpl.fireTerminal`.)
    @discardableResult
    private func fireTerminal(_ terminal: Terminal) -> MonaTransportEvent? {
        var toFire: MonaTransportEvent? = nil
        _lock.lock()
        if _terminal == nil && !_disposed {
            _terminal = terminal
            switch terminal {
            case .closed:
                toFire = .closed
            case .errored(let error):
                toFire = .errored(error)
            }
        }
        _lock.unlock()
        if let event = toFire {
            _emitter.fire(event)
        }
        return toFire
    }

    /// Injects `bytes` received from the process's stdout, firing
    /// `.received(bytes)` in arrival order. Private host-side hook (reusing
    /// T001's `internal receive(_:)` pattern): the read loop reads from the real
    /// byte stream and calls this. No-op after the transport has reached a
    /// terminal state or after `dispose()`.
    private func receive(_ bytes: Data) {
        guard isOpen else { return }
        _emitter.fire(.received(bytes))
    }

    /// Starts the stdout read loop at most once. Called on the first
    /// listener subscription (via the custom `onEvent` getter), so bytes
    /// produced before subscription are buffered by the OS pipe and drained
    /// afterward — no `.received` is lost.
    private func startReadLoopOnce() {
        _lock.lock()
        if _readLoopStarted || _disposed {
            _lock.unlock()
            return
        }
        _readLoopStarted = true
        _lock.unlock()

        let fh = stdoutPipe.fileHandleForReading
        let thread = Thread { [weak self] in
            guard let self = self else { return }
            while true {
                // `availableData` blocks until data arrives or the write end
                // (the process's stdout) closes — empty Data signals EOF.
                let chunk = fh.availableData
                // If disposed during a blocked read, exit once unblocked.
                if self._isDisposed { break }
                if chunk.isEmpty {
                    // End-of-file: the process closed stdout. Drive a clean
                    // terminal (no-op if already terminal/disposed).
                    self.close()
                    break
                }
                self.receive(chunk)
            }
        }
        thread.name = "MonaProcessMessageTransport.stdout"
        thread.start()
        _readThread = thread
    }

    /// `true` once `dispose()` has run (read-only, lock-guarded).
    private var _isDisposed: Bool {
        _lock.lock()
        defer { _lock.unlock() }
        return _disposed
    }

    // MARK: - One-time SIGPIPE ignore

    /// Installs `SIG_IGN` for `SIGPIPE` once per process. Writing to a stdin
    /// whose read end (the process) has closed must surface as a transport
    /// error (`fail`) rather than killing the host process. Idempotent.
    private static let _installSIGPIPEIgnore: Void = {
        signal(SIGPIPE, SIG_IGN)
    }()

    private static func installSIGPIPEIgnore() {
        _ = _installSIGPIPEIgnore
    }
}

// MARK: - Sendable

// `MonaProcessMessageTransport` crosses concurrency-isolation boundaries: the
// process `terminationHandler` and the stdout read `Thread` are `@Sendable`
// closures that capture `self`. All mutable state is guarded by `_lock`
// (`_terminal`, `_disposed`, `cancellationRegistration`, `_readThread`); the
// `_emitter`, `process`, and pipes are themselves internally synchronized
// (`MonaEmitter` is `NSLock`-guarded; `Process`/`Pipe` are thread-safe for
// the read/write/terminate surface used here). `@unchecked` asserts that this
// manual verification holds — matching the `MonaPointerGateway` /
// `MonaScrollGateway` / `MonaContextMenuGateway` precedent in this target.
extension MonaProcessMessageTransport: @unchecked Sendable {}
