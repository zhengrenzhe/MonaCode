// MonaTokenizationFeature.swift
//
// P05-T156 — Implement retained feature tokenization.
//
// `MonaTokenizationFeature` is the Swift counterpart of Monaco's core
// tokenization surface (monaco-editor 0.56.0): the feature that, for each
// line, asks the attached direct token provider for its tokens, and retains
// plain-text tokens when no provider is attached.
//
// The direct-token-provider pattern reuses the T009 colorize attachment
// model (`MonaDirectTokenProvider`, defined in `MonaCodeAppKit/Colorize`):
// a provider is attached to the feature, and the feature consumes its tokens.
// Because this feature lives in the Foundation-only Core target, it cannot
// import the AppKit `MonaDirectTokenProvider` (which returns AppKit
// `MonaColorToken`s over raw `[UInt16]`). Instead it defines a
// Foundation-only `MonaTokenizationProvider` that mirrors the T009 pattern but
// returns Core `MonaToken`s (P01-T004, the port of `monaco.Token`) over a line
// `String` — the same value type Monaco's tokenizer produces. When no provider
// is attached, the feature retains the plain-text token: one `MonaToken` per
// line (offset 0, type `""`, language `"plaintext"`) via `MonaPlainTextLanguage`
// (P05-T008).
//
// The feature is a Foundation-only Core surface (`import Foundation` only). It
// performs the three implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `tokenize(line:languageId:)`,
//      `tokenize(text:languageId:)`, `directTokenProvider`, consuming the
//      attached provider and retaining the plain-text token when none is
//      attached.
//   2. Register the exact feature identity `tokenization` and its declared
//      commands, actions, contributions, options, menus, and keybindings,
//      referenced verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation (read-only — none performed), asynchronous
//      publication, disposal, localization, and degraded plain-text behavior
//      through the shared gateways — reusing `MonaTransactionGateway` (mutation,
//      vacuous), `MonaProviderExecutor` + `MonaMicrotaskQueue` (async
//      publication), `MonaEmitter` (disposal), `MonaLocalization` (localization),
//      and `MonaPlainTextLanguage` (degraded plain text). No parallel mechanisms
//      are introduced.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

// MARK: - MonaTokenizationProvider

/// A direct tokenization provider for the Foundation-only Core — the
/// counterpart of the T009 AppKit `MonaDirectTokenProvider` pattern.
///
/// Given a line's text and language id, returns the tokens covering it in
/// offset order. Attached to a `MonaTokenizationFeature` via
/// `directTokenProvider`; when `nil`, the feature retains the plain-text
/// token. This is the Phase 06 attachment point for real language tokenizers;
/// until then only the plain-text fallback path is exercised.
public protocol MonaTokenizationProvider: AnyObject {

    /// Returns the tokens covering `line`, in offset order.
    ///
    /// - Parameters:
    ///   - line: The line text (no trailing newline).
    ///   - languageId: The language id of the model (e.g. `"typescript"`).
    /// - Returns: The tokens covering `line`. Returning an empty array causes
    ///   the feature to fall back to the plain-text token.
    func tokens(forLine line: String, languageId: String) -> [MonaToken]
}

// MARK: - MonaTokenizationEvent

/// A tokenization event: a tokenized result that was staged.
public struct MonaTokenizationEvent: Equatable {

    /// The staged tokens (one line's worth), or `nil` when none is staged.
    public let tokens: [MonaToken]?

    public init(tokens: [MonaToken]?) {
        self.tokens = tokens
    }
}

// MARK: - MonaTokenizationFeature

/// The tokenization feature: consume direct token providers and retain
/// plain-text tokens when none is attached.
///
/// The feature identity `tokenization` and its declared slice are referenced
/// verbatim from the frozen registries. `tokenize(line:languageId:)` consumes
/// the attached `MonaTokenizationProvider` when present (returning its tokens);
/// when none is attached (or it returns an empty array), it retains the
/// plain-text token — one `MonaToken` per line (offset 0, type `""`, language
/// `"plaintext"`) via `MonaPlainTextLanguage` (P05-T008). The feature performs
/// no model mutation: mutation routing is vacuous. Asynchronous publication is
/// routed through `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal
/// through `MonaEmitter`; localization through `MonaLocalization`; and
/// degraded plain-text behavior through `MonaPlainTextLanguage`.
public final class MonaTokenizationFeature: MonaDisposable {

    /// The frozen feature identity (`"tokenization"`).
    public static let featureId = "tokenization"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs — tokenization declares no labeled editor
    /// actions.
    public static let declaredActionIds: [String] = []

    /// The declared command IDs — tokenization declares no editor commands.
    public static let declaredCommandIds: [String] = []

    /// The declared contribution IDs — tokenization declares no contributions.
    public static let declaredContributionIds: [String] = []

