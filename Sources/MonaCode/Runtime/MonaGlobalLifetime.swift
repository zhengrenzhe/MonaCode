// MonaGlobalLifetime.swift
//
// P01-T012 — Implement application-global and per-editor lifetime registries.
//
// `MonaGlobalLifetime` is the application-global lifetime — the Swift counterpart
// of Monaco's process-global ownership scope (monaco-editor 0.56.0, fixed by
// the H2-R `globalLifetime` closure). It owns global resources: the eight
// process-global registries and services (environment-services, model-registry,
// editor-registry, marker-registry, theme-registry, language-registry,
// command-keybinding-menu-registry, opener-registry) recorded in the H2-R
// `runtimeScope.processGlobalMainActor` table.
//
// H2-R ownership contract:
//
//   - Process-global state is owned by exactly one application-global lifetime.
//     Each registered child carries an explicit owner tag (one of the eight
//     `MonaGlobalResourceOwner` categories) so the C09 embedding/lifetime
//     gate can verify the ownership graph is closed and every resource is
//     accounted for.
//   - Children are disposed in REVERSE acquisition order (LIFO), mirroring
//     vscode's `DisposableStore` / `ReferenceCollection` which dispose in the
//     reverse of insertion order "to be safe" (a later registration may depend
//     on an earlier one).
//   - Teardown is idempotent: the first `dispose()` runs reverse-order disposal
//     of every registered child; every subsequent `dispose()` is a no-op.
//     Registering a child after `dispose()` immediately disposes that child so
//     it can never leak (matching vscode's `DisposableStore.add` after dispose).
//
// Accounting hooks (for C09 and the 1000-cycle lifecycle gate) expose the
// current registered count and the distinct owner set without retaining
// resources beyond the registration itself.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The eight process-global owner categories fixed by the H2-R
/// `runtimeScope.processGlobalMainActor` table. Each resource registered with a
/// `MonaGlobalLifetime` carries one of these tags so the ownership graph is
/// explicit and machine-verifiable by the C09 embedding/lifetime gate.
public enum MonaGlobalResourceOwner: String, Sendable, Equatable, CaseIterable {

    /// `MonaCodeEnvironment` and all standalone service overrides.
    case environmentServices

    /// All explicitly created and editor-implicitly-created live models keyed
    /// by canonical `MonaURI`.
    case modelRegistry

    /// Live code editors and diff editors plus create/dispose events.
    case editorRegistry

    /// Marker owners and resource markers.
    case markerRegistry

    /// Builtin themes, custom theme definitions, the active theme, the token
    /// color map and high-contrast auto-detection.
    case themeRegistry

    /// Language metadata, configurations, token providers and all retained
    /// provider registries.
    case languageRegistry

    /// Global commands, dynamic keybindings, global actions and menu items.
    case commandKeybindingMenuRegistry

    /// Link and code-editor openers.
    case openerRegistry
}

/// The application-global lifetime — the single owner of process-global
/// resources (registries and services).
///
/// Create one per application (host process). Register global resources with
/// `register(_:resource:)`, declaring the owning category. Tear down with
/// `dispose()`, which disposes every registered child in reverse acquisition
/// order. Repeated `dispose()` is inert. Registering after `dispose()`
/// immediately disposes the resource so it cannot leak.
///
/// Thread-safe: all registration and teardown state is guarded by an
/// `NSLock`. `@unchecked Sendable` because the lock is the synchronization
/// boundary — the registry is safe to share across isolation domains, which
/// is its intended use as a process-global singleton.
public final class MonaGlobalLifetime: MonaDisposable, @unchecked Sendable {

    /// A registered child: the explicit owner tag plus the disposable resource.
    private struct Entry {
        let owner: MonaGlobalResourceOwner
        let resource: MonaDisposable
    }

    private let lock = NSLock()
    private var entries: [Entry] = []
    private var disposed = false

    /// Creates a new, empty application-global lifetime.
    public init() {}

    /// `true` after `dispose()` has run. Sticky: once `true`, never `false`.
    public var isDisposed: Bool {
        lock.lock()
        defer { lock.unlock() }
        return disposed
    }

    /// The number of resources currently registered (not yet torn down).
    /// Returns 0 after `dispose()`. This is the accounting hook the C09 gate
    /// uses to verify the live registration set is bounded.
    public var registeredCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.count
    }

    /// The owner tags of the currently-registered resources, in acquisition
    /// order. Returns an empty array after `dispose()`.
    public var registeredOwners: [MonaGlobalResourceOwner] {
        lock.lock()
        defer { lock.unlock() }
        return entries.map { $0.owner }
    }

    /// Registers `resource` as a child of this lifetime, owned by `owner`.
    ///
    /// On `dispose()`, registered children are disposed in reverse
    /// acquisition order (the last registered is disposed first).
    ///
    /// If called after `dispose()`, `resource` is disposed immediately and
    /// not tracked, so it can never leak. This mirrors vscode's
    /// `DisposableStore.add` semantics for a disposed store.
    public func register(
        _ owner: MonaGlobalResourceOwner,
        _ resource: MonaDisposable
    ) {
        lock.lock()
        if disposed {
            lock.unlock()
            // Disposed: dispose immediately so the resource is never leaked.
            resource.dispose()
            return
        }
        entries.append(Entry(owner: owner, resource: resource))
        lock.unlock()
    }

    /// Tears down this lifetime. Disposes every registered child in REVERSE
    /// acquisition order (LIFO: the last registered is disposed first).
    /// Idempotent: the first call performs disposal; every subsequent call is
    /// a no-op. Clears the registration table so children are released.
    public func dispose() {
        lock.lock()
        guard !disposed else {
            lock.unlock()
            return
        }
        disposed = true
        // Reverse acquisition order: snapshot reversed so disposal runs
        // outside the lock (a child's dispose may itself register/dispose
        // other resources and must not deadlock).
        let toDispose = entries.reversed()
        entries.removeAll()
        lock.unlock()

        for entry in toDispose {
            entry.resource.dispose()
        }
    }
}
