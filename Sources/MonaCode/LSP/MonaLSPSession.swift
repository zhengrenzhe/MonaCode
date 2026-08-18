// MonaLSPSession.swift
//
// P06-T004 — Implement LSP session state and 25 capability mappings.
//
// `MonaLSPSession` is the LSP session lifecycle state machine. It is the Swift
// counterpart of the LSP client's session state — the sequence
// initialize → initialized → (request/notification exchange) → shutdown → exit
// (Language Server Protocol 3.18, vendored via Monaco's `monaco-lsp-client`
// in monaco-editor 0.56.0). Beyond the linear lifecycle, the session tracks
// restart epoch (server restart invalidates every outstanding response),
// cancellation generation (cancellation requested since capture), and active
// progress tokens (server-initiated `$ /progress` streams).
//
// The session is a pure state machine: it holds no I/O and never sends bytes.
// The `MonaLSPClient` (this file's sibling) drives it through the transition
// methods as it encodes/decodes messages. Every transition is typed and
// deterministic: a legal transition returns the PREVIOUS state and advances;
// an illegal transition is a no-op returning `nil`. This matches Monaco's
// contract that the session has exactly one current state and the order of
// transitions is fully determined by the order of message events.
//
// Lifecycle + auxiliary states (frozen by P06-T004 / L2-R):
//
//   - `uninitialized`  — the session has not yet sent `initialize`.
//   - `initializing`   — `initialize` request sent, awaiting the response.
//   - `initialized`    — `initialize` response received + `initialized` sent.
//   - `shuttingDown`   — `shutdown` request sent, awaiting the response.
//   - `shutdown`       — `shutdown` response received; only `exit` is legal.
//   - `exited`         — `exit` notification sent; the session is terminal.
//   - `error`          — a fatal condition (transport failure, …) ended the
//                        session; only `restart` recovers from here.
//
// `restart` is the universal recovery: from any state it returns to
// `uninitialized` and bumps `epoch`. A response captured before a restart has
// a smaller epoch than the live session, so the client drops it as stale
// (the stale-response rule, operation 3). `requestCancellation` bumps the
// cancellation generation, which the publication gate reflects in every
// ticket captured before the bump.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The LSP session lifecycle state. One current state at a time; transitions
/// are deterministic (each is a single legal step or a no-op).
public enum MonaLSPSessionState: Equatable, Sendable {

    /// The session has not yet sent `initialize`.
    case uninitialized

    /// `initialize` request sent, awaiting the response.
    case initializing

    /// `initialize` response received + `initialized` notification sent. The
    /// session is open for request/notification exchange.
    case initialized

    /// `shutdown` request sent, awaiting the response.
    case shuttingDown

    /// `shutdown` response received. Only `exit` is a legal next step.
    case shutdown

    /// `exit` notification sent. The session is terminal.
    case exited

    /// A fatal condition ended the session. Only `restart` recovers from here.
    case error
}

/// A typed session error surfaced by `MonaLSPSession.fail(_:)`. Each case
/// corresponds to a distinct fatal condition.
public enum MonaLSPSessionError: Error, Equatable, Sendable {

    /// A transition was attempted that is not legal from the current state.
    case illegalTransition(from: MonaLSPSessionState, to: MonaLSPSessionState)

    /// A response arrived whose captured epoch no longer matches the live
    /// session epoch (server restarted since the request was issued).
    case staleResponse(epoch: Int, currentEpoch: Int)

    /// The transport failed with `message`.
    case transportFailure(String)
}

/// The LSP session lifecycle state machine. Holds the current state, the
/// restart epoch, the cancellation generation, the active progress tokens,
/// and the last fatal error. A pure state machine: no I/O, no bytes.
///
/// Create with `init()`. Drive the lifecycle with `beginInitialize` /
/// `completeInitialize` / `beginShutdown` / `completeShutdown` / `exit` /
/// `restart` / `fail`. Request cancellation with `requestCancellation`.
/// Manage progress tokens with `registerProgress` / `reportProgress` /
/// `unregisterProgress`.
public final class MonaLSPSession {

    private let _lock = NSLock()

    /// The current lifecycle state.
    public private(set) var state: MonaLSPSessionState = .uninitialized

    /// The restart epoch. Bumped by `restart()`; a response whose captured
    /// epoch is below the live value is stale and dropped.
    public private(set) var epoch: Int = 0

    /// The cancellation generation. Bumped by `requestCancellation()`. The
    /// publication gate reflects this in every ticket captured before the
    /// bump, so outstanding publications are dropped silently.
    public private(set) var cancellationGeneration: Int = 0

