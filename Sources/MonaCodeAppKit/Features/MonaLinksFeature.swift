// MonaLinksFeature.swift
//
// P05-T136 — Implement retained feature links.
//
// `MonaLinksFeature` is the Swift counterpart of Monaco's `links` contribution
// (monaco-editor 0.56.0): it retains document links provided by a
// `MonaLinkProvider`, keyed by model version, and surfaces the request /
// resolve / underline / activate / release lifecycle using native AppKit
// rendering. Requesting asks the provider for the links at a model version and
// publishes the result through the shared `MonaProviderExecutor` (which
// validates a `MonaAsyncValidityTicket` immediately before publication — the
// version gate) and may be gated by a `MonaCancellationToken` (the cancellation
// gate). Resolving produces the link's target URL. Underlining renders the
// link's text with the AX/rendering underline attribute (`NSUnderlineStyle`).
// Activating commits a selection covering the link's range through
// `MonaTransactionGateway`. Releasing drops the links retained for a stale
// model version.
//
// The feature is an AppKit surface (`import AppKit`, `import Foundation`,
// `import MonaCode` — the underline step produces an `NSAttributedString`). It
// performs the three implementation operations every retained feature performs:
//
//   1. Feature-specific behavior — `requestLinks`, `resolveLink`,
//      `underlineLink`, `activateLink`, and `releaseLinks`, all keyed by model
//      version, with native AppKit rendering of the underline attribute.
//   2. Register the exact feature identity `links` and its declared commands,
//      actions, contributions, options, menus, and keybindings, referenced
//      verbatim from the frozen registries (no rename / coalesce).
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import AppKit
import Foundation
import MonaCode

/// A document link: the range it covers, its target URL (or `nil` when the
/// link has no resolvable target), and an optional tooltip.
public struct MonaLink: Equatable {

    /// The range the link covers.
    public let range: MonaRange

    /// The link's target URL, or `nil` when the link has no resolvable target.
    public let url: String?

    /// An optional tooltip shown when the link is hovered.
    public let tooltip: String?

    public init(range: MonaRange, url: String?, tooltip: String? = nil) {
        self.range = range
        self.url = url
        self.tooltip = tooltip
    }
}

/// A links event: the retained links and the model version they are retained
/// against.
public struct MonaLinksEvent: Equatable {

    /// The retained links (empty when released).
    public let links: [MonaLink]

    /// The model version the links are retained against.
    public let modelVersion: Int

    public init(links: [MonaLink], modelVersion: Int) {
        self.links = links
        self.modelVersion = modelVersion
    }
}

/// A link provider — the Swift counterpart of Monaco's `LinkProvider`. Returns
/// the document links for `model`, gated by `token`.
///
/// The result is published through `MonaProviderExecutor`, so a provider may
/// return its result in any of the seven normalized shapes (synchronous,
/// asynchronous, optional, throwing, cancelable, resolvable, releasable). The
/// `token` is the cancellation gate: a provider that performs async work should
/// observe it and short-circuit when cancellation is requested.
public protocol MonaLinkProvider {

    /// Returns the document links for `model`, gated by `token`.
    func provideLinks(
        model: MonaCodeModel,
        token: MonaCancellationToken
    ) -> MonaProviderResult<[MonaLink]>
}

/// The links feature: request, resolve, underline, activate, and release
/// document links, retained by model version.
///
/// The feature identity `links` and its declared slice are referenced verbatim
/// from the frozen registries. Model mutation (activate / reveal) is routed
/// through `MonaTransactionGateway`; asynchronous publication (including the
/// provider result) through `MonaProviderExecutor` + `MonaMicrotaskQueue`;
/// disposal through `MonaEmitter`; localization through `MonaLocalization`;
/// and degraded plain-text behavior through `MonaPlainTextLanguage`.
public final class MonaLinksFeature: MonaDisposable {

    /// The frozen feature identity (`"links"`).
    public static let featureId = "links"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs in source order (no rename / coalesce). The
    /// single links action: `editor.action.openLink` (ordinal 139, "Open
    /// Link").
    public static let declaredActionIds: [String] = [
        "editor.action.openLink"
    ]

