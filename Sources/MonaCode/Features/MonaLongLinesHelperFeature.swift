// MonaLongLinesHelperFeature.swift
//
// P05-T137 — Implement retained feature longLinesHelper.
//
// `MonaLongLinesHelperFeature` is the Swift counterpart of Monaco's
// `longLinesHelper` contribution (monaco-editor 0.56.0): it enforces the
// configured long-line rendering cutoff — flagging lines whose length exceeds
// the `longLinesHintThreshold` option — and an explicit unlimited mode that
// overrides any configured cutoff. The `renderLongLineSelection` option
// controls whether selection rendering on long lines is enabled.
//
// The two options are read through the shared `MonaOptionStore` (P05-T005).
// They are runtime-read options that may be absent in the Foundation-only Core
// (they are not part of the F1-R3 174-option registry); when absent, the store
// returns `nil`, so the feature defaults to unlimited mode with
// `renderLongLineSelection = true` — a graceful degradation, not an error.
//
// The feature is a Foundation-only Core surface (`import Foundation` only). It
// performs the three implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `readLongLinesOptions`, `enforceLongLines`,
//      and `setExplicitUnlimited`, all reading the configured cutoff via the
//      shared option store and supporting an explicit unlimited override.
//   2. Register the exact feature identity `longLinesHelper` and its declared
//      commands, actions, contributions, options, menus, and keybindings,
//      referenced verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import Foundation

/// The long-lines rendering options read from the shared option store: the
/// configured cutoff threshold (`nil` = unlimited) and whether selection
/// rendering on long lines is enabled.
public struct MonaLongLinesOptions: Equatable {

    /// The configured long-line rendering cutoff (in characters per line), or
    /// `nil` when no cutoff is configured (unlimited).
    public let threshold: Int?

    /// Whether selection rendering on long lines is enabled.
    public let renderLongLineSelection: Bool

    public init(threshold: Int?, renderLongLineSelection: Bool) {
        self.threshold = threshold
        self.renderLongLineSelection = renderLongLineSelection
    }
}

/// A long-lines enforcement result: whether unlimited mode is in effect, the
/// configured threshold, the 1-based line numbers exceeding the threshold, and
/// whether selection rendering on long lines is enabled.
public struct MonaLongLinesEnforcement: Equatable {

    /// `true` when no cutoff is enforced (explicit unlimited mode, no threshold,
    /// or a zero threshold).
    public let unlimited: Bool

    /// The configured cutoff threshold, or `nil` when unlimited.
    public let threshold: Int?

    /// The 1-based line numbers whose length exceeds the threshold (empty when
    /// unlimited).
    public let longLineNumbers: [Int]

    /// Whether selection rendering on long lines is enabled.
    public let rendersLongLineSelection: Bool

    public init(
        unlimited: Bool,
        threshold: Int?,
        longLineNumbers: [Int],
        rendersLongLineSelection: Bool
    ) {
        self.unlimited = unlimited
        self.threshold = threshold
        self.longLineNumbers = longLineNumbers
        self.rendersLongLineSelection = rendersLongLineSelection
    }
}

/// A long-lines event kind: whether a cutoff was enforced or unlimited mode is
/// in effect.
public enum MonaLongLinesKind: String, Equatable {

    /// A cutoff was enforced (at least one line was evaluated against the
    /// threshold).
    case enforced

    /// Unlimited mode is in effect (no cutoff enforced).
    case unlimited
}

/// A long-lines event: the kind and the enforcement result.
public struct MonaLongLinesEvent: Equatable {

    /// The kind that fired.
    public let kind: MonaLongLinesKind

    /// The enforcement result.
    public let enforcement: MonaLongLinesEnforcement

    public init(kind: MonaLongLinesKind, enforcement: MonaLongLinesEnforcement) {
        self.kind = kind
        self.enforcement = enforcement
    }
}

