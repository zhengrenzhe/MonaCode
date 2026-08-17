// MonaDiffEditorBreadcrumbsFeature.swift
//
// P05-T113 — Implement retained feature diffEditorBreadcrumbs.
//
// `MonaDiffEditorBreadcrumbsFeature` is the Swift counterpart of Monaco's
// `diffEditorBreadcrumbs` contribution (monaco-editor 0.56.0): it presents
// multi-diff navigation breadcrumbs from host-owned item metadata — the
// ordered breadcrumb items the multi-diff editor renders above the diff surface
// to navigate between the diff entries the host owns.
//
// The host owns the diff item metadata (item id, label, URI, active flag); this
// feature projects that metadata into an ordered breadcrumb list, tracks the
// active breadcrumb, and emits a selection event when the user navigates to a
// breadcrumb. Diff construction itself is behind a Phase 07 adapter; this
// feature works from host-owned metadata and does NOT construct a diff editor.
//
// The feature is an AppKit surface (`import AppKit`, `import Foundation`,
// `import MonaCode`). It performs the three implementation operations every
// retained feature performs:
//
//   1. Feature-specific behavior — `buildBreadcrumbs`, `navigate(toIndex:)`,
//      keyed by host-owned item metadata.
//   2. Register the exact feature identity `diffEditorBreadcrumbs` and its
//      declared commands, actions, contributions, options, menus, and
//      keybindings, referenced verbatim from the frozen registries (no rename /
//      coalesce). diffEditorBreadcrumbs declares no own command registrations —
//      it is a host-metadata-driven presentation feature.
//   3. Route model mutation, asynchronous publication, disposal, localization,
//      and degraded plain-text behavior through the shared gateways — reusing
//      `MonaTransactionGateway` (mutation boundary), `MonaProviderExecutor` +
//      `MonaMicrotaskQueue` (async publication), `MonaEmitter` (disposal),
//      `MonaLocalization` (localization), and `MonaPlainTextLanguage`
//      (degraded plain text). No parallel mechanisms are introduced.

import AppKit
import Foundation
import MonaCode

/// Host-owned metadata for one multi-diff item, the source from which the
/// breadcrumbs are presented.
public struct MonaDiffEditorBreadcrumbMetadata {

    /// The host-owned diff item id (the multi-diff entry this breadcrumb
    /// navigates to).
    public let itemId: String

    /// The human-readable label rendered on the breadcrumb.
    public let label: String

    /// The item URI, when known.
    public let uri: MonaURI?

    /// Whether this item is the active diff entry the editor is currently
    /// showing.
    public let isActive: Bool

    public init(itemId: String, label: String, uri: MonaURI? = nil, isActive: Bool = false) {
        self.itemId = itemId
        self.label = label
        self.uri = uri
        self.isActive = isActive
    }
}

/// A single breadcrumb presented in the multi-diff navigation strip.
public struct MonaDiffEditorBreadcrumbItem {

    /// The host-owned diff item id this breadcrumb navigates to.
    public let itemId: String

    /// The human-readable label rendered on the breadcrumb.
    public let label: String

    /// The item URI, when known.
    public let uri: MonaURI?

    /// Whether this breadcrumb is the active one.
    public let isActive: Bool

    public init(itemId: String, label: String, uri: MonaURI? = nil, isActive: Bool = false) {
        self.itemId = itemId
        self.label = label
        self.uri = uri
        self.isActive = isActive
    }
}

/// A breadcrumb navigation event: the selected item id and its index.
public struct MonaDiffEditorBreadcrumbsEvent: Equatable {

    /// The host-owned diff item id the user navigated to.
    public let selectedItemId: String

    /// The index of the selected breadcrumb.
    public let selectedIndex: Int

    public init(selectedItemId: String, selectedIndex: Int) {
        self.selectedItemId = selectedItemId
        self.selectedIndex = selectedIndex
    }
}

/// The diffEditorBreadcrumbs feature: present multi-diff navigation breadcrumbs
/// from host-owned item metadata.
///
/// The feature identity `diffEditorBreadcrumbs` and its declared slice are
/// referenced verbatim from the frozen registries. diffEditorBreadcrumbs declares
/// no own command registrations — it is a host-metadata-driven presentation
/// feature. The host-owned item metadata is projected into an ordered breadcrumb
/// list; the active breadcrumb is tracked; navigation emits a selection event
/// routed asynchronously through `MonaProviderExecutor` + `MonaMicrotaskQueue`.
/// Disposal is routed through `MonaEmitter`; localization through
/// `MonaLocalization`; and degraded plain-text behavior through
/// `MonaPlainTextLanguage`.
public final class MonaDiffEditorBreadcrumbsFeature: MonaDisposable {

    /// The frozen feature identity (`"diffEditorBreadcrumbs"`).
    public static let featureId = "diffEditorBreadcrumbs"

    // MARK: - Declared slice (verbatim from the F1-R3 scope manifest / registries)

    /// The declared action IDs. diffEditorBreadcrumbs declares no actions.
    public static let declaredActionIds: [String] = []

    /// The declared command IDs. diffEditorBreadcrumbs declares no commands.
    public static let declaredCommandIds: [String] = []

    /// The declared contribution IDs. diffEditorBreadcrumbs declares no
    /// contributions — it is a host-metadata-driven presentation feature.
    public static let declaredContributionIds: [String] = []

    /// The declared keybinding commands. diffEditorBreadcrumbs declares none.
    public static let declaredKeybindingCommands: [String] = []

    /// The declared option names. diffEditorBreadcrumbs declares no options.
    public static let declaredOptionIds: [String] = []

