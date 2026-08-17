// MonaCompositionSession.swift
//
// P04-T004 — Implement marked-text input and composition arbitration.
//
// `MonaCompositionSession` is the IME composition session state machine. macOS
// text input (the `NSTextInputClient` protocol) drives composition through a
// sequence of marked-text updates, terminated by a commit (final text
// inserted), a cancel (marked text discarded), or a fold (part committed, part
// newly marked). The session owns the marked-text state and the lifecycle
// transitions so the arbiter (`MonaCompositionArbiter`) can route every input
// decision through one state machine.
//
// States:
//
//   - `idle`       — no composition. Ready to begin.
//   - `composing`  — marked text is active (the IME is mid-composition).
//   - `committing` — finalization in progress (transient; the synchronous
//                     `commit`/`cancel`/`fold` path passes through here on its
//                     way to `committed`).
//   - `committed`  — terminal for this composition cycle. `reset()` returns the
//                     session to `idle` so a new composition can begin; `dispose()`
//                     marks the session permanently terminal.
//
// The session uses a deterministic injected clock (`() -> Double`, shared with
// the keybinding resolver P04-T003) for timeout. The IME composition has no
// fixed Monaco-side deadline (the IME owns the composition lifetime), but the
// session exposes `hasTimedOut()` so the platform layer can detect a stale
// composition (no marked-text updates for longer than the timeout) and cancel
// it — mirroring how the chord state (P04-T003) uses the same clock pattern.
//
// The session performs no platform dispatch and references no AppKit input
// type; it stores `NSRange` (Foundation) because the marked-text selected
// range and replacement range are UTF-16 ranges, matching the
// `NSTextInputClient` coordinate system.
//
// MonaCodeAppKit may import AppKit, CoreGraphics, Foundation, and MonaCode.

import Foundation
import MonaCode

// MARK: - MonaCompositionPhase

/// The phase of an IME composition session state machine.
public enum MonaCompositionPhase: Equatable, Hashable, Sendable {
    /// No composition active. Ready to begin.
    case idle
    /// Marked text is active; the IME is mid-composition.
    case composing
    /// Finalization in progress (transient; synchronous paths pass through here
    /// on the way to `committed`).
    case committing
    /// Terminal for this composition cycle. `reset()` returns to `idle`;
    /// `dispose()` makes this permanent.
    case committed
}

// MARK: - MonaCompositionTerminalOutcome

/// The outcome of a terminal transition (`commit`, `cancel`).
///
/// Carries the committed or discarded text so the arbiter and platform layer
/// can observe what the session finalized on, without re-reading session state.
public enum MonaCompositionTerminalOutcome: Equatable, Sendable {

    /// The composition was committed; the associated string is the final
    /// committed text (the text that replaced the marked text).
    case committed(String)

    /// The composition was cancelled; the associated string is the discarded
    /// marked text (or `nil` if there was no marked text to discard).
    case cancelled(String?)

    /// No composition was active (the session was `idle`); nothing happened.
    case nothingToCommit

    /// The session is permanently terminal (disposed, or already committed and
    /// not reset); the operation was rejected.
    case alreadyTerminal
}

// MARK: - MonaCompositionSession

/// The IME composition session state machine.
///
/// Owns the marked-text state (the marked text, its selected range within the
/// marked text, and the raw UTF-16 replacement range in the document) and the
/// lifecycle transitions: update, commit, cancel, fold (mark + insert), and
/// disposal. The deterministic clock is injected so tests advance time without
/// real timers; the same clock pattern is shared with `MonaChordState`
/// (P04-T003).
///
/// The session performs no platform dispatch. It is not thread-safe; the
/// editor pipeline that owns one session drives it from a single coordinator.
public final class MonaCompositionSession {

    // MARK: - Dependencies

    /// The injected deterministic clock. Returns the current time as a `Double`
    /// (seconds, any consistent time base). Tests inject a mutable counter;
    /// production shares the keybinding resolver's clock.
    private let clock: () -> Double

