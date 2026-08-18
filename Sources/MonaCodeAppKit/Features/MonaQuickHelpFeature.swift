// MonaQuickHelpFeature.swift
//
// P05-T143 — Implement retained feature quickHelp.
//
// `MonaQuickHelpFeature` is the Swift counterpart of Monaco's `quickHelp`
// contribution (monaco-editor 0.56.0): it presents retained keyboard and
// accessibility help from localized messages. The keyboard help is built from
// the builtin keybindings (T003 `MonaBuiltinKeybindings`), with each entry's
// key label formatted through `MonaLocalization` (T007). The accessibility help
// is a localized message resolved through `MonaLocalization`.
//
// The keyboard-help entries list every builtin keybinding row (command + key
// label + when-clause). The key label is a human-readable combination of the
// modifier set and the key code (e.g. "Cmd+Shift+O", "F1"). The accessibility
// help message is formatted through `MonaLocalization.format` under the
// requested profile, so the pseudo profile transforms it.
//
// The feature is an AppKit surface (`import AppKit`, `import Foundation`,
// `import MonaCode`). It performs the three implementation operations every
// retained feature performs:
//
//   1. Feature-specific behavior — `keyboardHelp(profile:)`,
//      `accessibilityHelp(profile:)`, `presentHelp(profile:)`: build the
//      keyboard-help entries from builtin keybindings and the accessibility
//      help from localized messages.
//   2. Register the exact feature identity `quickHelp` and its declared
//      commands, actions, contributions, options, menus, and keybindings,
//      referenced verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import AppKit
import Foundation
import MonaCode

/// A keyboard-help entry: the command, its formatted key label, and the
/// optional when-clause.
public struct MonaQuickHelpKeyboardEntry: Equatable, Sendable {

    /// The command ID dispatched by this keybinding.
    public let command: String

    /// The human-readable key label (e.g. "F1", "Cmd+Shift+O").
    public let keyLabel: String

    /// The when-clause context expression, or `nil` when unconditional.
    public let `when`: String?

    public init(command: String, keyLabel: String, when: String?) {
        self.command = command
        self.keyLabel = keyLabel
        self.when = when
    }
}

/// A quickHelp presentation: the keyboard-help entries + the accessibility
/// help message.
public struct MonaQuickHelpPresentation: Equatable {

    /// The keyboard-help entries (one per builtin keybinding row).
    public let keyboardEntries: [MonaQuickHelpKeyboardEntry]

    /// The localized accessibility help message.
    public let accessibilityMessage: String

    public init(keyboardEntries: [MonaQuickHelpKeyboardEntry], accessibilityMessage: String) {
        self.keyboardEntries = keyboardEntries
        self.accessibilityMessage = accessibilityMessage
    }
}

/// A quickHelp event: the current presentation.
public struct MonaQuickHelpEvent: Equatable {

    /// The presentation after the change.
    public let presentation: MonaQuickHelpPresentation

    public init(presentation: MonaQuickHelpPresentation) {
        self.presentation = presentation
    }
}

/// The quickHelp feature: present retained keyboard and accessibility help from
/// localized messages.
///
/// The feature identity `quickHelp` and its declared slice are referenced
/// verbatim from the frozen registries. The keyboard help is built from
/// `MonaBuiltinKeybindings` (T003); the accessibility help is a localized
/// message resolved through `MonaLocalization` (T007). Model mutation (inserting
/// the help text) is routed through `MonaTransactionGateway`; asynchronous
/// publication through `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal
/// through `MonaEmitter`; localization through `MonaLocalization`; and degraded
/// plain-text behavior through `MonaPlainTextLanguage`.
public final class MonaQuickHelpFeature: MonaDisposable {

    /// The frozen feature identity (`"quickHelp"`).
    public static let featureId = "quickHelp"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order. quickHelp declares no labeled
    /// actions — it is a controller that presents help, not an action target.
    public static let declaredActionIds: [String] = []

    /// The declared command IDs. quickHelp declares no commands.
    public static let declaredCommandIds: [String] = []

    /// The declared contribution IDs. The shared quick-input controller
    /// (`editor.controller.quickInput`, ordinal 52) is the quick-help surface's
    /// contribution.
    public static let declaredContributionIds: [String] = [
        "editor.controller.quickInput"
    ]

    /// The declared keybinding commands. quickHelp registers no default
    /// keybindings.
    public static let declaredKeybindingCommands: [String] = []

    /// The declared option names. quickHelp owns no editor options.
    public static let declaredOptionIds: [String] = []

