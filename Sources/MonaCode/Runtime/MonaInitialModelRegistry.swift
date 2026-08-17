// MonaInitialModelRegistry.swift
//
// P01-T012 — Implement application-global and per-editor lifetime registries.
//
// `MonaInitialModelRegistry` tracks initial model state for the first-model /
// initialization path — the Swift counterpart of Monaco's editor-model
// construction tracking (monaco-editor 0.56.0, fixed by the H2-R
// `perEditorLifetime` closure and the `editorModelConstruction` table).
//
// H2-R fixes exactly three model construction cases (the
// `MonaInitialModel` discriminant):
//
//   - `implicitOwned`  — the construction option's model field is omitted; a
//                        new process-registered model is created from value
//                        or empty raw UTF-16 and the selected/inferred
//                        language; the editor disposes it on first detach,
//                        replace, or editor disposal.
//   - `externalBorrowed` — the construction option's model field contains a
//                        live model; the exact reference is attached; replace
//                        or dispose only detaches and NEVER disposes the
//                        external model.
//   - `none`           — explicit null; no model is created or attached.
//
// The registry records which construction case was used for each initial
// model and holds the model WEAKLY. Weak accounting is the contract surface
// for C09 (the embedding/lifetime complexity gate) and the 1000-cycle
// lifecycle gate:
//
//   - `liveCount` reports how many tracked models are still alive. Dropping the
//     owner's strong reference deallocates the model and the registry stops
//     counting it — this is the leak signal the 1000-cycle gate asserts
//     returns to zero after every create/dispose cycle.
//   - `totalRegistered` is the cumulative registration count (sticky), the
//     bound metric C09 checks against the source-bound state limits.
//   - `liveOwners` reports the construction kinds of the still-live models, in
//     registration order, so the gate can verify the live set composition.
//
// The registry does NOT own the models: it never disposes them (the editor
// lifetime owns `implicitOwned` models; the host owns `externalBorrowed`
// models). `dispose()` clears the tracking table; it is idempotent.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The three initial-model construction cases fixed by the H2-R
/// `editorModelConstruction` table.
public enum MonaInitialModel: Sendable, Equatable {

    /// The construction option's model field is omitted. A new
    /// process-registered model is created from value or empty raw UTF-16 and
    /// the selected/inferred language; the editor owns and disposes it.
    case implicitOwned

    /// The construction option's model field contains a live model. The exact
    /// reference is attached; replace/dispose only detaches and never disposes
    /// the external model.
    case externalBorrowed

    /// Explicit null. No model is created or attached.
    case none
}

/// Tracks initial model state for the first-model/initialization path.
///
/// Register each editor's initial model with `register(_:model:)`, declaring
/// the construction case. The registry holds the model WEAKLY so it can
/// observe release without retaining — the weak accounting hooks
/// (`liveCount`, `totalRegistered`, `liveOwners`) are the contract surface for
/// the C09 complexity gate and the 1000-cycle lifecycle gate.
///
/// The registry never owns the models: it does not dispose them. `dispose()`
/// clears the tracking table and is idempotent.
///
/// Thread-safe: all tracking state is guarded by an `NSLock`.
/// `@unchecked Sendable` because the lock is the synchronization boundary.
public final class MonaInitialModelRegistry: MonaDisposable, @unchecked Sendable {

    /// A weakly-held model plus its construction case. A reference type so the
    /// weak reference is shared (not copied under value semantics) when the
    /// tracking array is iterated for accounting.
    private final class Tracked {
        let kind: MonaInitialModel
        weak var model: MonaCodeModel?

        init(kind: MonaInitialModel, model: MonaCodeModel?) {
            self.kind = kind
            self.model = model
        }
    }

    private let lock = NSLock()
    private var tracked: [Tracked] = []
    private var totalRegisteredCount = 0
    private var disposed = false

    /// Creates a new, empty initial-model registry.
    public init() {}

    /// `true` after `dispose()` has run. Sticky: once `true`, never `false`.
    public var isDisposed: Bool {
        lock.lock()
        defer { lock.unlock() }
        return disposed
    }

    /// The cumulative number of registrations recorded by this registry
    /// (sticky — never reset). This is the bound metric the C09 complexity gate
    /// checks against the source-bound state limits.
    public var totalRegistered: Int {
        lock.lock()
        defer { lock.unlock() }
        return totalRegisteredCount
    }

    /// The number of tracked models still alive (weakly observed). Dropping the
    /// owner's strong reference deallocates the model and this count drops —
    /// the leak signal the 1000-cycle lifecycle gate asserts returns to zero.
    public var liveCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return tracked.reduce(into: 0) { count, entry in
            if entry.model != nil { count += 1 }
        }
    }

    /// The construction kinds of the still-live tracked models, in registration
    /// order. Models whose weak reference has cleared are omitted.
    public var liveOwners: [MonaInitialModel] {
        lock.lock()
        defer { lock.unlock() }
        return tracked.reduce(into: [MonaInitialModel]()) { result, entry in
            if entry.model != nil { result.append(entry.kind) }
        }
    }

    /// Records that an editor's initial model was constructed with `kind`.
    ///
    /// - For `.implicitOwned` and `.externalBorrowed`, pass the model; it is
    ///   held weakly so the registry observes release without retaining.
    /// - For `.none`, pass `nil` (no model to track); the registration is still
    ///   counted in `totalRegistered`.
    ///
    /// The registry never disposes the model. After `dispose()`, this method is
    /// a no-op (the registry is terminal).
    public func register(_ kind: MonaInitialModel, model: MonaCodeModel?) {
        lock.lock()
        guard !disposed else {
            lock.unlock()
            return
        }
        tracked.append(Tracked(kind: kind, model: model))
        totalRegisteredCount += 1
        lock.unlock()
    }

    /// Clears the tracking table. Idempotent: the first call clears the table;
    /// every subsequent call is a no-op. The registry never disposes tracked
    /// models (it does not own them). `totalRegistered` is sticky and is not
    /// reset.
    public func dispose() {
        lock.lock()
        guard !disposed else {
            lock.unlock()
            return
        }
        disposed = true
        tracked.removeAll()
        lock.unlock()
    }
}