    /// The active progress tokens the server has registered via
    /// `window/workDoneProgress/create` (or the client via the corresponding
    /// request). Reporting progress for a token not in this set is a no-op.
    public var activeProgressTokens: Set<String> {
        _lock.lock()
        defer { _lock.unlock() }
        return _progressTokens
    }

    /// The last fatal error, set by `fail(_:)`. `nil` until a fatal condition.
    public private(set) var lastError: MonaLSPSessionError? = nil

    /// The set of active progress tokens.
    private var _progressTokens: Set<String> = []

    /// Creates a fresh session in the `uninitialized` state, epoch 0.
    public init() {}

    // MARK: - Lifecycle transitions

    /// `uninitialized → initializing`. Returns the previous state, or `nil`
    /// if the transition is illegal from the current state.
    @discardableResult
    public func beginInitialize() -> MonaLSPSessionState? {
        return transition(expected: .uninitialized, next: .initializing)
    }

    /// `initializing → initialized`. Returns the previous state, or `nil` if
    /// the transition is illegal from the current state.
    @discardableResult
    public func completeInitialize() -> MonaLSPSessionState? {
        return transition(expected: .initializing, next: .initialized)
    }

    /// `initialized → shuttingDown`. Returns the previous state, or `nil` if
    /// the transition is illegal from the current state.
    @discardableResult
    public func beginShutdown() -> MonaLSPSessionState? {
        return transition(expected: .initialized, next: .shuttingDown)
    }

    /// `shuttingDown → shutdown`. Returns the previous state, or `nil` if
    /// the transition is illegal from the current state.
    @discardableResult
    public func completeShutdown() -> MonaLSPSessionState? {
        return transition(expected: .shuttingDown, next: .shutdown)
    }

    /// `shutdown → exited`. Returns the previous state, or `nil` if the
    /// transition is illegal from the current state.
    @discardableResult
    public func exit() -> MonaLSPSessionState? {
        return transition(expected: .shutdown, next: .exited)
    }

    /// Any state (except `exited`) → `error`. Records `error` as the last
    /// fatal error. Returns the previous state, or `nil` if already `exited`
    /// (a terminal session cannot fail). From `error`, only `restart()`
    /// recovers.
    @discardableResult
    public func fail(_ error: MonaLSPSessionError) -> MonaLSPSessionState? {
        _lock.lock()
        if state == .exited {
            _lock.unlock()
            return nil
        }
        let prev = state
        state = .error
        lastError = error
        _lock.unlock()
        return prev
    }

    /// Any state → `uninitialized`, bumping `epoch`. The universal recovery:
    /// every outstanding response captured before the bump is stale (its epoch
    /// is below the live value). Returns the previous state (always non-nil —
    /// restart is legal from every state, including `exited`).
    @discardableResult
    public func restart() -> MonaLSPSessionState? {
        _lock.lock()
        let prev = state
        state = .uninitialized
        epoch &+= 1
        // A restart clears the progress tokens — the new server has not
        // registered any yet.
        _progressTokens.removeAll()
        _lock.unlock()
        return prev
    }

    // MARK: - Cancellation

    /// Requests cancellation: bumps the cancellation generation. Outstanding
    /// publications whose ticket was captured before the bump are dropped
    /// silently by the publication gate (P01-T010 / P05-T013).
    public func requestCancellation() {
        _lock.lock()
        cancellationGeneration &+= 1
        _lock.unlock()
    }

    // MARK: - Progress tokens

    /// Registers `token` as an active progress token. Returns `true` if it
    /// was newly registered; `false` if it was already active.
    @discardableResult
    public func registerProgress(token: String) -> Bool {
        _lock.lock()
        defer { _lock.unlock() }
        return _progressTokens.insert(token).inserted
    }

    /// Reports progress for `token`. Returns `true` if `token` was active
    /// (and remains active); `false` if `token` was not registered (a no-op).
    @discardableResult
    public func reportProgress(token: String) -> Bool {
        _lock.lock()
        defer { _lock.unlock() }
        return _progressTokens.contains(token)
    }

    /// Removes `token` from the active set (the progress stream completed).
    public func unregisterProgress(token: String) {
        _lock.lock()
        _progressTokens.remove(token)
        _lock.unlock()
    }

    // MARK: - Private

    /// Performs a single-state legal transition: if the current state is
    /// `expected`, advances to `next` and returns the previous state;
    /// otherwise returns `nil` (no-op). Thread-safe.
    @discardableResult
    private func transition(
        expected: MonaLSPSessionState, next: MonaLSPSessionState
    ) -> MonaLSPSessionState? {
        _lock.lock()
        if state != expected {
            _lock.unlock()
            return nil
        }
        let prev = state
        state = next
        _lock.unlock()
        return prev
    }
}