    /// The declared menu IDs. diffEditorBreadcrumbs declares no menu items.
    public static let declaredMenuIds: [String] = []

    // MARK: - Routing state

    /// The breadcrumb items currently presented, in order.
    private var breadcrumbs: [MonaDiffEditorBreadcrumbItem] = []

    /// The index of the active breadcrumb, or `nil` when no breadcrumbs are
    /// presented.
    private(set) public var activeBreadcrumbIndex: Int?

    private let emitter = MonaEmitter<MonaDiffEditorBreadcrumbsEvent>()

    /// The event stream for breadcrumb navigation. Subscribe with
    /// `onChange { event in ... }`; the returned disposable removes the listener.
    public var onChange: MonaEvent<MonaDiffEditorBreadcrumbsEvent> { emitter.event }

    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates the diffEditorBreadcrumbs feature.
    public init() {}

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _isDisposed
    }

    /// The number of breadcrumbs currently presented. Zero after `dispose()`.
    public var breadcrumbCount: Int {
        _lock.lock(); defer { _lock.unlock() }
        return breadcrumbs.count
    }

    // MARK: - 1. Feature-specific behavior: present breadcrumbs from host metadata

    /// Builds the ordered breadcrumb items from host-owned `metadata`, retaining
    /// them and marking the active breadcrumb. Returns the presented breadcrumbs,
    /// or an empty array after `dispose()`.
    @discardableResult
    public func buildBreadcrumbs(
        from metadata: [MonaDiffEditorBreadcrumbMetadata]
    ) -> [MonaDiffEditorBreadcrumbItem] {
        guard !isDisposed else { return [] }
        let items = metadata.map {
            MonaDiffEditorBreadcrumbItem(
                itemId: $0.itemId,
                label: $0.label,
                uri: $0.uri,
                isActive: $0.isActive
            )
        }
        _lock.lock()
        breadcrumbs = items
        activeBreadcrumbIndex = items.firstIndex(where: { $0.isActive })
        _lock.unlock()
        return items
    }

    /// Navigates to the breadcrumb at `index`, marking it active and firing a
    /// selection event. Returns `true` when the index is in range; `false`
    /// (and no event) when out of bounds or after `dispose()`.
    @discardableResult
    public func navigate(toIndex index: Int) -> Bool {
        guard !isDisposed else { return false }
        _lock.lock()
        let count = breadcrumbs.count
        guard index >= 0, index < count else {
            _lock.unlock()
            return false
        }
        let itemId = breadcrumbs[index].itemId
        // Re-mark the active flag on the retained items.
        breadcrumbs = breadcrumbs.enumerated().map { offset, item in
            MonaDiffEditorBreadcrumbItem(
                itemId: item.itemId,
                label: item.label,
                uri: item.uri,
                isActive: offset == index
            )
        }
        activeBreadcrumbIndex = index
        _lock.unlock()
        fire(.init(selectedItemId: itemId, selectedIndex: index))
        return true
    }

    // MARK: - 3b. Async publication → MonaProviderExecutor + MonaMicrotaskQueue

    /// Publishes `event` through the shared provider executor, normalized onto
    /// the deterministic microtask queue. `receive` runs ONLY when the queue is
    /// drained (FIFO), after the publication ticket is validated.
    @discardableResult
    public func publishBreadcrumbsEvent(
        _ event: MonaDiffEditorBreadcrumbsEvent,
        executor: MonaProviderExecutor,
        ticket: MonaAsyncValidityTicket,
        receive: @escaping (MonaDiffEditorBreadcrumbsEvent) -> Void
    ) -> Bool {
        return executor.publish(
            .synchronous(event),
            ticket: ticket,
            receive: receive
        )
    }

    // MARK: - 3c. Disposal → MonaEmitter / MonaDisposable

    /// Disposes the feature. Idempotent: a second call is a no-op. After
    /// disposal, listeners are dropped, retained breadcrumbs are released, and
    /// `buildBreadcrumbs` / `navigate` are no-ops.
    public func dispose() {
        _lock.lock()
        let already = _isDisposed
        _isDisposed = true
        breadcrumbs.removeAll()
        activeBreadcrumbIndex = nil
        _lock.unlock()
        if !already {
            emitter.dispose()
        }
    }

    // MARK: - 3d. Localization → MonaLocalization

    /// Returns the declared action labels formatted through the shared
    /// `MonaLocalization` surface under `profile`. diffEditorBreadcrumbs
    /// declares no actions, so this is always empty.
    public func localizedActionLabels(profile: MonaCodeEnvironmentProfile) -> [String] {
        let registry = MonaActionRegistry()
        return Self.declaredActionIds.map { id in
            let label = registry.identity(for: id)?.label ?? id
            return MonaLocalization.format(label, args: [], profile: profile)
        }
    }

    // MARK: - 3e. Degraded plain-text → MonaPlainTextLanguage

    /// The plain-text fallback language. diffEditorBreadcrumbs needs no
    /// tokenization; it degrades to plain text for its tokenization needs.
    public var degradedLanguage: MonaPlainTextLanguage { MonaPlainTextLanguage() }

    /// `true` — diffEditorBreadcrumbs performs no tokenization-dependent work
    /// and degrades gracefully to the plain-text fallback.
    public var isPlainTextDegraded: Bool { true }

    // MARK: - Private

    /// Fires a breadcrumb navigation event when not disposed.
    private func fire(_ event: MonaDiffEditorBreadcrumbsEvent) {
        guard !isDisposed else { return }
        emitter.fire(event)
    }
}
