// MonaUnusualLineTerminatorsFeature.swift
//
// P05-T158 — Implement retained feature unusualLineTerminators.
//
// `MonaUnusualLineTerminatorsFeature` is the Swift counterpart of Monaco's
// `unusualLineTerminators` contribution (monaco-editor 0.56.0, registered as
// `editor.contrib.unusualLineTerminatorsDetector`): it detects Unicode line
// separators that are not the model's normal line terminator (LINE SEPARATOR
// U+2028, PARAGRAPH SEPARATOR U+2029, NEXT LINE U+0085) and removes them
// transactionally, normalizing each to the model's line feed (LF).
//
// Detection is a pure query over the model text. Removal prepares one edit
// operation per unusual terminator (each replaced with `"\n"`) and commits
// the whole batch as one ordered unit through `MonaTransactionGateway` — the
// model is mutated only through the shared gateway, never directly.
//
// The `unusualLineTerminators` editor option (`"auto"` / `"off"` / `"prompt"`,
// default `"prompt"`) controls the policy: `"off"` suppresses detection;
// `"auto"` removes automatically; `"prompt"` defers to the host. The
// Foundation-only Core exposes the mode as `MonaUnusualLineTerminatorsMode`
// and lets the host decide; removal is always explicit through the gateway.
//
// The feature is a Foundation-only Core surface (`import Foundation` only). It
// performs the three implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `detectUnusualLineTerminators(in:mode:)`
//      and `removeUnusualLineTerminators(in:gateway:)`.
//   2. Register the exact feature identity `unusualLineTerminators` and its
//      declared commands, actions, contributions, options, menus, and
//      keybindings, referenced verbatim from the frozen registries (no rename
//      / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import Foundation

/// The unusual-line-terminators policy — mirrors Monaco's
/// `unusualLineTerminators` editor option (`"auto"` / `"off"` / `"prompt"`).
public enum MonaUnusualLineTerminatorsMode: String, Equatable {

    /// Suppress detection (Monaco's `"off"`).
    case off

    /// Remove automatically (Monaco's `"auto"`).
    case auto

    /// Defer to the host (Monaco's `"prompt"`, the default).
    case prompt
}

/// A detected unusual line terminator: the 1-based range and the code point
/// (U+2028, U+2029, or U+0085).
public struct MonaUnusualLineTerminatorSpan: Equatable {

    /// The 1-based range of the unusual terminator character.
    public let range: MonaRange

    /// The unicode scalar value of the unusual terminator (0x2028 / 0x2029 /
    /// 0x0085).
    public let codePoint: UInt32

    public init(range: MonaRange, codePoint: UInt32) {
        self.range = range
        self.codePoint = codePoint
    }
}

/// An unusual-line-terminators event: the staged detection set (empty when
/// cleared).
public struct MonaUnusualLineTerminatorsEvent: Equatable {

    /// The staged spans, or empty when none are staged.
    public let spans: [MonaUnusualLineTerminatorSpan]

    public init(spans: [MonaUnusualLineTerminatorSpan]) {
        self.spans = spans
    }
}

/// The unusualLineTerminators feature: detect and explicitly remove unusual
/// line terminators transactionally.
///
/// The feature identity `unusualLineTerminators` and its declared slice are
/// referenced verbatim from the frozen registries. Model mutation (the
/// normalization edits) is routed through `MonaTransactionGateway`;
/// asynchronous publication through `MonaProviderExecutor` +
/// `MonaMicrotaskQueue`; disposal through `MonaEmitter`; localization through
/// `MonaLocalization`; and degraded plain-text behavior through
/// `MonaPlainTextLanguage`.
public final class MonaUnusualLineTerminatorsFeature: MonaDisposable {

