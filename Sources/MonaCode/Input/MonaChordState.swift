// MonaChordState.swift
//
// P04-T003 — Port keybinding resolution and chord state to Core.
//
// `MonaChordState` is the per-editor chord state machine. Monaco's
// `AbstractKeybindingService` keeps a per-editor "current chord" (the first
// part of a two-part keybinding that was pressed and is awaiting its second
// part) and a deadline. The service polls every 500 ms; if the elapsed time
// since the first part is STRICTLY greater than 5000 ms, or the document loses
// focus, the chord is abandoned.
//
// In Core, the *state* lives here and the *polling* lives in the platform
// layer (P04-T002+, which calls `hasTimedOut()` on a timer). This keeps Core
// free of timers, run loops, and platform types: the only time source is an
// injected `() -> Double` clock, so tests are deterministic.
//
// The state machine has two phases:
//
//   - `idle`           — no chord in progress.
//   - `awaitingSecond` — the first part matched and the resolver is waiting
//                         for the second key, with a deadline recorded against
//                         the injected clock.
//
// Transitions are driven by the resolver:
//
//   - `enterChord(_:)`            — idle → awaitingSecond. Records the
//                                    keybinding that started the chord (so the
//                                    resolver can re-check its when-clause
//                                    after a context change) and the entry time
//                                    (so `hasTimedOut()` can compute elapsed).
//   - `completeChord()`           — awaitingSecond → idle. The second part
//                                    matched.
//   - `cancel()`                   — awaitingSecond → idle. Used for timeout,
//                                    focus loss, a non-matching second key
//                                    (replay), and context-change replay.
//   - `hasTimedOut()`              — `true` when awaitingSecond AND
//                                    `clock() - enteredAt > timeoutInterval`
//                                    (strictly greater, mirroring Monaco's
//                                    `elapsed > 5000` check).
//
// The chord timeout interval defaults to 5.0 seconds (Monaco's 5000 ms). The
// clock is injected so tests can advance time without `sleep` or real timers.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The phase of a per-editor chord state machine.
public enum MonaChordPhase: Equatable, Hashable, Sendable {
    /// No chord in progress.
    case idle
    /// The first part of a chord matched; awaiting the second key.
    case awaitingSecond
}

/// The chord-related outcome of resolving one key event.
///
/// Reported by `MonaKeybindingResolver.resolve` so the platform layer can
/// drive chord UI (e.g. the "waiting for second key of chord" status hint)
/// without re-deriving it.
public enum MonaChordStatus: Equatable, Hashable, Sendable {
    /// No chord interaction: the event was resolved as a normal (non-chord)
    /// key — either a single command dispatched or no match.
    case none
    /// The event matched the first part of a chord keybinding; the resolver
    /// entered the chord state and is awaiting the second key.
    case entered
    /// The event matched the second part of an in-progress chord; the chord's
    /// command was dispatched.
    case completed
    /// An in-progress chord was cancelled by this event — a timeout, a
    /// non-matching second key (replay), or an explicit context-change
    /// re-evaluation. The event may still have dispatched a command via
    /// replay; check `MonaKeybindingResolution.commandId`.
    case cancelled
}

/// Per-editor chord state with a deterministic injected clock.
///
/// Tracks the current chord sequence (the keybinding that started it) and a
/// timeout deadline. Core owns the *state*; the platform layer owns the
/// *polling* (it calls `hasTimedOut()` on a timer). The clock is injected as
/// `() -> Double` so tests advance time deterministically without real timers.
public final class MonaChordState {

    /// The current phase of the chord state machine.
    public private(set) var phase: MonaChordPhase = .idle

    /// The keybinding whose first part started the current chord, or `nil`
    /// when idle. The resolver re-checks this keybinding's when-clause after a
    /// context change to decide whether the in-progress chord is still valid.
    public private(set) var firstPartKeybinding: MonaKeybinding?

    /// The clock time at which the current chord was entered (seconds, in the
    /// injected clock's time base). `0` when idle.
    public private(set) var enteredAt: Double = 0

    /// The chord timeout interval in seconds. Defaults to 5.0 (Monaco's
    /// 5000 ms). The chord expires when the elapsed time is STRICTLY greater
    /// than this value.
    public let timeoutInterval: Double

    /// The injected deterministic clock. Returns the current time as a
    /// `Double` (seconds, any consistent time base). Tests inject a mutable
    /// counter; production injects the platform's monotonic clock.
    private let clock: () -> Double

    /// Creates a chord state with an injected clock and timeout interval.
    ///
    /// - Parameters:
    ///   - clock: A closure returning the current time. Injected for
    ///     test determinism — tests advance a captured variable instead of
    ///     sleeping.
    ///   - timeoutInterval: The chord timeout in seconds. Defaults to 5.0
    ///     (Monaco's 5000 ms). The chord expires when elapsed > interval.
    public init(clock: @escaping () -> Double, timeoutInterval: Double = 5.0) {
        self.clock = clock
        self.timeoutInterval = timeoutInterval
    }

    /// `true` when a chord is in progress (phase == awaitingSecond).
    public var isActive: Bool { phase == .awaitingSecond }

    /// The elapsed time since the current chord was entered, in the injected
    /// clock's time base. `0` when idle.
    public var elapsed: Double {
        guard phase == .awaitingSecond else { return 0 }
        return clock() - enteredAt
    }

    /// `true` when the chord is active AND the elapsed time is STRICTLY
    /// greater than `timeoutInterval`. Mirrors Monaco's `elapsed > 5000`
    /// check (polling cadence is a platform concern; this is the pure
    /// threshold test).
    public func hasTimedOut() -> Bool {
        guard phase == .awaitingSecond else { return false }
        return (clock() - enteredAt) > timeoutInterval
    }

    /// Records the first part of a chord: idle → awaitingSecond.
    ///
    /// The resolver calls this when a chord keybinding's first part matches.
    /// Stores the keybinding (for when-clause re-evaluation) and the entry
    /// time (for timeout).
    public func enterChord(_ keybinding: MonaKeybinding) {
        phase = .awaitingSecond
        firstPartKeybinding = keybinding
        enteredAt = clock()
    }

    /// Completes the chord: awaitingSecond → idle.
    ///
    /// The resolver calls this when the second part of an in-progress chord
    /// matches and the command has been dispatched.
    public func completeChord() {
        reset()
    }

    /// Cancels the chord: awaitingSecond → idle.
    ///
    /// Used for timeout (the platform polls `hasTimedOut()` and cancels), a
    /// non-matching second key (replay), focus loss, and context-change
    /// re-evaluation. A no-op when idle.
    public func cancel() {
        reset()
    }

    /// Resets the state machine to idle, clearing the recorded first part.
    private func reset() {
        phase = .idle
        firstPartKeybinding = nil
        enteredAt = 0
    }
}