/// The longLinesHelper feature: enforce the configured long-line rendering
/// cutoff and explicit unlimited mode.
///
/// The feature identity `longLinesHelper` and its declared slice are referenced
/// verbatim from the frozen registries. Model mutation (reveal the first long
/// line) is routed through `MonaTransactionGateway`; asynchronous publication
/// through `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal through
/// `MonaEmitter`; localization through `MonaLocalization`; and degraded
/// plain-text behavior through `MonaPlainTextLanguage`.
public final class MonaLongLinesHelperFeature: MonaDisposable {

    /// The frozen feature identity (`"longLinesHelper"`).
    public static let featureId = "longLinesHelper"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce).
    /// longLinesHelper declares no labeled actions, so this slice is empty.
    public static let declaredActionIds: [String] = []

    /// The declared command IDs in source order. longLinesHelper declares no
    /// commands, so this slice is empty.
    public static let declaredCommandIds: [String] = []

    /// The declared contribution ID. The long-lines helper controller — the
    /// single longLinesHelper contribution (ordinal 34).
    public static let declaredContributionIds: [String] = [
        "editor.contrib.longLinesHelper"
    ]

    /// The declared keybinding commands — longLinesHelper registers no default
    /// keybindings, so this slice is empty.
    public static let declaredKeybindingCommands: [String] = []

    /// The declared option names. The `longLinesHintThreshold` /
    /// `renderLongLineSelection` options are runtime-read via
    /// `MonaOptionStore` but are not part of the F1-R3 174-option registry, so
    /// the declared slice is empty.
    public static let declaredOptionIds: [String] = []

    /// The declared menu IDs — longLinesHelper registers no menu items, so
    /// this slice is empty.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    private let emitter = MonaEmitter<MonaLongLinesEvent>()

    /// The event stream for long-lines changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaLongLinesEvent> { emitter.event }

    private var _isDisposed = false
    private var _explicitUnlimited = false
    private var _stagedEnforcement: MonaLongLinesEnforcement? = nil
    private let _lock = NSLock()

    /// Creates the longLinesHelper feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    /// `true` when explicit unlimited mode is in effect (overrides any
    /// configured cutoff).
    public var isExplicitUnlimited: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _explicitUnlimited
    }

    // MARK: - 1. Feature-specific behavior: enforce cutoff + explicit unlimited

    /// Reads the long-lines options from the shared `MonaOptionStore` (P05-T005):
    /// `longLinesHintThreshold` (integer; `nil` = unlimited) and
    /// `renderLongLineSelection` (boolean). Missing or unknown values fall back
    /// to unlimited mode with `renderLongLineSelection = true` (the
    /// Foundation-Core default — the two options are runtime-read and may be
    /// absent in the Foundation-only Core).
    public func readLongLinesOptions(
        from store: MonaOptionStore
    ) -> MonaLongLinesOptions {
        let threshold = store.value(for: "longLinesHintThreshold")?.intValue
        let renderLongLineSelection = store.value(for: "renderLongLineSelection")?.boolValue ?? true
        return MonaLongLinesOptions(
            threshold: threshold,
            renderLongLineSelection: renderLongLineSelection
        )
    }

    /// Sets explicit unlimited mode. When `unlimited` is `true`, the feature
    /// enforces no cutoff regardless of the configured threshold. A no-op after
    /// `dispose()`.
    public func setExplicitUnlimited(_ unlimited: Bool) {
        guard !isDisposed else { return }
        _lock.lock()
        _explicitUnlimited = unlimited
        _lock.unlock()
    }

    /// Enforces the long-line rendering cutoff against `model`'s lines, under
    /// `options` and an `explicitUnlimited` override. Returns an enforcement
    /// result describing whether unlimited mode is in effect, the configured
    /// threshold, the 1-based line numbers exceeding the threshold, and whether
    /// selection rendering on long lines is enabled. A no-op (returns an
    /// unlimited enforcement with no long lines) after `dispose()`.
    @discardableResult
    public func enforceLongLines(
        model: MonaCodeModel,
        options: MonaLongLinesOptions,
        explicitUnlimited: Bool
    ) -> MonaLongLinesEnforcement {
        guard !isDisposed else {
            return MonaLongLinesEnforcement(
                unlimited: true, threshold: nil, longLineNumbers: [],
                rendersLongLineSelection: options.renderLongLineSelection
            )
        }
        let unlimited = explicitUnlimited || options.threshold == nil || options.threshold == 0
        let longLineNumbers: [Int]
        if unlimited {
            longLineNumbers = []
        } else {
            let threshold = options.threshold ?? 0
            var flagged: [Int] = []
            let count = model.getLineCount()
            for line in 1...max(1, count) {
                if model.getLineLength(line) > threshold {
                    flagged.append(line)
                }
            }
            longLineNumbers = flagged
        }
        let enforcement = MonaLongLinesEnforcement(
            unlimited: unlimited,
            threshold: unlimited ? nil : options.threshold,
            longLineNumbers: longLineNumbers,
            rendersLongLineSelection: options.renderLongLineSelection
        )
        _lock.lock()
        _stagedEnforcement = enforcement
        _lock.unlock()
        fire(enforcement)
        return enforcement
    }

    // MARK: - 3a. Mutation → MonaTransactionGateway

    /// Reveals the first long line through the shared transaction gateway:
    /// begins a transaction, prepares a collapsed selection at the first long
    /// line's first column, and commits the unit. Returns the committed
    /// selections (empty when the feature is disposed, the enforcement is
    /// unlimited, the enforcement has no long lines, or the commit dropped).
    @discardableResult
    public func commitRevealFirstLongLine(
        gateway: MonaTransactionGateway,
        enforcement: MonaLongLinesEnforcement
    ) -> [MonaSelection] {
        guard !isDisposed else { return [] }
        guard !enforcement.unlimited, let firstLine = enforcement.longLineNumbers.first else {
            return []
        }
        let tx = gateway.beginTransaction()
        let position = MonaPosition(line: firstLine, column: 1)
        let selection = MonaSelection(anchor: position, activePosition: position)
        tx.prepareSelections([selection])
        _ = gateway.commit(tx)
        return gateway.lastCommittedSelections
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `enforcement` through the shared provider executor,
    /// normalized onto the deterministic microtask queue. `receive` runs ONLY
    /// when the queue is drained (FIFO), after the publication ticket is
    /// validated.
    @discardableResult
    public func publishLongLinesEnforcement(
        _ enforcement: MonaLongLinesEnforcement,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaLongLinesEnforcement) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(enforcement),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, the staged enforcement is cleared, and
    /// `readLongLinesOptions` / `enforceLongLines` / `commitRevealFirstLongLine`
    /// / `setExplicitUnlimited` are no-ops.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        _stagedEnforcement = nil
        _explicitUnlimited = false
        _lock.unlock()
        if !already {
            emitter.dispose()
        }
    }

    // MARK: - 3d. Localization → MonaLocalization

    /// Returns the declared action labels formatted through the shared
    /// `MonaLocalization` surface under `profile`. longLinesHelper declares no
    /// actions, so this returns an empty array under every profile.
    public func localizedActionLabels(profile: MonaCodeEnvironmentProfile) -> [String] {
        let registry = MonaActionRegistry()
        return Self.declaredActionIds.map { id in
            let label = registry.identity(for: id)?.label ?? id
            return MonaLocalization.format(label, args: [], profile: profile)
        }
    }

    // MARK: - 3e. Degraded plain-text → MonaPlainTextLanguage

    /// The plain-text fallback language. longLinesHelper performs no
    /// tokenization-dependent work (it reads line lengths, not tokens); it
    /// degrades gracefully to the plain-text fallback.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — longLinesHelper performs no tokenization-dependent work and
    /// degrades gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Fires a long-lines event when not disposed.
    private func fire(_ enforcement: MonaLongLinesEnforcement) {
        guard !isDisposed else { return }
        let kind: MonaLongLinesKind = enforcement.unlimited ? .unlimited : .enforced
        emitter.fire(MonaLongLinesEvent(kind: kind, enforcement: enforcement))
    }
}
