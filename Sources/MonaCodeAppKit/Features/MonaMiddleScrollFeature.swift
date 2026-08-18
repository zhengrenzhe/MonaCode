// MonaMiddleScrollFeature.swift
//
// P05-T138 — Implement retained feature middleScroll.
//
// `MonaMiddleScrollFeature` is the Swift counterpart of Monaco's
// `middleScroll` contribution (monaco-editor 0.56.0): it implements native
// middle-button scrolling — a press-drag-and-release gesture where the pointer
// offset from a drag anchor drives a bounded scroll velocity on the shared
// `MonaScrollModel` (P03-T005), and the gesture may be cancelled through a
// `MonaCancellationToken` (the cancellation gate).
//
// The velocity is bounded: the pointer offset from the anchor is scaled by a
// sensitivity factor and clamped to `[-maxVelocity, +maxVelocity]`, so a far
// pointer offset never produces unbounded acceleration. Beginning a drag
// records the anchor; updating requests a scroll of `velocity` on the scroll
// model and converges (the scroll model clamps to `[0, maxScroll]`); ending or
// cancelling stops the drag. Cancellation observes a cancellation token: an
// already-cancelled token immediately stops the drag and fires a cancelled
// event.
//
// The feature is an AppKit surface (`import AppKit`, `import Foundation`,
// `import MonaCode` — the drag anchor is an `NSPoint`). It performs the three
// implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `beginMiddleButtonScroll`,
//      `updateMiddleButtonScroll`, `currentVelocity`, `endMiddleButtonScroll`,
//      and `cancelMiddleButtonScroll`, with bounded velocity and cancellation.
//   2. Register the exact feature identity `middleScroll` and its declared
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

/// A middle-scroll event: the bounded velocity, the requested scroll offset,
/// whether the gesture was cancelled, and whether a drag is still active.
public struct MonaMiddleScrollEvent: Equatable {

    /// The bounded vertical velocity applied this update (in scroll-offset
    /// units), clamped to `[-maxVelocity, +maxVelocity]`.
    public let velocityY: Double

    /// The requested horizontal scroll offset.
    public let requestedScrollX: Double

    /// The requested vertical scroll offset.
    public let requestedScrollY: Double

    /// `true` when the gesture was cancelled (the cancellation gate fired).
    public let cancelled: Bool

    /// `true` when a middle-button drag is still active after this event.
    public let active: Bool

    public init(
        velocityY: Double,
        requestedScrollX: Double,
        requestedScrollY: Double,
        cancelled: Bool,
        active: Bool
    ) {
        self.velocityY = velocityY
        self.requestedScrollX = requestedScrollX
        self.requestedScrollY = requestedScrollY
        self.cancelled = cancelled
        self.active = active
    }
}

/// The middleScroll feature: native middle-button scrolling with bounded
/// velocity and cancellation.
///
/// The feature identity `middleScroll` and its declared slice are referenced
/// verbatim from the frozen registries. Model mutation (reveal) is routed
/// through `MonaTransactionGateway`; asynchronous publication through
/// `MonaProviderExecutor` + `MonaMicrotaskQueue`; disposal through `MonaEmitter`;
/// localization through `MonaLocalization`; and degraded plain-text behavior
/// through `MonaPlainTextLanguage`. The scroll itself is driven on the shared
/// `MonaScrollModel` (P03-T005).
public final class MonaMiddleScrollFeature: MonaDisposable {

    /// The frozen feature identity (`"middleScroll"`).
    public static let featureId = "middleScroll"

    /// The maximum scroll velocity per update (the bound). A pointer offset
    /// beyond this is clamped, so the gesture never accelerates unbounded.
    public static let maxVelocity: Double = 100.0

