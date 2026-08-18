// MonaMessageTransport.swift
//
// P06-T001 — Define a transport-neutral byte channel in Core.
//
// `MonaMessageTransport` is the LSP message transport's lowest layer — a
// transport-neutral ordered byte channel. It is the Swift counterpart of the
// byte-stream abstraction that sits beneath Monaco's JSON-RPC message reader
// and writer (monaco-editor 0.56.0). The protocol surface is exactly five
// operations:
//
//   1. ordered byte receive — `onEvent` delivers `.received(Data)` in arrival
//      order (alongside `.sent`, `.closed`, `.errored`).
//   2. byte send — `send(_:)` emits bytes to the peer.
//   3. close — `close()` initiates a clean terminal close.
//   4. error — `fail(_:)` signals a transport error (terminal).
//   5. disposal — `dispose()` (inherited from `MonaDisposable`) tears down the
//      event sink.
//
// Everything above the byte channel — framing (Content-Length headers),
// JSON-RPC, session state, launch policy, file descriptors, and platform
// lifecycle — is OUTSIDE this protocol. Those are handled by T002 (frame
// codec), T003 (JSON-RPC), T004 (session), and T009 (macOS host adapter).
//
// Terminal serialization (frozen by P06-T001):
//
//   - `close()` and `fail(_:)` are terminal and idempotent: each fires its
//     event at most once. The first terminal wins — once `close()` or
//     `fail(_:)` has fired, subsequent `close()`/`fail(_:)`/`send(_:)` are
//     no-ops and no further `.received`/`.sent` events are delivered.
//   - `dispose()` is distinct from a terminal: it tears down the event sink
//     WITHOUT firing `.closed`/`.errored` (mirroring
//     `MonaCancellationTokenSource.dispose` vs `cancel`). After `dispose()`,
//     `send(_:)`/`close()`/`fail(_:)`/`receive(_:)` are no-ops.
//
// `MonaMessageTransportImpl` is the concrete reference byte channel: an
// in-memory `MonaEmitter<MonaTransportEvent>` + an idempotent terminal state
// machine + an idempotent disposal guard. The host adapter (T009) drives
// `.received` via the `internal receive(_:)` hook and wires `send(_:)` to the
// real byte stream; the terminal/disposal mechanics are reused as-is.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// A transport-neutral ordered byte channel — the LSP message transport's
/// lowest layer.
///
/// The protocol surface is exactly five operations: ordered byte receive
/// (`onEvent`), byte send (`send`), close (`close`), error (`fail`), and
/// disposal (`dispose`, inherited from `MonaDisposable`). Conforming types are
/// reference types (`AnyObject`-bound via `MonaDisposable`): the terminal and
/// disposal guards mutate shared state.
public protocol MonaMessageTransport: MonaDisposable {

    /// The ordered event stream for this transport.
    ///
    /// Delivers `.received(Data)` in arrival order, `.sent(Data)` in issuance
    /// order, and the `.closed`/`.errored` terminal events at most once each.
    /// After a terminal or `dispose()`, the returned `MonaDisposable` is inert
    /// (the listener is never registered).
    var onEvent: MonaEvent<MonaTransportEvent> { get }

    /// Sends `bytes` to the transport's peer.
    ///
    /// Fires `.sent(bytes)` when the transport is open. No-op after a terminal
    /// event has fired or after `dispose()`.
    func send(_ bytes: Data)

    /// Initiates a clean terminal close.
    ///
    /// Idempotent: the first call fires `.closed` exactly once; every
    /// subsequent call is a no-op. If `fail(_:)` has already fired, `close()`
    /// is a no-op (the first terminal wins). No-op after `dispose()`.
    func close()

    /// Signals a transport error.
    ///
    /// Idempotent: the first call fires `.errored(error)` exactly once; every
    /// subsequent call is a no-op. If `close()` has already fired, `fail(_:)`
    /// is a no-op (the first terminal wins). No-op after `dispose()`.
    func fail(_ error: Error)
}

/// The concrete reference byte channel — an in-memory, transport-neutral
/// `MonaMessageTransport`.
///
/// Composes a `MonaEmitter<MonaTransportEvent>` for ordered, reentrancy-safe
/// event delivery and an idempotent terminal/disposal state machine guarded by
/// an `NSLock`. The host adapter (T009) drives `.received` via
/// `receive(_:)` and wires `send(_:)` to the real byte stream; the
/// terminal/disposal mechanics are reused unchanged.
///
/// Disposal is distinct from a terminal event (mirrors
/// `MonaCancellationTokenSource.dispose` vs `cancel`): `dispose()` tears down
/// the event sink without firing `.closed`/`.errored`.
public final class MonaMessageTransportImpl: MonaMessageTransport {

    private let _emitter = MonaEmitter<MonaTransportEvent>()
    private let _lock = NSLock()
    /// `nil` while open; set once by the first of `close()`/`fail(_:)` — the
    /// first terminal wins and subsequent terminal/send/receive calls no-op.
    private var _terminal: Terminal? = nil
    private var _disposed = false

    /// Creates a new, open byte channel.
    public init() {}

    public var onEvent: MonaEvent<MonaTransportEvent> {
        return _emitter.event
    }

    public func send(_ bytes: Data) {
        // No-op once terminal or disposed. Ordered `.sent` delivery is
        // preserved by `MonaEmitter`'s snapshot-end delivery queue.
        guard isOpen else { return }
        _emitter.fire(.sent(bytes))
    }

    public func close() {
        fireTerminal(.closed)
    }

    public func fail(_ error: Error) {
        fireTerminal(.errored(error))
    }

    public func dispose() {
        // Idempotent. Distinct from `close()`/`fail(_:)`: disposal tears down
        // the event sink WITHOUT firing a terminal event, mirroring
        // `MonaCancellationTokenSource.dispose` vs `cancel`. After dispose,
        // `send`/`close`/`fail`/`receive` are no-ops.
        var shouldTearDownEmitter = false
        _lock.lock()
        if !_disposed {
            _disposed = true
            shouldTearDownEmitter = true
        }
        _lock.unlock()
        if shouldTearDownEmitter {
            _emitter.dispose()
        }
    }

    /// Injects `bytes` received from the peer, firing `.received(bytes)` in
    /// arrival order. Host-side hook (NOT part of the `MonaMessageTransport`
    /// protocol surface): the concrete host adapter (T009) reads from the
    /// real byte stream and calls this to deliver `.received`. No-op after the
    /// transport has reached a terminal state or after `dispose()`.
    internal func receive(_ bytes: Data) {
        guard isOpen else { return }
        _emitter.fire(.received(bytes))
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
    /// `dispose()`.
    private func fireTerminal(_ terminal: Terminal) {
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
    }
}