    /// The declared menu IDs. quickHelp registers no menu items.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    private let emitter = MonaEmitter<MonaQuickHelpEvent>()

    /// The event stream for quickHelp changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaQuickHelpEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the quickHelp feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    // MARK: - 1. Feature-specific behavior: keyboard + accessibility help

    /// Builds the keyboard-help entries from the builtin keybindings (T003),
    /// formatting each entry's key label through `MonaLocalization` (T007)
    /// under `profile`. Fires an event with the built presentation. Returns an
    /// empty array after `dispose()`.
    @discardableResult
    public func keyboardHelp(
        profile: MonaCodeEnvironmentProfile
    ) -> [MonaQuickHelpKeyboardEntry] {
        guard !isDisposed else {
            emitter.fire(MonaQuickHelpEvent(presentation: MonaQuickHelpPresentation(
                keyboardEntries: [],
                accessibilityMessage: ""
            )))
            return []
        }
        let entries: [MonaQuickHelpKeyboardEntry] = MonaBuiltinKeybindings.rows.map { row in
            let rawLabel = Self.formatKeyLabel(row.keybinding)
            let label = MonaLocalization.format(rawLabel, args: [], profile: profile)
            return MonaQuickHelpKeyboardEntry(
                command: row.keybinding.command,
                keyLabel: label,
                when: row.keybinding.when
            )
        }
        let accessibility = accessibilityHelp(profile: profile)
        emitter.fire(MonaQuickHelpEvent(presentation: MonaQuickHelpPresentation(
            keyboardEntries: entries,
            accessibilityMessage: accessibility
        )))
        return entries
    }

    /// Returns the localized accessibility help message, formatted through
    /// `MonaLocalization` under `profile`. Returns an empty string after
    /// `dispose()`.
    public func accessibilityHelp(
        profile: MonaCodeEnvironmentProfile
    ) -> String {
        guard !isDisposed else { return "" }
        // The accessibility help message is formatted through MonaLocalization
        // so the pseudo profile transforms it (fullwidth brackets).
        return MonaLocalization.format(
            "Show Editor Accessibility Help",
            args: [],
            profile: profile
        )
    }

    /// Presents the combined help (keyboard entries + accessibility message)
    /// under `profile`. Fires an event with the presentation. Returns an empty
    /// presentation after `dispose()`.
    @discardableResult
    public func presentHelp(
        profile: MonaCodeEnvironmentProfile
    ) -> MonaQuickHelpPresentation {
        guard !isDisposed else {
            let empty = MonaQuickHelpPresentation(keyboardEntries: [], accessibilityMessage: "")
            emitter.fire(MonaQuickHelpEvent(presentation: empty))
            return empty
        }
        let entries = keyboardHelp(profile: profile)
        let message = accessibilityHelp(profile: profile)
        // keyboardHelp already fired; do not double-fire.
        return MonaQuickHelpPresentation(keyboardEntries: entries, accessibilityMessage: message)
    }

    // MARK: - 3a. Mutation → MonaTransactionGateway

