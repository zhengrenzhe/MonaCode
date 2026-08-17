// MonaAXFocusCoordinator.swift
//
// P04-T012 — Implement focus modes and the localized announcement bridge.
//
// `MonaAXFocusCoordinator` is the single accessibility focus state machine for
// the AppKit editor. It models ALL focus modes — editor, widget,
// accessibility-optimized, tab-focus, and temporary — as ONE machine with a
// mutually-exclusive `currentMode` and a temporary push/pop, NOT five
// independent flags.
//
// The five modes:
//   - editor: focus is in the text area (the native-text surface, P04-T010).
//   - widget: focus moved to an overlay widget (hover widget, suggestion,
//     inline hint).
//   - accessibilityOptimized: VoiceOver-optimized focus — when VoiceOver is
//     active, focus is forced to the most relevant AX element.
//   - tabFocus: keyboard tab-navigation focus.
//   - temporary: a transient focus grab that restores the prior mode on
//     release.
//
// `.temporary` is the push/pop mode: entering it saves the current mode;
// `releaseTemporary()` restores it; a direct transition out of `.temporary`
// discards the saved mode. This is the temporary focus transition.
//
// `currentMode` is mutually exclusive — exactly one mode is active at a time —
// and every transition routes through one authoritative `transition(to:)`
// entry point. That is what makes the five modes a single state machine rather
// than five independent flags that could be simultaneously set.
//
// This coordinator sits on top of the AX element graph (P04-T011) and feeds the
// AX mutation gateway (P04-T013), which validates focus before commit.
//
// `MonaCodeAppKit` may `import AppKit`, `import Foundation`, and `import MonaCode`.

import AppKit
import Foundation

/// The five accessibility focus modes the AppKit editor exposes — modelled as
/// one state machine, not five independent flags.
public enum MonaAXFocusMode: String, Sendable, CaseIterable {

    /// Focus is in the text area (the native-text surface, P04-T010).
    case editor

    /// Focus moved to an overlay widget (hover widget, suggestion, inline hint).
    case widget

    /// VoiceOver-optimized focus: when VoiceOver is active, focus is forced to
    /// the most relevant AX element.
    case accessibilityOptimized

    /// Keyboard tab-navigation focus.
    case tabFocus

    /// A transient focus grab that restores the prior mode on release. Entering
    /// `.temporary` saves the current mode; `releaseTemporary()` restores it.
    case temporary
}

/// The single accessibility focus state machine for the AppKit editor.
///
/// `currentMode` is mutually exclusive — exactly one mode is active at a time —
/// and every transition routes through `transition(to:)`. The `.temporary` mode
/// is a push/pop: entering it saves the prior mode; `releaseTemporary()`
/// restores it; a direct transition out of `.temporary` discards the saved mode.
///
/// Construct with `init(initial:)` (defaults to `.editor`). Read `currentMode`
/// and `savedMode` to observe the machine's state. Drive it with
/// `transition(to:)` and `releaseTemporary()`.
public final class MonaAXFocusCoordinator {

    /// The currently active focus mode. Mutually exclusive — exactly one mode
    /// is active at a time.
    public private(set) var currentMode: MonaAXFocusMode

    /// The mode saved when `.temporary` was entered; restored on
    /// `releaseTemporary()`. `nil` outside `.temporary`. A direct transition
    /// out of `.temporary` discards this slot.
    public private(set) var savedMode: MonaAXFocusMode?

    /// Creates the coordinator in `initial` (default `.editor`).
    public init(initial: MonaAXFocusMode = .editor) {
        self.currentMode = initial
    }

    /// Transitions to `mode` as one state-machine step.
    ///
    /// - Entering `.temporary` from a non-temporary mode saves the current mode
    ///   in `savedMode` (the push). Re-entering `.temporary` while already in
    ///   `.temporary` is idempotent: `savedMode` is unchanged.
    /// - A direct transition out of `.temporary` (to a non-temporary mode)
    ///   discards `savedMode` and sets `currentMode` to the target.
    /// - Any other transition sets `currentMode` to the target.
    /// - Transitioning to the current mode is a no-op.
    public func transition(to mode: MonaAXFocusMode) {
        if mode == currentMode { return }
        if mode == .temporary {
            // Push: save the current mode so releaseTemporary can restore it.
            savedMode = currentMode
            currentMode = .temporary
            return
        }
        if currentMode == .temporary {
            // Direct exit from .temporary abandons the saved mode.
            savedMode = nil
        }
        currentMode = mode
    }

    /// Releases `.temporary` and restores the saved mode (the pop).
    ///
    /// - Returns: The restored mode, or `nil` if not currently in `.temporary`
    ///   (no-op). The `savedMode` slot is cleared on restore.
    @discardableResult
    public func releaseTemporary() -> MonaAXFocusMode? {
        guard currentMode == .temporary, let restored = savedMode else {
            return nil
        }
        savedMode = nil
        currentMode = restored
        return restored
    }
}