    /// The declared keybinding commands — tokenization declares no keybindings.
    public static let declaredKeybindingCommands: [String] = []

    /// The declared option names — tokenization declares no options.
    public static let declaredOptionIds: [String] = []

    /// The declared menu IDs — tokenization registers no menu items.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    /// The optional direct token provider (Phase 06 attachment point). When
    /// `nil`, `tokenize(...)` retains the plain-text token.
    public var directTokenProvider: MonaTokenizationProvider?

    private let emitter = MonaEmitter<MonaTokenizationEvent>()

    /// The event stream for tokenization changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaTokenizationEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the tokenization feature with no provider attached (the
    /// plain-text fallback path).
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    // MARK: - 1. Feature-specific behavior: consume providers / retain plain-text

    /// The plain-text fallback token: one `MonaToken` per line (offset 0, type
    /// `""`, language `"plaintext"`), reusing `MonaPlainTextLanguage`
    /// (P05-T008) for the language id.
    public static func plainTextToken() -> MonaToken {
        return MonaToken(
            offset: 0,
            type: "",
            language: MonaPlainTextLanguage.languageId
        )
    }

    /// Tokenizes `line` under `languageId`. When a `directTokenProvider` is
    /// attached and returns a non-empty array, returns its tokens. When none
    /// is attached (or it returns an empty array), retains the plain-text
    /// token. Returns an empty array after `dispose()`.
    public func tokenize(
        line: String,
        languageId: String = MonaPlainTextLanguage.languageId
    ) -> [MonaToken] {
        guard !isDisposed else { return [] }
        if let provider = directTokenProvider {
            let provided = provider.tokens(forLine: line, languageId: languageId)
            if !provided.isEmpty {
                return provided
            }
        }
        return [Self.plainTextToken()]
    }

    /// Tokenizes `text` line-by-line, returning one token array per line
    /// (lines split on `\n`). Returns an empty array after `dispose()`.
    public func tokenize(
        text: String,
        languageId: String = MonaPlainTextLanguage.languageId
    ) -> [[MonaToken]] {
        guard !isDisposed else { return [] }
        return text
            .components(separatedBy: "\n")
            .map { tokenize(line: $0, languageId: languageId) }
    }

    /// Stages `tokens` as the current tokenization result and fires an event.
    /// A no-op after `dispose()`.
    public func stageTokens(_ tokens: [MonaToken]) {
        guard !isDisposed else { return }
        emitter.fire(MonaTokenizationEvent(tokens: tokens))
    }

    // MARK: - 3a. Mutation → MonaTransactionGateway (read-only: none performed)

    /// tokenization performs no model mutation: it reads line text and
    /// produces tokens without touching the model. Mutation routing is
    /// therefore vacuous — this no-op commits an empty transaction through the
    /// shared gateway so callers that route every feature action through it can
    /// confirm the model is unchanged. A no-op after `dispose()`.
    @discardableResult
    public func confirmReadOnly(gateway: MonaTransactionGateway) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let transaction = gateway.beginTransaction()
        return gateway.commit(transaction)
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `tokens` through the shared provider executor, normalized onto
    /// the deterministic microtask queue. `receive` runs ONLY when the queue is
    /// drained (FIFO), after the publication ticket is validated. After
    /// `dispose()`, returns `false` and publishes nothing.
    @discardableResult
    public func publishTokenization(
        _ tokens: [MonaToken],
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping ([MonaToken]) -> Void
    ) -> Bool {
        guard !isDisposed else { return false }
        return executor.publish(
            .synchronous(tokens),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, the provider attachment is released,
    /// and `tokenize(...)` / `confirmReadOnly` / `publishTokenization` are
    /// no-ops.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        directTokenProvider = nil
        _lock.unlock()
        if !already {
            emitter.dispose()
        }
    }

    // MARK: - 3d. Localization → MonaLocalization

    /// Returns the declared action labels formatted through the shared
    /// `MonaLocalization` surface under `profile`. tokenization declares no
    /// actions, so this returns an empty array under every profile.
    public func localizedActionLabels(profile: MonaCodeEnvironmentProfile) -> [String] {
        let registry = MonaActionRegistry()
        return Self.declaredActionIds.map { id in
            let label = registry.identity(for: id)?.label ?? id
            return MonaLocalization.format(label, args: [], profile: profile)
        }
    }

    // MARK: - 3e. Degraded plain-text → MonaPlainTextLanguage

    /// The plain-text fallback language. tokenization retains plain-text
    /// tokens (one per line, language `"plaintext"`) when no provider is
    /// attached, reusing `MonaPlainTextLanguage` (P05-T008) for the language id.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — tokenization degrades to the plain-text fallback when no
    /// direct token provider is attached (the Foundation-only Core carries no
    /// language tokenizers until Phase 06).
    public var isPlainTextDegraded: Bool { true }
}
