// MonaEditorLifetime.swift
//
// P01-T012 — Implement application-global and per-editor lifetime registries.
//
// `MonaEditorLifetime` is the per-editor lifetime — the Swift counterpart of
// Monaco's per-instance ownership scope (monaco-editor 0.56.0, fixed by the
// H2-R `perEditorLifetime` closure). It owns per-editor resources: the seven
// per-editor state categories (model attachment + ownership tag, selection and
// cursors, scroll/focus/view-state/context, projection/folds/zones/injected
// contributions, widgets, Core Text layout + renderer surfaces + editor-local
// caches, IME/pointer/event-dispatch) recorded in the H2-R
// `runtimeScope.perEditorMainActor` table.
//
// H2-R ownership contract:
//
//   - Per-editor state is owned by exactly one `MonaEditorLifetime` per editor
//     instance. Each registered child carries an explicit owner tag (one of the
//     seven `MonaEditorResourceOwner` categories) so the C09 embedding/lifetime
//     gate can verify the per-editor ownership graph is closed.
//   - Disposing an editor removes its per-editor state but NEVER disposes an
//     externally supplied model or unrelated global registration (H2-R
//     `disposalRule`). `MonaEditorLifetime` disposes only the children
//     explicitly registered with it.
//   - Children are disposed in REVERSE acquisition order (LIFO).
//   - Teardown is idempotent: the first `dispose()` runs reverse-order
//     disposal; every subsequent `dispose()` is a no-op. Registering after
//     `dispose()` immediately disposes that child so it cannot leak.
//
// Accounting hooks (for C09 and the 1000-cycle lifecycle gate) expose the
// current registered count and the distinct owner set.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The seven per-editor owner categories fixed by the H2-R
/// `runtimeScope.perEditorMainActor` table. Each resource registered with a
/// `MonaEditorLifetime` carries one of these tags so the per-editor ownership
/// graph is explicit and machine-verifiable by the C09 embedding/lifetime gate.
public enum MonaEditorResourceOwner: String, Sendable, Equatable, CaseIterable {

    /// Model attachment reference and ownership tag (implicitOwned /
    /// externalBorrowed / none).
    case modelAttachment

    /// Selection and cursor collection.
    case selectionCursor

    /// Scroll, focus, view state and context-key child scope.
    case scrollFocusContext

    /// Projection, folds, view zones, injected text and contribution instances.
    case projectionFoldsZonesInjectedContributions

    /// Content, overlay and glyph-margin widget instances.
    case widgets

    /// Core Text layout records, renderer surfaces and editor-local derived
    /// caches.
    case layoutRendererCaches

    /// IME composition, pointer and event-dispatch state.
    case imePointerEventDispatch
}

/// The per-editor lifetime — the owner of an editor instance's resources.
///
/// Create one per editor. Register per-editor resources with
/// `register(_:resource:)`, declaring the owning category. Tear down with
/// `dispose()`, which disposes every registered child in reverse acquisition
/// order. Repeated `dispose()` is inert. Registering after `dispose()`
/// immediately disposes the resource so it cannot leak.
///
/// `MonaEditorLifetime` disposes ONLY the children explicitly registered with
/// it; it never disposes a borrowed model or a global registration (H2-R
/// `disposalRule`).
///
/// Thread-safe: all registration and teardown state is guarded by an
/// `NSLock`. `@unchecked Sendable` because the lock is the synchronization
/// boundary.
public final class MonaEditorLifetime: MonaDisposable, @unchecked Sendable {

    /// A registered child: the explicit owner tag plus the disposable resource.
    private struct Entry {
        let owner: MonaEditorResourceOwner
        let resource: MonaDisposable
    }

    private let lock = NSLock()
    private var entries: [Entry] = []
    private var disposed = false

    /// Creates a new, empty per-editor lifetime.
    public init() {}

    /// `true` after `dispose()` has run. Sticky: once `true`, never `false`.
    public var isDisposed: Bool {
        lock.lock()
        defer { lock.unlock() }
        return disposed
    }

    /// The number of resources currently registered (not yet torn down).
    /// Returns 0 after `dispose()`.
    public var registeredCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.count
    }

    /// The owner tags of the currently-registered resources, in acquisition
    /// order. Returns an empty array after `dispose()`.
    public var registeredOwners: [MonaEditorResourceOwner] {
        lock.lock()
        defer { lock.unlock() }
        return entries.map { $0.owner }
    }

    /// Registers `resource` as a child of this editor lifetime, owned by
    /// `owner`.
    ///
    /// On `dispose()`, registered children are disposed in reverse
    /// acquisition order (the last registered is disposed first).
    ///
    /// If called after `dispose()`, `resource` is disposed immediately and
    /// not tracked, so it can never leak.
    public func register(
        _ owner: MonaEditorResourceOwner,
        _ resource: MonaDisposable
    ) {
        lock.lock()
        if disposed {
            lock.unlock()
            resource.dispose()
            return
        }
        entries.append(Entry(owner: owner, resource: resource))
        lock.unlock()
    }

    /// Tears down this editor lifetime. Disposes every registered child in
    /// REVERSE acquisition order (LIFO). Idempotent: the first call performs
    /// disposal; every subsequent call is a no-op. Clears the registration
    /// table so children are released.
    ///
    /// Per H2-R `disposalRule`, this disposes only the children explicitly
    /// registered here; it never disposes a borrowed model or a global
    /// registration.
    public func dispose() {
        lock.lock()
        guard !disposed else {
            lock.unlock()
            return
        }
        disposed = true
        let toDispose = entries.reversed()
        entries.removeAll()
        lock.unlock()

        for entry in toDispose {
            entry.resource.dispose()
        }
    }
}
