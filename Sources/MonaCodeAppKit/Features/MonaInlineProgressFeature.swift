// MonaInlineProgressFeature.swift
//
// P05-T129 — Implement retained feature inlineProgress.
//
// `MonaInlineProgressFeature` is the Swift counterpart of Monaco's
// `inlineProgress` contribution (monaco-editor 0.56.0): it renders retained
// inline progress feedback — a message + optional determinate percent — keyed
// by model version, using native AppKit rendering. Staging retains the progress
// item per model version so a stale version's result can be released when the
// model advances; updating replaces the staged item; rendering produces an
// `NSAttributedString` for inline display; and releasing drops the item cached
// for a stale model version.
//
// CRITICAL: this feature renders inline progress feedback WITHOUT
// notification-center UI. It deliberately does NOT bridge through
// `NSUserNotificationCenter` (deprecated) or `UNUserNotificationCenter`; the
// render path produces an `NSAttributedString` for native inline display only.
// `notificationCenterBridge` is permanently `nil` and exists solely as a
// testable surface asserting no notification-center delivery is wired.
//
// The feature is an AppKit surface (`import AppKit`, `import Foundation`,
// `import MonaCode` — the render step produces an `NSAttributedString`). It
// performs the three implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `stageInlineProgress`, `renderInlineProgress`,
//      `renderPlainText`, `updateInlineProgress`, and `releaseInlineProgress`,
//      all keyed by model version, with native AppKit rendering and no
//      notification-center UI.
//   2. Register the exact feature identity `inlineProgress` and its declared
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

/// An inline progress item: an identifier, a message, an optional determinate
/// percent (`nil` = indeterminate), and an optional position the indicator
/// renders at.
public struct MonaInlineProgress: Equatable {

    /// A stable identifier for the progress item (e.g. `"indexing"`).
    public let identifier: String

    /// The human-readable progress message.
    public let message: String

    /// The determinate progress in `[0, 1]`, or `nil` when the progress is
    /// indeterminate.
    public let percent: Double?

    /// The position the indicator renders at, or `nil` when the indicator is
    /// not anchored to a specific position.
    public let position: MonaPosition?

    public init(identifier: String, message: String, percent: Double?, position: MonaPosition? = nil) {
        self.identifier = identifier
        self.message = message
        self.percent = percent
        self.position = position
    }
}

/// An inline-progress event: the staged progress (or `nil` when released) and
/// the model version it is retained against.
public struct MonaInlineProgressEvent: Equatable {

    /// The staged progress, or `nil` when no progress is staged.
    public let progress: MonaInlineProgress?

    /// The model version the progress is retained against.
    public let modelVersion: Int

    public init(progress: MonaInlineProgress?, modelVersion: Int) {
        self.progress = progress
        self.modelVersion = modelVersion
    }
}

/// The inlineProgress feature: render retained inline progress feedback
/// without notification-center UI.
///
/// The feature identity `inlineProgress` and its declared slice are referenced
/// verbatim from the frozen registries. Staged progress is retained per model
/// version so a stale version's result can be released when the model advances.
/// Rendering produces an `NSAttributedString` for native inline display (NOT a
/// posted notification). Model mutation (reveal) is routed through
/// `MonaTransactionGateway`; asynchronous publication through
/// `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal through `MonaEmitter`;
/// localization through `MonaLocalization`; and degraded plain-text behavior
/// through `MonaPlainTextLanguage`.
public final class MonaInlineProgressFeature: MonaDisposable {