    /// The declared command IDs in source order. The links feature registers
    /// the internal `_executeLinkProvider` command (to run registered link
    /// providers) and the `editor.action.openLink` action-command.
    public static let declaredCommandIds: [String] = [
        "_executeLinkProvider",
        "editor.action.openLink"
    ]

    /// The declared contribution ID. The link detector — the single links
    /// contribution (ordinal 33).
    public static let declaredContributionIds: [String] = [
        "editor.linkDetector"
    ]

    /// The declared keybinding commands — links registers no default
    /// keybindings (`editor.action.openLink` carries no default keybinding),
    /// so this slice is empty.
    public static let declaredKeybindingCommands: [String] = []

    /// The declared option names — the `links` editor option (boolean,
    /// default `true`).
    public static let declaredOptionIds: [String] = [
        "links"
    ]

    /// The declared menu IDs — links registers no menu items, so this slice is
    /// empty.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    /// The links retained by model version. A stale model version's links are
    /// released by `releaseLinks(modelVersion:)`.
    private var retainedByVersion: [Int: [MonaLink]] = [:]

    /// The currently staged links (the most recent requested / retained).
    private var _stagedLinks: [MonaLink]? = nil

    private let emitter = MonaEmitter<MonaLinksEvent>()

    /// The event stream for links changes. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaLinksEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the links feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    /// The currently staged links, or `nil` when none are staged (or after
    /// disposal).
    public var stagedLinks: [MonaLink]? {
        _lock.lock(); defer { _lock.unlock() }
        return _stagedLinks
    }

    // MARK: - 1. Feature-specific behavior: request / resolve / underline / activate / release

    /// Requests document links from `provider` for `model`, retaining the
    /// result keyed by model version and staging it as the current links. The
    /// provider's result is published through the shared `executor`, normalized
    /// onto the deterministic microtask queue with `ticket` validated
    /// immediately before publication (the version gate) and `token` available
    /// as the cancellation gate.
    ///
    /// `receive` runs ONLY when the queue is drained (FIFO), after the ticket
    /// is validated and the cancellation gate has not suppressed publication.
    /// When the result carries links, they are retained against the model's
    /// current version. Returns `true` when the result was accepted onto the
    /// publication path (enqueued / armed); `false` after `dispose()` or when
    /// the shape normalized to "no value to publish".
    @discardableResult
    public func requestLinks(
        provider: MonaLinkProvider,
        model: MonaCodeModel,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        token: MonaCancellationToken,
        receive: @escaping ([MonaLink]) -> Void
    ) -> Bool {
        guard !isDisposed else { return false }
        let version = model.getVersionId()
        let result = provider.provideLinks(model: model, token: token)
        return executor.publish(result, ticket: ticket) { [weak self] links in
            self?.retainLinks(links, modelVersion: version)
            receive(links)
        }
    }

    /// The number of link sets retained for `modelVersion` (0 or 1). Zero when
    /// the version has no retained links (or after disposal).
    public func retainedLinksCount(for modelVersion: Int) -> Int {
        _lock.lock(); defer { _lock.unlock() }
        return retainedByVersion[modelVersion] != nil ? 1 : 0
    }

    /// Resolves `link`'s target URL, gated by `token`. Returns the link when
    /// it carries a resolvable URL; `nil` when the link has no URL or the
    /// cancellation gate has been requested. After `dispose()`, returns `nil`.
    public func resolveLink(
        _ link: MonaLink,
        token: MonaCancellationToken
    ) -> MonaLink? {
        guard !isDisposed else { return nil }
        if token.isCancellationRequested { return nil }
        guard link.url != nil else { return nil }
        return link
    }

