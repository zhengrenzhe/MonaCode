// MonaInspectTokensFeature.swift
//
// P05-T132 — Implement retained feature inspectTokens.
//
// `MonaInspectTokensFeature` is the Swift counterpart of Monaco's
// `inspectTokens` developer action (monaco-editor 0.56.0): it exposes the
// token, scope, foreground, background, font style, and source inspection data
// for the token at a position. The scope→color mapping reuses the token theme
// (P05-T006 `MonaTokenTheme`); the token text and offset are produced under the
// degraded plain-text fallback (P05-T008 `MonaPlainTextLanguage`), since no
// language provider / tokenizer is registered in Foundation-only Core.
//
// The feature is read-only: it inspects the model without mutating it. Model
// mutation is therefore vacuously routed through `MonaTransactionGateway` (no
// mutation occurs and no parallel mutation mechanism is introduced).
//
// The feature is a Foundation-only Core surface (`import Foundation` only). It
// performs the three implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `inspect(at:model:theme:)`: produce the
//      token inspection at a position, reusing `MonaTokenTheme.rule(for:)` for
//      the scope→color lookup and the plain-text fallback for tokenization.
//   2. Register the exact feature identity `inspectTokens` and its declared
//      commands, actions, contributions, options, menus, and keybindings,
//      referenced verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation (read-only — none), asynchronous publication,
//      disposal, localization, and degraded plain-text behavior through the
//      shared gateways — reusing `MonaTransactionGateway` (mutation, vacuous),
//      `MonaProviderExecutor` + `MonaMicrotaskQueue` (async publication),
//      `MonaEmitter` (disposal), `MonaLocalization` (localization), and
//      `MonaPlainTextLanguage` (degraded plain text). No parallel mechanisms
//      are introduced.

import Foundation

/// The source-location metadata for a token inspection: the language id, the
/// 1-based line and column of the token start, and the 0-based UTF-16 offset of
/// the token start within its line.
public struct MonaTokenInspectionSource: Equatable {

    /// The language id of the inspected token (the plain-text fallback
    /// `"plaintext"` under degraded tokenization).
    public let languageId: String

    /// The 1-based line number of the token start.
    public let line: Int

    /// The 1-based column of the token start.
    public let column: Int

    /// The 0-based UTF-16 offset of the token start within its line.
    public let offset: Int

    public init(languageId: String, line: Int, column: Int, offset: Int) {
        self.languageId = languageId
        self.line = line
        self.column = column
        self.offset = offset
    }
}

/// A token inspection: the token text, its scope, the foreground / background /
/// font style resolved from the token theme for that scope, and the source
/// location. Produced by `MonaInspectTokensFeature.inspect`.
public struct MonaTokenInspection: Equatable {

    /// The token text (the word at the inspected position under the degraded
    /// plain-text fallback).
    public let token: String

    /// The token scope / type string used for the theme rule lookup. Under the
    /// plain-text fallback this is `""` (the default scope), since no tokenizer
    /// assigns typed scopes.
    public let scope: String

    /// The foreground hex (without `#`) resolved from the token theme rule for
    /// `scope`, or `nil` when the theme carries no rule for the scope.
    public let foreground: String?

    /// The background hex (without `#`) resolved from the token theme rule for
    /// `scope`, or `nil` when the theme carries no rule for the scope.
    public let background: String?

    /// The font style resolved from the token theme rule for `scope`, or `nil`.
    public let fontStyle: String?

    /// The source-location metadata for the inspected token.
    public let source: MonaTokenInspectionSource

    public init(
        token: String,
        scope: String,
        foreground: String?,
        background: String?,
        fontStyle: String?,
        source: MonaTokenInspectionSource
    ) {
        self.token = token
        self.scope = scope
        self.foreground = foreground
        self.background = background
        self.fontStyle = fontStyle
        self.source = source
    }
}

/// An inspect-tokens event: the staged inspection result. Fired on
/// `stageInspection(_:)`.
public struct MonaInspectTokensEvent: Equatable {

    /// The staged inspection result, or `nil` when none is staged.
    public let inspection: MonaTokenInspection?