    /// Commits `text` as an insertion at `range` through `gateway` as one
    /// ordered unit — inserting the help text into the model. Returns the
    /// reconciliation outcome. A no-op after `dispose()` (returns `.dropped`).
    @discardableResult
    public func commitHelpText(
        _ text: String,
        at range: MonaRange,
        gateway: MonaTransactionGateway
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let transaction = gateway.beginTransaction()
        transaction.prepareEdits([
            MonaModelEditOperation(range: range, text: text)
        ])
        return gateway.commit(transaction)
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `presentation` through the shared provider executor, normalized
    /// onto the deterministic microtask queue. `receive` runs ONLY when the queue
    /// is drained (FIFO), after the publication ticket is validated. After
    /// `dispose()`, returns `false` and publishes nothing.
    @discardableResult
    public func publishHelp(
        _ presentation: MonaQuickHelpPresentation,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaQuickHelpPresentation) -> Void
    ) -> Bool {
        guard !isDisposed else { return false }
        return executor.publish(
            .synchronous(presentation),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, and `keyboardHelp` /
    /// `accessibilityHelp` / `presentHelp` / `commitHelpText` / `publishHelp`
    /// are no-ops.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        _lock.unlock()
        if !already {
            emitter.dispose()
        }
    }

    // MARK: - 3d. Localization → MonaLocalization

    /// Returns the declared action labels formatted through the shared
    /// `MonaLocalization` surface under `profile`. quickHelp declares no
    /// actions, so this returns an empty array under every profile.
    public func localizedActionLabels(profile: MonaCodeEnvironmentProfile) -> [String] {
        let registry = MonaActionRegistry()
        return Self.declaredActionIds.map { id in
            let label = registry.identity(for: id)?.label ?? id
            return MonaLocalization.format(label, args: [], profile: profile)
        }
    }

    // MARK: - 3e. Degraded plain-text → MonaPlainTextLanguage

    /// The plain-text fallback language. quickHelp needs no tokenization; it
    /// degrades to plain text for its tokenization needs.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — quickHelp performs no tokenization-dependent work and degrades
    /// gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Formats a `MonaKeybinding` into a human-readable key label (e.g.
    /// "Cmd+Shift+O", "F1"). The modifier names follow the macOS convention
    /// (ctrlCmd → Cmd, alt → Option, winCtrl → Ctrl).
    private static func formatKeyLabel(_ keybinding: MonaKeybinding) -> String {
        var parts: [String] = []
        let mods = keybinding.modifiers
        if mods.contains(.winCtrl) { parts.append("Ctrl") }
        if mods.contains(.alt) { parts.append("Option") }
        if mods.contains(.shift) { parts.append("Shift") }
        if mods.contains(.ctrlCmd) { parts.append("Cmd") }
        parts.append(keyName(for: keybinding.key))
        if let chordKey = keybinding.chordKey {
            parts.append(" ")
            var chordParts: [String] = []
            let chordMods = keybinding.chordModifiers
            if chordMods.contains(.winCtrl) { chordParts.append("Ctrl") }
            if chordMods.contains(.alt) { chordParts.append("Option") }
            if chordMods.contains(.shift) { chordParts.append("Shift") }
            if chordMods.contains(.ctrlCmd) { chordParts.append("Cmd") }
            chordParts.append(keyName(for: chordKey))
            parts.append(contentsOf: chordParts)
        }
        return parts.joined(separator: "+")
    }

    /// Maps a `MonaKeyCode` to its human-readable name.
    private static func keyName(for code: MonaKeyCode) -> String {
        switch code.rawValue {
        case MonaKeyCode.escape.rawValue: return "Esc"
        case MonaKeyCode.tab.rawValue: return "Tab"
        case MonaKeyCode.enter.rawValue: return "Enter"
        case MonaKeyCode.space.rawValue: return "Space"
        case MonaKeyCode.pageUp.rawValue: return "PageUp"
        case MonaKeyCode.pageDown.rawValue: return "PageDown"
        case MonaKeyCode.end.rawValue: return "End"
        case MonaKeyCode.home.rawValue: return "Home"
        case MonaKeyCode.leftArrow.rawValue: return "Left"
        case MonaKeyCode.upArrow.rawValue: return "Up"
        case MonaKeyCode.rightArrow.rawValue: return "Right"
        case MonaKeyCode.downArrow.rawValue: return "Down"
        case MonaKeyCode.insert.rawValue: return "Insert"
        case MonaKeyCode.delete.rawValue: return "Delete"
        case MonaKeyCode.backspace.rawValue: return "Backspace"
        case MonaKeyCode.pauseBreak.rawValue: return "Pause"
        case MonaKeyCode.capsLock.rawValue: return "CapsLock"
        case MonaKeyCode.numLock.rawValue: return "NumLock"
        case MonaKeyCode.scrollLock.rawValue: return "ScrollLock"
        case MonaKeyCode.contextMenu.rawValue: return "Menu"
        case MonaKeyCode.meta.rawValue: return "Meta"
        case MonaKeyCode.dependsOnKbLayout.rawValue: return "?"
        case MonaKeyCode.unknown.rawValue: return "?"
        default:
            if code.rawValue >= MonaKeyCode.f1.rawValue && code.rawValue <= MonaKeyCode.f24.rawValue {
                return "F\(code.rawValue - MonaKeyCode.f1.rawValue + 1)"
            }
            if code.rawValue >= MonaKeyCode.keyA.rawValue && code.rawValue <= MonaKeyCode.keyZ.rawValue {
                let offset = code.rawValue - MonaKeyCode.keyA.rawValue
                return String(UnicodeScalar(UInt8(65 + offset)))
            }
            if code.rawValue >= MonaKeyCode.digit0.rawValue && code.rawValue <= MonaKeyCode.digit9.rawValue {
                let offset = code.rawValue - MonaKeyCode.digit0.rawValue
                return String(offset)
            }
            return "Key\(code.rawValue)"
        }
    }
}