    /// Renders `link` to an `NSAttributedString` with the AX/rendering
    /// underline attribute (`NSUnderlineStyle.single`) and the link color, for
    /// native inline display. Returns an empty attributed string after
    /// `dispose()`.
    public func underlineLink(_ link: MonaLink) -> NSAttributedString {
        guard !isDisposed else { return NSAttributedString() }
        let attributed = NSMutableAttributedString()
        let label = link.tooltip ?? link.url ?? "link"
        let range = NSRange(location: 0, length: label.utf16.count)
        attributed.append(NSAttributedString(string: label))
        attributed.addAttribute(
            .underlineStyle,
            value: NSUnderlineStyle.single.rawValue,
            range: range
        )
        attributed.addAttribute(
            .foregroundColor,
            value: NSColor.blue,
            range: range
        )
        return attributed
    }

    /// Activates `link` by committing a selection covering its range through
    /// the shared transaction gateway: begins a transaction, prepares a
    /// selection from the link's start to its end, and commits the unit.
    /// Returns the committed selections (empty when the feature is disposed or
    /// the commit dropped).
    @discardableResult
    public func activateLink(
        _ link: MonaLink,
        gateway: MonaTransactionGateway
    ) -> [MonaSelection] {
        guard !isDisposed else { return [] }
        let tx = gateway.beginTransaction()
        let selection = MonaSelection(
            anchor: link.range.startPosition,
            activePosition: link.range.endPosition
        )
        tx.prepareSelections([selection])
        _ = gateway.commit(tx)
        return gateway.lastCommittedSelections
    }

    /// Releases the links retained for `modelVersion` (the model has advanced
    /// past that version, so the result is stale). Returns `1` when a link set
    /// was released, `0` otherwise. After `dispose()`, returns `0`.
    @discardableResult
    public func releaseLinks(modelVersion: Int) -> Int {
        _lock.lock(); defer { _lock.unlock() }
        if _isDisposed { return 0 }
        return retainedByVersion.removeValue(forKey: modelVersion) != nil ? 1 : 0
    }

    // MARK: - 3a. Mutation → MonaTransactionGateway

    /// Reveals the staged links' first range through the shared transaction
    /// gateway: begins a transaction, prepares a collapsed selection at the
    /// first staged link's start, and commits the unit. Returns the committed
    /// selections (empty when the feature is disposed, no links are staged, or
    /// the commit dropped).
    @discardableResult
    public func commitReveal(gateway: MonaTransactionGateway) -> [MonaSelection] {
        guard !isDisposed else { return [] }
        _lock.lock()
        let first = _stagedLinks?.first
        _lock.unlock()
        guard let link = first else { return [] }
        let tx = gateway.beginTransaction()
        let position = link.range.startPosition
        let selection = MonaSelection(anchor: position, activePosition: position)
        tx.prepareSelections([selection])
        _ = gateway.commit(tx)
        return gateway.lastCommittedSelections
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `links` through the shared provider executor, normalized onto
    /// the deterministic microtask queue. `receive` runs ONLY when the queue is
    /// drained (FIFO), after the publication ticket is validated.
    @discardableResult
    public func publishLinks(
        _ links: [MonaLink],
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping ([MonaLink]) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(links),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, retained links are released, the
    /// staged links are cleared, and `requestLinks` / `resolveLink` /
    /// `underlineLink` / `activateLink` / `releaseLinks` / `commitReveal` are
    /// no-ops.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        retainedByVersion.removeAll()
        _stagedLinks = nil
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

    /// The plain-text fallback language. links needs no tokenization; it
    /// degrades gracefully to the plain-text fallback for its rendering needs.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — links performs no tokenization-dependent work and degrades
    /// gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Retains `links` against `modelVersion`, firing a links event. Called
    /// inside the executor's publication microtask, so the ticket has already
    /// been validated.
    private func retainLinks(_ links: [MonaLink], modelVersion: Int) {
        _lock.lock()
        let disposed = _isDisposed
        if !disposed {
            retainedByVersion[modelVersion] = links
            _stagedLinks = links
        }
        _lock.unlock()
        fire(links, modelVersion: modelVersion)
    }

    /// Fires a links event when not disposed.
    private func fire(_ links: [MonaLink], modelVersion: Int) {
        guard !isDisposed else { return }
        emitter.fire(MonaLinksEvent(links: links, modelVersion: modelVersion))
    }
}