    /// Creates an inspect-tokens event.
    public init(inspection: MonaTokenInspection?) {
        self.inspection = inspection
    }
}

/// The inspect-tokens feature: expose token, scope, foreground, background, and
/// source inspection data.
///
/// The feature identity `inspectTokens` and its declared slice are referenced
/// verbatim from the frozen registries. `inspect(at:model:theme:)` finds the
/// word at a position, resolves its scope (`""` under the plain-text fallback)
/// to a token-theme rule (`MonaTokenTheme.rule(for:)`, P05-T006), and returns
/// the token text + colors + source. The feature is read-only: it performs no
/// model mutation. Asynchronous publication is routed through
/// `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal through `MonaEmitter`;
/// localization through `MonaLocalization`; and degraded plain-text behavior
/// through `MonaPlainTextLanguage`.
public final class MonaInspectTokensFeature: MonaDisposable {

    /// The frozen feature identity (`"inspectTokens"`).
    public static let featureId = "inspectTokens"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce). The
    /// single inspect-tokens developer action (ordinal 161).
    public static let declaredActionIds: [String] = [
        "editor.action.inspectTokens"
    ]

    /// The declared command IDs in source order. The inspect-tokens action is
    /// also registered as an editor command, so this slice equals
    /// `declaredActionIds`.
    public static let declaredCommandIds: [String] = declaredActionIds

    /// The declared contribution ID. The inspect-tokens controller — the single
    /// inspect-tokens contribution (ordinal 50).
    public static let declaredContributionIds: [String] = [
        "editor.contrib.inspectTokens"
    ]

    /// The declared keybinding commands — inspectTokens carries no default
    /// keybinding in `MonaBuiltinKeybindings`, so this slice is empty.
    public static let declaredKeybindingCommands: [String] = []

    /// The declared option names — inspectTokens declares no options in the
    /// F1-R3 scope manifest, so this slice is empty.
    public static let declaredOptionIds: [String] = []

    /// The declared menu IDs — inspectTokens registers no menu items, so this
    /// slice is empty.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    /// The staged inspection result (set by `stageInspection(_:)`), or `nil`.
    private var stagedInspection: MonaTokenInspection? = nil

    private let emitter = MonaEmitter<MonaInspectTokensEvent>()

    /// The event stream for inspect-tokens changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaInspectTokensEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the inspect-tokens feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    // MARK: - 1. Feature-specific behavior: expose token + scope + colors + source

    /// The plain-text fallback scope (`""`) used when no tokenizer assigns typed
    /// scopes. All builtin token themes carry a `""` default rule.
    private static let plainTextScope = ""

    /// Resolves the token-theme rule for `scope` from `theme` (reusing
    /// `MonaTokenTheme.rule(for:)`, P05-T006). Returns `nil` when the theme
    /// carries no rule for the scope.
    public func themeRule(
        for scope: String,
        theme: MonaTokenTheme
    ) -> MonaTokenColorRule? {
        return theme.rule(for: scope)
    }

    /// Returns the active word at `position` in `model`: the maximal run of
    /// alphanumeric / underscore characters containing the column, with its
    /// 1-based start column and text. Returns `nil` when the column is on
    /// whitespace or past the end of the line.
    private func activeWord(
        at position: MonaPosition,
        model: MonaCodeModel
    ) -> (startColumn: Int, text: String)? {
        let lineNumber = position.line
        guard lineNumber >= 1, lineNumber <= model.getLineCount() else { return nil }
        let content = model.getLineContent(lineNumber)
        let column = position.column
        guard column >= 1 else { return nil }
        let index = column - 1 // 0-based character index
        let chars = Array(content)
        guard index < chars.count else { return nil }
        guard Self.isWordCharacter(chars[index]) else { return nil }

        var start = index
        while start > 0, Self.isWordCharacter(chars[start - 1]) {
            start -= 1
        }
        var end = index
        while end + 1 < chars.count, Self.isWordCharacter(chars[end + 1]) {
            end += 1
        }
        let word = String(chars[start...end])
        return (start + 1, word)
    }

    /// Produces the token inspection at `position` in `model` under `theme`.
    /// The token text is the active word at the position (degraded plain-text
    /// tokenization); the scope is `""` (the plain-text fallback scope); the
    /// foreground / background / font style are resolved from `theme`'s rule for
    /// that scope (P05-T006); and the source carries the plain-text language
    /// id, the 1-based line and column, and the 0-based UTF-16 offset of the
    /// token start within the line.
    ///
    /// Returns `nil` when no active word exists at the position, or after
    /// `dispose()`. The inspection performs no model mutation.
    public func inspect(
        at position: MonaPosition,
        model: MonaCodeModel,
        theme: MonaTokenTheme
    ) -> MonaTokenInspection? {
        guard !isDisposed else { return nil }
        guard let active = activeWord(at: position, model: model) else { return nil }

        let scope = Self.plainTextScope
        let rule = themeRule(for: scope, theme: theme)
        let startColumn = active.startColumn
        let offset = startColumn - 1
        return MonaTokenInspection(
            token: active.text,
            scope: scope,
            foreground: rule?.foreground,
            background: rule?.background,
            fontStyle: rule?.fontStyle,
            source: MonaTokenInspectionSource(
                languageId: MonaPlainTextLanguage.languageId,
                line: position.line,
                column: startColumn,
                offset: offset
            )
        )
    }

    /// Stages `inspection` as the current inspection result and fires an event.
    /// A no-op after `dispose()`.
    public func stageInspection(_ inspection: MonaTokenInspection) {
        guard !isDisposed else { return }
        _lock.lock()
        stagedInspection = inspection
        _lock.unlock()
        fire(.init(inspection: inspection))
    }

    // MARK: - 3a. Mutation → MonaTransactionGateway (read-only: none performed)

    /// inspectTokens is a read-only inspection: it performs no model mutation.
    /// Mutation routing is therefore vacuous — the feature introduces no
    /// parallel mutation mechanism, and `inspect(at:model:theme:)` leaves the
    /// model untouched. This no-op is exposed so callers that route every
    /// feature action through the gateway can confirm the model is unchanged.
    @discardableResult
    public func confirmReadOnly(gateway: MonaTransactionGateway) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        // Commit an empty transaction: no edits, no selections, no EOL. The
        // model is untouched; the outcome records that the (non-)mutation was
        // routed through the shared gateway rather than bypassing it.
        let transaction = gateway.beginTransaction()
        return gateway.commit(transaction)
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `inspection` through the shared provider executor, normalized
    /// onto the deterministic microtask queue. `receive` runs ONLY when the
    /// queue is drained (FIFO), after the publication ticket is validated.
    @discardableResult
    public func publishInspection(
        _ inspection: MonaTokenInspection,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaTokenInspection) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(inspection),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, the staged inspection is cleared, and
    /// `inspect` returns `nil`.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        stagedInspection = nil
        _lock.unlock()
        if !already {
            emitter.dispose()
        }
    }

    // MARK: - 3d. Localization → MonaLocalization

    /// Returns the declared action labels formatted through the shared
    /// `MonaLocalization` surface under `profile`.
    public func localizedActionLabels(profile: MonaCodeEnvironmentProfile) -> [String] {
        let registry = MonaActionRegistry()
        return Self.declaredActionIds.map { id in
            let label = registry.identity(for: id)?.label ?? id
            return MonaLocalization.format(label, args: [], profile: profile)
        }
    }

    // MARK: - 3e. Degraded plain-text → MonaPlainTextLanguage

    /// The plain-text fallback language. inspectTokens degrades to plain-text
    /// tokenization when no language provider / tokenizer is registered (the
    /// Foundation-only Core carries none); the token theme (P05-T006) still
    /// resolves the scope→color mapping for the default scope.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — inspectTokens performs tokenization under the degraded
    /// plain-text fallback (no language provider is registered in
    /// Foundation-only Core); it degrades gracefully to plain text.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Fires an inspect-tokens event when not disposed.
    private func fire(_ event: MonaInspectTokensEvent) {
        guard !isDisposed else { return }
        emitter.fire(event)
    }

    /// `true` when `character` participates in a token word (alphanumeric or
    /// underscore).
    private static func isWordCharacter(_ character: Character) -> Bool {
        return character.isLetter || character.isNumber || character == "_"
    }
}