    /// The composition timeout interval in seconds. When the elapsed time since
    /// the last marked-text update exceeds this, `hasTimedOut()` returns `true`
    /// so the platform layer can cancel a stale composition.
    public let timeoutInterval: Double

    // MARK: - State

    /// The current phase of the state machine.
    public private(set) var phase: MonaCompositionPhase = .idle

    /// `true` when a composition is in progress (`composing` or `committing`).
    public var isActive: Bool {
        return phase == .composing || phase == .committing
    }

    /// `true` when the session is in the terminal `committed` phase.
    public var isTerminal: Bool {
        return phase == .committed
    }

    /// `true` when the session has been disposed — permanently terminal. All
    /// further operations are rejected.
    public private(set) var isDisposed: Bool = false

    /// The current marked text, or `nil` when not composing.
    public private(set) var markedText: String?

    /// The selection within the marked text (UTF-16 offsets relative to the
    /// marked text start).
    public private(set) var markedSelectedRange: NSRange = .notFound

    /// The raw UTF-16 replacement range in the document — where the marked text
    /// is inserted. Preserved verbatim (NOT converted to graphemes), matching
    /// the `NSTextInputClient` coordinate system. `NSNotFound` location means
    /// "replace the current marked range or selection."
    public private(set) var replacementRange: NSRange = .notFound

    /// The text committed by the most recent `commit` or `fold`. Observable so
    /// the arbiter and tests can verify what was finalized.
    public private(set) var lastCommittedText: String?

    /// The marked text discarded by the most recent `cancel`. `nil` if the
    /// cancel found no marked text.
    public private(set) var lastDiscardedMarkedText: String?

    /// The clock time at which the current composition was (last) started or
    /// updated. Used by `hasTimedOut()` and `elapsed`.
    private var lastActivityAt: Double = 0

    // MARK: - Init

    /// Creates a session with an injected deterministic clock and timeout.
    ///
    /// - Parameters:
    ///   - clock: A closure returning the current time. Injected for test
    ///     determinism — tests advance a captured variable instead of sleeping.
    ///   - timeoutInterval: The composition timeout in seconds. Defaults to
    ///     30.0. The composition is stale when elapsed > interval.
    public init(clock: @escaping () -> Double, timeoutInterval: Double = 30.0) {
        self.clock = clock
        self.timeoutInterval = timeoutInterval
    }

    // MARK: - Time

    /// The elapsed time since the current composition's last activity, in the
    /// injected clock's time base. `0` when not composing.
    public var elapsed: Double {
        guard phase == .composing || phase == .committing else { return 0 }
        return clock() - lastActivityAt
    }

    /// `true` when the composition is active AND the elapsed time is STRICTLY
    /// greater than `timeoutInterval`. Mirrors the chord-state timeout pattern
    /// (P04-T003): the threshold test is pure, the polling cadence is a
    /// platform concern.
    public func hasTimedOut() -> Bool {
        guard phase == .composing || phase == .committing else { return false }
        return (clock() - lastActivityAt) > timeoutInterval
    }

    // MARK: - Marked-text update

    /// Updates the marked text: `idle`/`committed` → `composing`, or
    /// `composing` → `composing` (refresh).
    ///
    /// Stores the marked text, its selected range, and the raw UTF-16
    /// replacement range verbatim. The replacement range is preserved as raw
    /// UTF-16 code units (NOT converted to graphemes) so ABC/Pinyin IME traces
    /// that span surrogate pairs are carried through unchanged.
    ///
    /// - Returns: `true` on success; `false` if the session is disposed.
    @discardableResult
    public func updateMarkedText(
        _ text: String,
        selectedRange: NSRange,
        replacementRange: NSRange
    ) -> Bool {
        guard !isDisposed else { return false }
        // From `committed`, auto-reset to `idle` so a new cycle can begin
        // without an explicit `reset()` call.
        if phase == .committed {
            resetMarkedState()
            phase = .idle
        }
        precondition(phase == .idle || phase == .composing,
                     "updateMarkedText from unexpected phase \(phase)")
        phase = .composing
        markedText = text
        markedSelectedRange = selectedRange
        self.replacementRange = replacementRange
        lastActivityAt = clock()
        return true
    }