    /// The sensitivity factor applied to the pointer offset to derive the
    /// velocity.
    public static let sensitivity: Double = 1.0

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce).
    /// middleScroll declares no labeled actions, so this slice is empty.
    public static let declaredActionIds: [String] = []

    /// The declared command IDs in source order. middleScroll declares no
    /// commands, so this slice is empty.
    public static let declaredCommandIds: [String] = []

    /// The declared contribution ID. The middle-scroll controller — the single
    /// middleScroll contribution (ordinal 35).
    public static let declaredContributionIds: [String] = [
        "editor.contrib.middleScroll"
    ]

    /// The declared keybinding commands — middleScroll registers no default
    /// keybindings, so this slice is empty.
    public static let declaredKeybindingCommands: [String] = []

    /// The declared option names — middleScroll declares no options, so this
    /// slice is empty.
    public static let declaredOptionIds: [String] = []

    /// The declared menu IDs — middleScroll registers no menu items, so this
    /// slice is empty.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    private let emitter = MonaEmitter<MonaMiddleScrollEvent>()

    /// The event stream for middle-scroll changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaMiddleScrollEvent> { emitter.event }

    private var _isDisposed = false
    private var _anchor: NSPoint? = nil
    private let _lock = NSLock()

    /// Creates the middleScroll feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    /// `true` when a middle-button drag is currently active.
    public var isDragging: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _anchor != nil
    }

    // MARK: - 1. Feature-specific behavior: bounded velocity + cancellation

    /// Begins a middle-button scroll drag at `point`, recording it as the
    /// drag anchor. Returns `true` when the drag began; `false` when a drag is
    /// already active (idempotent — the anchor is NOT overwritten), or after
    /// `dispose()`.
    @discardableResult
    public func beginMiddleButtonScroll(
        at point: NSPoint,
        in scrollModel: MonaScrollModel
    ) -> Bool {
        guard !isDisposed else { return false }
        _lock.lock()
        if _anchor != nil {
            _lock.unlock()
            return false
        }
        _anchor = point
        _lock.unlock()
        return true
    }

    /// Returns the bounded velocity for a pointer at `point`, derived from the
    /// pointer's vertical offset from the drag anchor (`anchor.y - point.y`)
    /// scaled by `sensitivity` and clamped to `[-maxVelocity, +maxVelocity]`.
    /// Returns `0` when no drag is active or after `dispose()`.
    public func currentVelocity(to point: NSPoint) -> Double {
        guard !isDisposed else { return 0 }
        _lock.lock()
        let anchor = _anchor
        _lock.unlock()
        guard let anchor = anchor else { return 0 }
        let delta = anchor.y - point.y
        let velocity = delta * MonaMiddleScrollFeature.sensitivity
        let maxV = MonaMiddleScrollFeature.maxVelocity
        return Swift.max(-maxV, Swift.min(velocity, maxV))
    }

    /// Updates the middle-button drag to `point`, requesting a bounded scroll
    /// of `currentVelocity(to: point)` on `scrollModel` and converging. Returns
    /// the emitted scroll-change event, or `nil` when no drag is active, after
    /// `dispose()`, or when the velocity is zero (no scroll requested).
    @discardableResult
    public func updateMiddleButtonScroll(
        to point: NSPoint,
        in scrollModel: MonaScrollModel
    ) -> MonaScrollChangeEvent? {
        guard !isDisposed else { return nil }
        _lock.lock()
        let anchor = _anchor
        _lock.unlock()
        guard anchor != nil else { return nil }
        let velocity = currentVelocity(to: point)
        // Request a scroll of `velocity` from the current published position.
        let targetX = scrollModel.publishedScrollX
        let targetY = scrollModel.publishedScrollY + velocity
        scrollModel.requestScroll(x: targetX, y: targetY)
        let event = scrollModel.converge()
        fire(
            velocityY: velocity,
            requestedScrollX: targetX,
            requestedScrollY: targetY,
            cancelled: false,
            active: true
        )
        return event
    }

    /// Ends the active middle-button drag (the button was released). Returns
    /// `true` when a drag was active and ended; `false` when no drag was active
    /// or after `dispose()`.
    @discardableResult
    public func endMiddleButtonScroll() -> Bool {
        guard !isDisposed else { return false }
        _lock.lock()
        let had = _anchor != nil
        _anchor = nil
        _lock.unlock()
        return had
    }

    /// Cancels the active middle-button drag when `token` has cancellation
    /// requested. Returns `true` when the drag was cancelled; `false` when the
    /// token has not been cancelled, no drag is active, or after `dispose()`.
    @discardableResult
    public func cancelMiddleButtonScroll(
        token: MonaCancellationToken
    ) -> Bool {
        guard !isDisposed else { return false }
        guard token.isCancellationRequested else { return false }
        _lock.lock()
        let had = _anchor != nil
        _anchor = nil
        _lock.unlock()
        if had {
            fire(
                velocityY: 0,
                requestedScrollX: 0,
                requestedScrollY: 0,
                cancelled: true,
                active: false
            )
        }
        return had
    }

    // MARK: - 3a. Mutation → MonaTransactionGateway

    /// Reveals `position` through the shared transaction gateway: begins a
    /// transaction, prepares a collapsed selection at `position` (the scroll's
    /// anchor), and commits the unit. Returns the committed selections (empty
    /// when the feature is disposed or the commit dropped).
    @discardableResult
    public func commitScrollReveal(
        gateway: MonaTransactionGateway,
        position: MonaPosition
    ) -> [MonaSelection] {
        guard !isDisposed else { return [] }
        let tx = gateway.beginTransaction()
        let selection = MonaSelection(anchor: position, activePosition: position)
        tx.prepareSelections([selection])
        _ = gateway.commit(tx)
        return gateway.lastCommittedSelections
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `event` through the shared provider executor, normalized onto
    /// the deterministic microtask queue. `receive` runs ONLY when the queue is
    /// drained (FIFO), after the publication ticket is validated.
    @discardableResult
    public func publishMiddleScrollEvent(
        _ event: MonaMiddleScrollEvent,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaMiddleScrollEvent) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(event),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, the drag anchor is cleared, and
    /// `beginMiddleButtonScroll` / `updateMiddleButtonScroll` /
    /// `cancelMiddleButtonScroll` / `commitScrollReveal` are no-ops.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        _anchor = nil
        _lock.unlock()
        if !already {
            emitter.dispose()
        }
    }

    // MARK: - 3d. Localization → MonaLocalization

    /// Returns the declared action labels formatted through the shared
    /// `MonaLocalization` surface under `profile`. middleScroll declares no
    /// actions, so this returns an empty array under every profile.
    public func localizedActionLabels(profile: MonaCodeEnvironmentProfile) -> [String] {
        let registry = MonaActionRegistry()
        return Self.declaredActionIds.map { id in
            let label = registry.identity(for: id)?.label ?? id
            return MonaLocalization.format(label, args: [], profile: profile)
        }
    }

    // MARK: - 3e. Degraded plain-text → MonaPlainTextLanguage

    /// The plain-text fallback language. middleScroll performs no
    /// tokenization-dependent work; it degrades gracefully to the plain-text
    /// fallback.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — middleScroll performs no tokenization-dependent work and
    /// degrades gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Fires a middle-scroll event when not disposed.
    private func fire(
        velocityY: Double,
        requestedScrollX: Double,
        requestedScrollY: Double,
        cancelled: Bool,
        active: Bool
    ) {
        guard !isDisposed else { return }
        emitter.fire(MonaMiddleScrollEvent(
            velocityY: velocityY,
            requestedScrollX: requestedScrollX,
            requestedScrollY: requestedScrollY,
            cancelled: cancelled,
            active: active
        ))
    }
}