    /// The frozen feature identity (`"unusualLineTerminators"`).
    public static let featureId = "unusualLineTerminators"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce).
    /// unusualLineTerminators declares no labeled actions.
    public static let declaredActionIds: [String] = []

    /// The declared command IDs in source order. unusualLineTerminators
    /// declares no editor commands.
    public static let declaredCommandIds: [String] = []

    /// The declared contribution ID (`editor.contrib.unusualLineTerminators-
    /// Detector`, ordinal 45).
    public static let declaredContributionIds: [String] = [
        "editor.contrib.unusualLineTerminatorsDetector"
    ]

    /// The declared keybinding commands — unusualLineTerminators carries no
    /// default keybinding in `MonaBuiltinKeybindings`, so this slice is empty.
    public static let declaredKeybindingCommands: [String] = []

    /// The declared option names. The `unusualLineTerminators` editor option
    /// (id 143) owns the policy (`"auto"` / `"off"` / `"prompt"`).
    public static let declaredOptionIds: [String] = [
        "unusualLineTerminators"
    ]

    /// The declared menu IDs — unusualLineTerminators registers no menu items,
    /// so this slice is empty.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    /// The staged detection set (set by `stageDetections(_:)`), or empty.
    private var stagedSpans: [MonaUnusualLineTerminatorSpan] = []

    private let emitter = MonaEmitter<MonaUnusualLineTerminatorsEvent>()

    /// The event stream for unusual-line-terminators changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the
    /// listener.
    public var onChange: MonaEvent<MonaUnusualLineTerminatorsEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the unusualLineTerminators feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    // MARK: - 1. Feature-specific behavior: detect + remove unusual terminators

    /// The frozen set of unusual line terminators Monaco's detector flags:
    /// LINE SEPARATOR (U+2028), PARAGRAPH SEPARATOR (U+2029), and NEXT LINE
    /// (U+0085).
    private static let unusualTerminators: Set<UInt32> = [0x2028, 0x2029, 0x0085]

    /// Detects unusual line terminators (U+2028 / U+2029 / U+0085) in `model`
    /// under `mode`. Each unusual terminator is reported as one span (1-based
    /// range + code point). When `mode` is `.off`, returns an empty array.
    /// Returns an empty array after `dispose()`.
    public func detectUnusualLineTerminators(
        in model: MonaCodeModel,
        mode: MonaUnusualLineTerminatorsMode = .prompt
    ) -> [MonaUnusualLineTerminatorSpan] {
        guard !isDisposed else { return [] }
        guard mode != .off else { return [] }

        var spans: [MonaUnusualLineTerminatorSpan] = []
        var line = 1
        var column = 1 // 1-based UTF-16 code-unit column
        for scalar in model.getValue().unicodeScalars {
            if scalar == "\n" {
                line += 1
                column = 1
                continue
            }
            let value = scalar.value
            let utf16Length = value < 0x10000 ? 1 : 2
            if Self.unusualTerminators.contains(value) {
                spans.append(MonaUnusualLineTerminatorSpan(
                    range: MonaRange(
                        startLine: line,
                        startColumn: column,
                        endLine: line,
                        endColumn: column + utf16Length
                    ),
                    codePoint: value
                ))
            }
            column += utf16Length
        }
        return spans
    }

    /// Removes every unusual line terminator in `model` by replacing it with
    /// `"\n"`, committed as one ordered unit through `gateway`. Returns the
    /// reconciliation outcome. A no-op (`.applied`) when no unusual terminators
    /// are present — the empty transaction still routes through the gateway.
    /// Returns `.dropped` after `dispose()`.
    @discardableResult
    public func removeUnusualLineTerminators(
        in model: MonaCodeModel,
        gateway: MonaTransactionGateway,
        mode: MonaUnusualLineTerminatorsMode = .prompt
    ) -> MonaReconciliationOutcome {
        guard !isDisposed else { return .dropped(reason: "disposed") }
        let spans = detectUnusualLineTerminators(in: model, mode: mode)
        let operations = spans.map { span in
            MonaModelEditOperation(range: span.range, text: "\n")
        }
        let transaction = gateway.beginTransaction()
        if !operations.isEmpty {
            transaction.prepareEdits(operations)
        }
        return gateway.commit(transaction)
    }

    /// Stages `spans` as the current detection set and fires an event. A no-op
    /// after `dispose()`.
    public func stageDetections(_ spans: [MonaUnusualLineTerminatorSpan]) {
        guard !isDisposed else { return }
        _lock.lock()
        stagedSpans = spans
        _lock.unlock()
        fire(.init(spans: spans))
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `spans` through the shared provider executor, normalized onto
    /// the deterministic microtask queue. `receive` runs ONLY when the queue is
    /// drained (FIFO), after the publication ticket is validated. After
    /// `dispose()`, returns `false` and publishes nothing.
    @discardableResult
    public func publishDetections(
        _ spans: [MonaUnusualLineTerminatorSpan],
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping ([MonaUnusualLineTerminatorSpan]) -> Void
    ) -> Bool {
        guard !isDisposed else { return false }
        return executor.publish(
            .synchronous(spans),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, the staged spans are cleared, and
    /// `detectUnusualLineTerminators` / `removeUnusualLineTerminators` are
    /// no-ops.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        stagedSpans = []
        _lock.unlock()
        if !already {
            emitter.dispose()
        }
    }

    // MARK: - 3d. Localization → MonaLocalization

    /// Returns the declared action labels formatted through the shared
    /// `MonaLocalization` surface under `profile`. unusualLineTerminators
    /// declares no labeled actions, so this returns an empty array under every
    /// profile.
    public func localizedActionLabels(profile: MonaCodeEnvironmentProfile) -> [String] {
        let registry = MonaActionRegistry()
        return Self.declaredActionIds.map { id in
            let label = registry.identity(for: id)?.label ?? id
            return MonaLocalization.format(label, args: [], profile: profile)
        }
    }

    // MARK: - 3e. Degraded plain-text → MonaPlainTextLanguage

    /// The plain-text fallback language. unusualLineTerminators needs no
    /// tokenization; it detects at the unicode-scalar level and degrades to
    /// the plain-text fallback for any tokenization-dependent concern.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — unusualLineTerminators performs no tokenization-dependent work
    /// and degrades gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Fires an unusual-line-terminators event when not disposed.
    private func fire(_ event: MonaUnusualLineTerminatorsEvent) {
        guard !isDisposed else { return }
        emitter.fire(event)
    }
}