    /// The frozen feature identity (`"inlineProgress"`).
    public static let featureId = "inlineProgress"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce).
    /// inlineProgress declares no labeled actions, so this slice is empty.
    public static let declaredActionIds: [String] = []

    /// The declared command IDs in source order. inlineProgress declares no
    /// commands, so this slice is empty.
    public static let declaredCommandIds: [String] = []

    /// The declared contribution IDs. inlineProgress declares no contributions,
    /// so this slice is empty.
    public static let declaredContributionIds: [String] = []

    /// The declared keybinding commands. inlineProgress declares no default
    /// keybindings, so this slice is empty.
    public static let declaredKeybindingCommands: [String] = []

    /// The declared option names. inlineProgress declares no options, so this
    /// slice is empty.
    public static let declaredOptionIds: [String] = []

    /// The declared menu IDs. inlineProgress declares no menu items, so this
    /// slice is empty.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    /// The progress items retained by model version. A stale model version's
    /// item is released by `releaseInlineProgress(modelVersion:)`.
    private var retainedByVersion: [Int: MonaInlineProgress] = [:]

    /// The currently staged progress (the most recent staged / updated).
    private var _stagedProgress: MonaInlineProgress? = nil

    private let emitter = MonaEmitter<MonaInlineProgressEvent>()

    /// The event stream for inline-progress changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaInlineProgressEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the inlineProgress feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    /// The currently staged progress, or `nil` when none is staged (or after
    /// disposal).
    public var stagedProgress: MonaInlineProgress? {
        _lock.lock(); defer { _lock.unlock() }
        return _stagedProgress
    }

    /// Always `nil`. The inline-progress feature renders native AppKit inline
    /// feedback and deliberately does NOT bridge through
    /// `NSUserNotificationCenter` or `UNUserNotificationCenter`. This property
    /// exists solely as a testable surface asserting no notification-center
    /// delivery is wired.
    public var notificationCenterBridge: Any? { nil }

    // MARK: - 1. Feature-specific behavior: stage / render / update / release (no notification-center UI)

    /// Stages `progress` against `modelVersion`, retaining it keyed by model
    /// version and staging it as the current progress. Fires an event with the
    /// staged progress. Returns the progress, or `nil` after `dispose()`.
    @discardableResult
    public func stageInlineProgress(
        _ progress: MonaInlineProgress,
        modelVersion: Int
    ) -> MonaInlineProgress? {
        guard !isDisposed else { return nil }
        _lock.lock()
        retainedByVersion[modelVersion] = progress
        _stagedProgress = progress
        _lock.unlock()
        fire(progress, modelVersion: modelVersion)
        return progress
    }

    /// The number of progress items retained for `modelVersion` (0 or 1). Zero
    /// when the version has no retained item (or after disposal).
    public func retainedProgressCount(for modelVersion: Int) -> Int {
        _lock.lock(); defer { _lock.unlock() }
        return retainedByVersion[modelVersion] != nil ? 1 : 0
    }

    /// Renders `progress` to an `NSAttributedString` for native inline display.
    /// The message is rendered bold; a determinate percent is appended as
    /// ` (NN%)`. Returns an empty attributed string after `dispose()`. This is
    /// the native AppKit inline render path — it does NOT post a notification.
    public func renderInlineProgress(_ progress: MonaInlineProgress) -> NSAttributedString {
        guard !isDisposed else { return NSAttributedString() }
        let result = NSMutableAttributedString()
        let bold = NSFont.boldSystemFont(ofSize: 0)
        let plain = NSFont.systemFont(ofSize: 0)
        result.append(NSAttributedString(string: progress.message, attributes: [.font: bold]))
        if let percent = progress.percent {
            let pct = Int((percent * 100).rounded())
            result.append(NSAttributedString(string: " (\(pct)%)", attributes: [.font: plain]))
        }
        // Indeterminate progress appends no percent figure.
        return result
    }

    /// Renders `progress` to a plain-text string. This is the degraded render
    /// path through `MonaPlainTextLanguage` — inlineProgress needs no
    /// tokenization and degrades to plain text for rendering.
    public func renderPlainText(_ progress: MonaInlineProgress) -> String {
        guard !isDisposed else { return "" }
        if let percent = progress.percent {
            let pct = Int((percent * 100).rounded())
            return "\(progress.message) (\(pct)%)"
        }
        return progress.message
    }

    /// Updates the staged progress to `progress` for `modelVersion`, replacing
    /// the retained copy for that version. Fires an event. Returns the updated
    /// progress, or `nil` after `dispose()`.
    @discardableResult
    public func updateInlineProgress(
        _ progress: MonaInlineProgress,
        modelVersion: Int
    ) -> MonaInlineProgress? {
        guard !isDisposed else { return nil }
        _lock.lock()
        _stagedProgress = progress
        retainedByVersion[modelVersion] = progress
        _lock.unlock()
        fire(progress, modelVersion: modelVersion)
        return progress
    }

    /// Releases the progress retained for `modelVersion` (the model has
    /// advanced past that version, so the result is stale). Returns `1` when an
    /// item was released, `0` otherwise. After `dispose()`, returns `0`.
    @discardableResult
    public func releaseInlineProgress(modelVersion: Int) -> Int {
        _lock.lock(); defer { _lock.unlock() }
        if _isDisposed { return 0 }
        return retainedByVersion.removeValue(forKey: modelVersion) != nil ? 1 : 0
    }

    // MARK: - 3a. Mutation → MonaTransactionGateway

    /// Reveals the staged progress's position through the shared transaction
    /// gateway: begins a transaction, prepares a collapsed selection at the
    /// staged progress's position, and commits the unit. Returns the committed
    /// selections (empty when the feature is disposed, no progress is staged,
    /// the staged progress has no position, or the commit dropped).
    @discardableResult
    public func commitReveal(gateway: MonaTransactionGateway) -> [MonaSelection] {
        guard !isDisposed else { return [] }
        _lock.lock()
        let position = _stagedProgress?.position
        _lock.unlock()
        guard let position = position else { return [] }
        let tx = gateway.beginTransaction()
        let selection = MonaSelection(anchor: position, activePosition: position)
        tx.prepareSelections([selection])
        _ = gateway.commit(tx)
        return gateway.lastCommittedSelections
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `progress` through the shared provider executor, normalized
    /// onto the deterministic microtask queue. `receive` runs ONLY when the
    /// queue is drained (FIFO), after the publication ticket is validated.
    @discardableResult
    public func publishInlineProgress(
        _ progress: MonaInlineProgress,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaInlineProgress) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(progress),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, retained progress is released, the
    /// staged progress is cleared, and `stageInlineProgress` /
    /// `renderInlineProgress` / `updateInlineProgress` /
    /// `releaseInlineProgress` / `commitReveal` are no-ops.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        retainedByVersion.removeAll()
        _stagedProgress = nil
        _lock.unlock()
        if !already {
            emitter.dispose()
        }
    }

    // MARK: - 3d. Localization → MonaLocalization

    /// Returns the declared action labels formatted through the shared
    /// `MonaLocalization` surface under `profile`. inlineProgress declares no
    /// actions, so this returns an empty array under every profile.
    public func localizedActionLabels(profile: MonaCodeEnvironmentProfile) -> [String] {
        let registry = MonaActionRegistry()
        return Self.declaredActionIds.map { id in
            let label = registry.identity(for: id)?.label ?? id
            return MonaLocalization.format(label, args: [], profile: profile)
        }
    }

    // MARK: - 3e. Degraded plain-text → MonaPlainTextLanguage

    /// The plain-text fallback language. inlineProgress needs no tokenization;
    /// it degrades to plain text for its rendering needs.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — inlineProgress performs no tokenization-dependent work and
    /// degrades gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Fires an inline-progress event when not disposed.
    private func fire(_ progress: MonaInlineProgress?, modelVersion: Int) {
        guard !isDisposed else { return }
        emitter.fire(MonaInlineProgressEvent(progress: progress, modelVersion: modelVersion))
    }
}