    // MARK: - Commit

    /// Commits the composition with the given final text: `composing` →
    /// `committed`.
    ///
    /// The marked text is discarded and replaced by `text` in the document
    /// (the actual document mutation is the model input barrier's job, P04-T005;
    /// the session only records the lifecycle transition and the committed
    /// text).
    ///
    /// - Returns: `.committed(text)` on success; `.nothingToCommit` when idle;
    ///   `.alreadyTerminal` when disposed or already committed.
    @discardableResult
    public func commit(_ text: String) -> MonaCompositionTerminalOutcome {
        guard !isDisposed else { return .alreadyTerminal }
        guard phase == .composing else {
            return phase == .committed ? .alreadyTerminal : .nothingToCommit
        }
        phase = .committing
        lastCommittedText = text
        lastDiscardedMarkedText = nil
        resetMarkedState()
        phase = .committed
        return .committed(text)
    }

    // MARK: - Cancel

    /// Cancels the composition: `composing` → `committed`, discarding the
    /// marked text.
    ///
    /// - Returns: `.cancelled(markedText)` on success (the discarded marked
    ///   text, or `nil` if none); `.nothingToCommit` when idle;
    ///   `.alreadyTerminal` when disposed or already committed.
    @discardableResult
    public func cancel() -> MonaCompositionTerminalOutcome {
        guard !isDisposed else { return .alreadyTerminal }
        guard phase == .composing else {
            return phase == .committed ? .alreadyTerminal : .nothingToCommit
        }
        let discarded = markedText
        phase = .committing
        lastDiscardedMarkedText = discarded
        lastCommittedText = nil
        resetMarkedState()
        phase = .committed
        return .cancelled(discarded)
    }

    // MARK: - Fold (mark + insert)

    /// Folds a committed insertion and a new marked range into one operation:
    /// inserts `committedText` (committed/final) and then marks `markedText`.
    ///
    /// If a composition is already active, the old marked text is committed
    /// first (via the commit path), then the new fold begins. This models the
    /// ABC/Pinyin IME pattern where a candidate is confirmed and composition
    /// continues over a new range.
    ///
    /// - Returns: `true` on success; `false` if the session is disposed.
    @discardableResult
    public func fold(
        committedText: String,
        markedText: String,
        markedSelectedRange: NSRange,
        replacementRange: NSRange
    ) -> Bool {
        guard !isDisposed else { return false }
        // If composing, commit the old marked text first (one session invariant:
        // the old composition must finalize before the new one begins).
        if phase == .composing {
            let oldMarked = markedText ?? ""
            _ = commit(oldMarked)
            // After commit the phase is `committed`; fall through to begin the
            // new composition via updateMarkedText (which auto-resets).
        }
        let ok = updateMarkedText(markedText, selectedRange: markedSelectedRange, replacementRange: replacementRange)
        if ok {
            // The fold's committed text is the inserted/finalized text of this
            // operation; it takes precedence over the old marked text's commit.
            lastCommittedText = committedText
        }
        return ok
    }

    // MARK: - Disposal & reset

    /// Disposes the session: any state → `committed`, permanently. All further
    /// operations are rejected. Used when the editor is tearing down or the
    /// input context is invalidated.
    public func dispose() {
        if phase == .composing {
            lastDiscardedMarkedText = markedText
        }
        resetMarkedState()
        phase = .committed
        isDisposed = true
    }

    /// Resets the session from `committed` back to `idle` so a new composition
    /// cycle can begin. A no-op (returns without changing state) when disposed.
    public func reset() {
        guard !isDisposed else { return }
        resetMarkedState()
        phase = .idle
    }

    /// Clears the marked-text state (but not the committed/discarded records).
    private func resetMarkedState() {
        markedText = nil
        markedSelectedRange = .notFound
        replacementRange = .notFound
        lastActivityAt = 0
    }
}

// MARK: - NSRange.notFound convenience

extension NSRange {
    /// The "not found" range: `location == NSNotFound`, `length == 0`.
    internal static let notFound = NSRange(location: NSNotFound, length: 0)
}
