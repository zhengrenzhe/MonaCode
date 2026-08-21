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

/// The kind of mutation reported by `MonaGlobalModelRegistry.onDidChangeModels`.
///
/// Mirrors the lifecycle transitions Monaco's model service emits through
/// `onDidCreateModel` / `onWillDisposeModel` / `onDidChangeModelLanguage`,
/// collapsed into one discriminant so a single change event covers every
/// URI-keyed registry mutation (matching the `MonaMarkerService` single-event
/// pattern).
public enum MonaModelRegistryChangeKind: Sendable, Equatable {

    /// A model was registered under its URI (createModel/register).
    case registered

    /// A model was removed from the URI map (unregister/dispose).
    case unregistered

    /// A registered model's tracked language id changed (setLanguage).
    case languageChanged
}

/// A change event fired by `MonaGlobalModelRegistry` when a model is
/// registered, unregistered, or has its language changed.
///
/// Carries the id of the affected model so subscribers can re-read registry
/// state for just that model. This is the Swift counterpart of Monaco's model
/// lifecycle events (monaco-editor 0.56.0 `onDidCreateModel` /
/// `onWillDisposeModel` / `onDidChangeModelLanguage`).
public struct MonaModelRegistryChangeEvent: Sendable, Equatable {

    /// The lifecycle transition this event reports.
    public let kind: MonaModelRegistryChangeKind

    /// The id (URI string) of the model whose registry entry changed.
    public let modelId: String

    /// Creates a change event carrying the transition kind and affected model id.
    public init(kind: MonaModelRegistryChangeKind, modelId: String) {
        self.kind = kind
        self.modelId = modelId
    }
}

/// The process-global, URI-keyed model registry — the Swift counterpart of
/// Monaco's standalone `createModel` / `getModel` / `getModels` /
/// `setModelLanguage` surface (monaco-editor 0.56.0).
///
/// Owns a `URI -> MonaCodeModel` map. Monaco's model service is a
/// `registerSingleton` standalone service (S1-R disposition
/// `retained-native-core`): one instance for the whole process, so
/// `MonaGlobalModelRegistry.shared` is the production entry point and the four
/// retained public editor functions route through it.
///
/// - `createModel(value:language:uri:)` constructs a `MonaCodeModel`, registers
///   it under its URI, and returns it (matching Monaco's `editor.createModel`).
/// - `register(_:)` adds a model under its URI; re-registering the same URI
///   replaces, not appends. `unregister(_:)` removes a model and its language
///   override.
/// - `model(for:)` returns the model registered under `uri`, or `nil`
///   (Monaco's `editor.getModel`).
/// - `models()` returns every registered model (Monaco's `editor.getModels`).
/// - `setLanguage(_:for:)` tracks a language override for a registered model
///   (Monaco's `editor.setModelLanguage`); `languageId(for:)` reads it, falling
///   back to the model's own language id.
/// - `onDidChangeModels` is the change event; every mutation fires it once
///   with the kind and affected model id.
///
/// Each mutation fires `onDidChangeModels` synchronously (the underlying
/// `MonaEmitter` is deterministic and reentrancy-safe).
///
/// Thread-safe: `byUri` and `languageOverrides` are guarded by an `NSLock`.
/// `@unchecked Sendable` because the lock is the synchronization boundary — the
/// registry is safe to share across isolation domains, which is its intended
/// use as a process-global singleton (S1-R model service is
/// `registerSingleton`). Change events are fired OUTSIDE the lock so a
/// listener that calls back into the registry cannot deadlock (NSLock is
/// non-reentrant).
public final class MonaGlobalModelRegistry: @unchecked Sendable {

    /// The process-global singleton (S1-R model service is a
    /// `registerSingleton` service).
    public static let shared = MonaGlobalModelRegistry()

    /// Per-URI model storage, keyed by `MonaCodeModel.id` (the URI string).
    private var byUri: [String: MonaCodeModel] = [:]

    /// Per-model language overrides, keyed by `MonaCodeModel.id`. Absent means
    /// "use the model's own language id".
    private var languageOverrides: [String: String] = [:]

