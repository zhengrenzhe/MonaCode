// MonaCompositionArbiter.swift
//
// P04-T004 — Implement marked-text input and composition arbitration.
//
// `MonaCompositionArbiter` arbitrates between keybinding resolution (P04-T003),
// command insertion, marked-text update, commit, cancel, fold, and disposal
// through ONE `MonaCompositionSession` state machine. It ensures only one
// composition session is active per editor and resolves the central conflict —
// a keybinding arriving during an active composition — by either absorbing
// the event (the composition owns it) or committing the composition first and
// then dispatching the command.
//
// Arbitration rules (ported from Monaco's `AbstractKeybindingService` +
// `IMESupport` input-layer contract):
//
//   - When a composition is active (`session.isActive`):
//       * If the event's `isComposing` flag is `true`, the IME is driving the
//         composition — the keybinding service must NOT dispatch. The event is
//         absorbed (handled, prevent-default, stop-propagation).
//       * If `isComposing` is `false` and the event resolves to a command, the
//         composition is committed first (its current marked text is finalized),
//         then the command dispatches. This lets a Cmd+S during Pinyin
//         composition save the committed text rather than losing it.
//       * If `isComposing` is `false` and no command matches, the event is
//         absorbed — the input context / IME handles it (e.g. a raw key the IME
//         turns into a candidate selection).
//   - When no composition is active, the keybinding is resolved normally: a
//     match dispatches; no match passes through to the platform default.
//
// One-session invariant: the arbiter owns one `MonaCompositionSession`.
// Starting a new composition (via `updateMarkedText`) while one is active
// commits the old first, then begins the new — exactly one session is ever
// active per editor.
//
// The arbiter performs no platform dispatch and references no AppKit input
// type beyond the session's `NSRange` (Foundation). The platform layer reads
// the `MonaCompositionArbitration` decision and the derived
// `MonaKeyDispatchOutcome` and applies them at the native boundary.
//
// MonaCodeAppKit may import AppKit, CoreGraphics, Foundation, and MonaCode.

import Foundation
import MonaCode

// MARK: - MonaCompositionArbitration

/// The arbitration decision for one key event through the composition arbiter.
///
/// The platform layer reads this decision (and the derived `dispatchOutcome`)
/// to decide what to do at the native boundary: whether to prevent the default,
/// stop propagation, and whether a command was dispatched.
public enum MonaCompositionArbitration: Equatable, Sendable {

    /// The composition absorbed the event (the IME owns it). The keybinding
    /// service did NOT dispatch. The platform should prevent its default and
    /// stop propagation so the event is not double-handled.
    case absorbedByComposition

    /// An active composition was committed first, then the matched command
    /// dispatched. The associated command ID is the dispatched command.
    case committedThenDispatched(commandId: String)

    /// No composition was active; the matched command dispatched. The
    /// associated command ID is the dispatched command.
    case dispatched(commandId: String)

    /// No composition was active and no command matched; the platform should
    /// perform its default behavior (pass-through).
    case passThrough

    /// The session is disposed (or otherwise unable to arbitrate); the event
    /// was not handled. The platform should perform its default behavior.
    case noOp

    /// The `MonaKeyDispatchOutcome` the platform layer should apply for this
    /// arbitration decision.
    ///
    /// - Absorbed / committed-then-dispatched / dispatched: the event was
    ///   handled — prevent the default and stop propagation.
    /// - Pass-through / no-op: the platform default (`MonaKeyDispatchOutcome.default`).
    public var dispatchOutcome: MonaKeyDispatchOutcome {
        switch self {
        case .absorbedByComposition,
             .committedThenDispatched,
             .dispatched:
            return MonaKeyDispatchOutcome(handled: true, preventDefault: true, stopPropagation: true)
        case .passThrough, .noOp:
            return .default
        }
    }
}

// MARK: - MonaCompositionArbiter

/// Arbitrates keybinding, command insertion, marked-text update, commit,
/// cancel, fold, and disposal through ONE `MonaCompositionSession`.
///
/// Ensures only one composition session is active per editor. Resolves
/// keybinding-during-composition conflicts (absorb vs. commit-first-then-
/// dispatch). The arbiter owns no platform type; the platform layer reads the
/// `MonaCompositionArbitration` decision and the derived `MonaKeyDispatchOutcome`.
///
/// Not thread-safe; the editor pipeline that owns one arbiter drives it from a
/// single coordinator.
public final class MonaCompositionArbiter {

    // MARK: - Dependencies

    /// The keybinding resolver (P04-T003). Produces dispatch decisions without
    /// invoking platform APIs.
    private let resolver: MonaKeybindingResolver

    /// The per-editor chord state (P04-T003), driven by the resolver.
    private let chordState: MonaChordState

    /// The one composition session per editor. The arbiter routes every
    /// composition operation through this single state machine.
    private let session: MonaCompositionSession

    /// The deterministic clock (shared with the keybinding resolver / chord
    /// state). Injected for test determinism.
    private let clock: () -> Double

    // MARK: - Init

    /// Creates an arbiter over the given resolver, chord state, session, and
    /// clock.
    ///
    /// - Parameters:
    ///   - resolver: The keybinding resolver (P04-T003).
    ///   - chordState: The per-editor chord state (P04-T003).
    ///   - session: The one composition session per editor.
    ///   - clock: The deterministic clock, shared with the resolver / chord state.
    public init(
        resolver: MonaKeybindingResolver,
        chordState: MonaChordState,
        session: MonaCompositionSession,
        clock: @escaping () -> Double
    ) {
        self.resolver = resolver
        self.chordState = chordState
        self.session = session
        self.clock = clock
    }

    // MARK: - Public: session state

    /// The current phase of the one composition session.
    public var sessionPhase: MonaCompositionPhase {
        return session.phase
    }

    /// `true` when a composition is active (the session is composing).
    public var hasActiveComposition: Bool {
        return session.isActive
    }

    /// The text committed by the most recent commit/fold through the arbiter.
    public var sessionLastCommittedText: String? {
        return session.lastCommittedText
    }

    // MARK: - Public: key arbitration

    /// Arbitrates a key event, deciding whether the composition absorbs it, the
    /// composition commits first and then a command dispatches, or no
    /// composition resolves the keybinding normally.
    ///
    /// - Parameters:
    ///   - event: The platform-neutral key event (P04-T001).
    ///   - context: The keybinding context (P04-T003) for when-clause matching.
    /// - Returns: The arbitration decision.
    public func handleKey(
        _ event: MonaKeyEvent,
        context: MonaKeybindingContext
    ) -> MonaCompositionArbitration {
        // A disposed session cannot arbitrate.
        if session.isDisposed {
            return .noOp
        }

        let compositionActive = session.isActive

        // --- Composition active: absorb or commit-first-then-dispatch. ---
        if compositionActive {
            if event.isComposing {
                // The IME is driving (isComposing == true): the composition
                // absorbs the event. The keybinding service must NOT dispatch.
                return .absorbedByComposition
            }
            // isComposing == false during composition: resolve the keybinding.
            // A match commits the composition first, then dispatches. No match
            // is absorbed (the input context / IME handles the raw key).
            let resolution = resolver.resolve(event: event, context: context, chordState: chordState)
            if let commandId = resolution.commandId {
                // Commit the current marked text first, then dispatch.
                let markedText = session.markedText ?? ""
                _ = session.commit(markedText)
                return .committedThenDispatched(commandId: commandId)
            }
            return .absorbedByComposition
        }

        // --- No composition: resolve the keybinding normally. ---
        let resolution = resolver.resolve(event: event, context: context, chordState: chordState)
        if let commandId = resolution.commandId {
            return .dispatched(commandId: commandId)
        }
        return .passThrough
    }

    // MARK: - Public: session operations (one-session invariant)

    /// Updates the marked text through the one session. If a composition is
    /// already active, the old is committed first (one-session invariant),
    /// then the new begins.
    ///
    /// - Returns: `true` on success; `false` if the session is disposed.
    @discardableResult
    public func updateMarkedText(
        _ text: String,
        selectedRange: NSRange,
        replacementRange: NSRange
    ) -> Bool {
        if session.isActive {
            // One-session invariant: commit the old composition first.
            let oldMarked = session.markedText ?? ""
            _ = session.commit(oldMarked)
        }
        return session.updateMarkedText(text, selectedRange: selectedRange, replacementRange: replacementRange)
    }

    /// Commits the composition through the one session.
    ///
    /// - Returns: The terminal outcome (`.committed(text)` on success).
    @discardableResult
    public func commit(_ text: String) -> MonaCompositionTerminalOutcome {
        return session.commit(text)
    }

    /// Cancels the composition through the one session.
    ///
    /// - Returns: The terminal outcome (`.cancelled(markedText)` on success).
    @discardableResult
    public func cancel() -> MonaCompositionTerminalOutcome {
        return session.cancel()
    }

    /// Folds a committed insertion and a new marked range through the one
    /// session.
    ///
    /// - Returns: `true` on success; `false` if the session is disposed.
    @discardableResult
    public func fold(
        committedText: String,
        markedText: String,
        markedSelectedRange: NSRange,
        replacementRange: NSRange
    ) -> Bool {
        return session.fold(
            committedText: committedText,
            markedText: markedText,
            markedSelectedRange: markedSelectedRange,
            replacementRange: replacementRange
        )
    }

    /// Disposes the one session — permanently terminal. All further operations
    /// are rejected.
    public func dispose() {
        session.dispose()
    }
}