    /// The change emitter; fires `MonaModelRegistryChangeEvent` on every
    /// mutation.
    private let changeEmitter = MonaEmitter<MonaModelRegistryChangeEvent>()

    /// Synchronization lock for `byUri` and `languageOverrides`.
    private let lock = NSLock()

    /// Creates a model registry.
    ///
    /// Public so tests can construct isolated instances; production code uses
    /// `MonaGlobalModelRegistry.shared`.
    public init() {}

    /// Creates a text model from `value`, registers it under `uri` (or a
    /// generated URI when `nil`), seeds the optional `language` override, and
    /// returns it. The Swift counterpart of Monaco's `editor.createModel`.
    public func createModel(
        value: String,
        language: String? = nil,
        uri: MonaURI? = nil
    ) -> MonaCodeModel {
        let resolvedUri = uri ?? MonaURI(scheme: "inmemory", path: "/\(UUID().uuidString)")
        let model = MonaCodeModel(text: value, uri: resolvedUri)
        register(model, language: language)
        return model
    }

    /// Registers `model` under its URI, optionally seeding a language override.
    ///
    /// Re-registering the same URI replaces the prior model reference (matching
    /// Monaco's URI-keyed lookup semantics) and does not duplicate the entry.
    /// Fires `onDidChangeModels` with kind `.registered`.
    public func register(_ model: MonaCodeModel, language: String? = nil) {
        lock.lock()
        byUri[model.id] = model
        if let language {
            languageOverrides[model.id] = language
        }
        lock.unlock()
        changeEmitter.fire(
            MonaModelRegistryChangeEvent(kind: .registered, modelId: model.id))
    }

    /// Removes `model` from the URI map and drops its language override. Fires
    /// `onDidChangeModels` with kind `.unregistered`. Idempotent: unregistering
    /// a model that is not registered still fires the event (the registry
    /// observes the transition, not the pre-state).
    public func unregister(_ model: MonaCodeModel) {
        lock.lock()
        byUri.removeValue(forKey: model.id)
        languageOverrides.removeValue(forKey: model.id)
        lock.unlock()
        changeEmitter.fire(
            MonaModelRegistryChangeEvent(kind: .unregistered, modelId: model.id))
    }

    /// Returns the model registered under `uri`, or `nil` when no model is
    /// registered for that URI. The Swift counterpart of Monaco's
    /// `editor.getModel`.
    public func model(for uri: MonaURI) -> MonaCodeModel? {
        let key = (try? uri.toString()) ?? "monacode:model"
        lock.lock()
        defer { lock.unlock() }
        return byUri[key]
    }

    /// Returns every registered model. The Swift counterpart of Monaco's
    /// `editor.getModels`.
    public func models() -> [MonaCodeModel] {
        lock.lock()
        defer { lock.unlock() }
        return Array(byUri.values)
    }

    /// Tracks a language override for a registered `model`. The Swift
    /// counterpart of Monaco's `editor.setModelLanguage`. Fires
    /// `onDidChangeModels` with kind `.languageChanged`. A no-op (no event)
    /// when `model` is not registered — the registry does not track language
    /// for models it does not own.
    public func setLanguage(_ languageId: String, for model: MonaCodeModel) {
        lock.lock()
        guard byUri[model.id] != nil else {
            lock.unlock()
            return
        }
        languageOverrides[model.id] = languageId
        lock.unlock()
        changeEmitter.fire(
            MonaModelRegistryChangeEvent(kind: .languageChanged, modelId: model.id))
    }

    /// The tracked language id for `model`: the override set via
    /// `setLanguage` when present, otherwise the model's own language id.
    public func languageId(for model: MonaCodeModel) -> String {
        lock.lock()
        defer { lock.unlock() }
        return languageOverrides[model.id] ?? model.getLanguageId()
    }

    /// Subscribe to registry-change events. The returned `MonaDisposable`
    /// removes the listener when disposed.
    public var onDidChangeModels: MonaEvent<MonaModelRegistryChangeEvent> {
        return changeEmitter.event
    }
}
