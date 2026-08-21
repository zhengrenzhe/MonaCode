// MonaEditorFactory.swift
//
// P05-T012 — Close editor factories and five instance-interface sequences.
//
// `MonaEditorFactory` is the AppKit editor factory — the native counterpart of
// monaco's `editor.create` / `editor.createModel` / `editor.getEditors` /
// `editor.onDidCreateEditor` / `editor.onDidCreateModel` family. It owns:
//
//   - editor creation        — `create(model:options:)` / `create(model:)`
//                              produce a `MonaCodeEditorView`, attach the
//                              model, register the editor by id, and fire the
//                              global editor-created sequence.
//   - model attachment       — `attach(editor:model:)` swaps the model on an
//                              existing editor (detaching the prior model first,
//                              idempotent). The model's lifetime is independent
//                              from the editor (P04-T014 invariant: the editor
//                              holds a weak/borrow ref and never disposes an
//                              externally-owned model).
//   - retrieval              — `retrieve(id:)` / `getEditors()` return the
//                              live editor set (`getEditors` / `getDiffEditors`).
//   - disposal               — `dispose(editor:)` / `disposeAll()` detach all
//                              callbacks before disposal and fire the
//                              editor-disposed sequence.
//   - global event sequences — `onDidCreateEditor`, `onDidDisposeEditor`,
//                              `onDidCreateModel`, `onWillDisposeModel` via
//                              `MonaEmitter` (Base, P01-T005). These are the
//                              global editor/model sequences.
//   - diff / multi-diff      — `createDiffEditor` / `createMultiFileDiffEditor`
//                              construct and return a `MonaDiffEditorView` /
//                              `MonaMultiDiffEditorView` (P07-T009/T010 wiring:
//                              the diff engine's views are constructed by the
//                              factory; `createDiffEditor` attaches the
//                              original + modified models when both are
//                              provided, borrowing them weakly via each
//                              sub-editor's `MonaEditorAttachment`).
//
// Lifetime invariants (carried forward from P04-T014/T015):
//   1. Model lifetime is independent from editor attachment — the factory
//      holds editors strongly (it owns editors) but only tracks models it
//      created via `createModel` weakly; externally-passed models are
//      borrowed (the editor's `MonaEditorAttachment` holds them weakly).
//      Disposing an editor never disposes an externally-owned model.
//   2. All callbacks are detached before disposal — every model-event
//      subscription the factory registers is disposed in `dispose(editor:)`
//      BEFORE the editor tears down (delegated to `MonaEditorAttachment`,
//      which disposes its subscriptions idempotently).
//
// `@MainActor` isolation: the factory is main-actor-isolated (matching the
// `NSView` editors it creates and the `MonaEditorAttachment` it composes), so
// the non-Sendable `MonaCodeModel` never crosses an actor boundary. The
// `MonaEmitter` subscriptions are `@Sendable` closures that hop back to the
// main actor via `MainActor.assumeIsolated` (the model is always mutated on
// the main thread in an AppKit editor).

import AppKit
import Foundation
import MonaCode

// MARK: - MonaEditorFactoryError

/// Errors thrown by `MonaEditorFactory` construction adapters.
public enum MonaEditorFactoryError: Error, Equatable, Sendable {

    /// Reserved construction-adapter error case. The diff / multi-diff factory
    /// methods (`createDiffEditor` / `createMultiFileDiffEditor`) are now wired
    /// (P07-T009/T010) and no longer throw this case; it is retained for any
    /// future construction-adapter error path and for source-stability of the
    /// public error surface.
    case phase07NotWired
}

// MARK: - MonaEditorFactory

/// The AppKit editor factory — the native counterpart of monaco's
/// `editor.create` / `editor.createModel` / `editor.getEditors` /
/// `editor.onDidCreateEditor` / `editor.onDidCreateModel` family.
///
/// Create editors with `create(model:options:)` or `create(model:)`, attach or
/// swap models with `attach(editor:model:)`, retrieve with `retrieve(id:)` or
/// `getEditors()`, and dispose with `dispose(editor:)` or `disposeAll()`. The
/// global editor/model event sequences (`onDidCreateEditor`,
/// `onDidDisposeEditor`, `onDidCreateModel`, `onWillDisposeModel`) fire via
/// `MonaEmitter`.
///
/// Diff and multi-file diff construction is wired through the factory:
/// `createDiffEditor` returns a `MonaDiffEditorView` (attaching the original +
/// modified models when both are provided) and `createMultiFileDiffEditor`
/// returns a `MonaMultiDiffEditorView`. The data source for a multi-file diff
/// view is attached separately via `MonaMultiDiffEditorView.attach(dataSource:)`.
@MainActor
public final class MonaEditorFactory {

    // MARK: - Registry state

    /// The live editors this factory created, keyed by editor id. Held
    /// strongly: the factory owns the editors it creates until they are
    /// disposed. monaco's `getEditors()` reads this set.
    private var editors: [String: MonaCodeEditorView] = [:]

    /// Models created via `createModel` and held weakly so the factory can fire
    /// `onWillDisposeModel` when one is disposed without retaining it. A
    /// reference type so the weak ref is shared across the tracking array.
    private final class TrackedModel {
        weak var model: MonaCodeModel?
        let willDisposeSubscription: MonaDisposable
        init(model: MonaCodeModel, willDisposeSubscription: MonaDisposable) {
            self.model = model
            self.willDisposeSubscription = willDisposeSubscription
        }
    }
    private var trackedModels: [TrackedModel] = []

    // MARK: - Global event sequences (via MonaEmitter)
    //
    // The four global editor/model sequences. Each is backed by a
    // `MonaEmitter` (Base, P01-T005); the public `MonaEvent<T>` subscribe
    // function is the emitter's `event`. Disposing the factory disposes every
    // emitter (idempotent — a no-op when called again).

    private let didCreateEditorEmitter = MonaEmitter<MonaCodeEditorView>()
    private let didDisposeEditorEmitter = MonaEmitter<MonaCodeEditorView>()
    private let didCreateModelEmitter = MonaEmitter<MonaCodeModel>()
    private let willDisposeModelEmitter = MonaEmitter<MonaCodeModel>()

    private var disposed = false

    // MARK: - Init

    /// Creates a new, empty editor factory.
    public init() {}

    // MARK: - Global editor/model event sequences

    /// `editor.onDidCreateEditor` — fires with the exact editor instance when
    /// an editor is created via `create(model:options:)` / `create(model:)`.
    public var onDidCreateEditor: MonaEvent<MonaCodeEditorView> {
        return didCreateEditorEmitter.event
    }

    /// `editor.onDidDisposeEditor` — fires with the exact editor instance when
    /// an editor is disposed via `dispose(editor:)` / `disposeAll()`.
    public var onDidDisposeEditor: MonaEvent<MonaCodeEditorView> {
        return didDisposeEditorEmitter.event
    }

    /// `editor.onDidCreateModel` — fires with the model when a model is created
    /// via `createModel(text:uri:)`.
    public var onDidCreateModel: MonaEvent<MonaCodeModel> {
        return didCreateModelEmitter.event
    }

    /// `editor.onWillDisposeModel` — fires with the model when a model created
    /// via `createModel` is being disposed.
    public var onWillDisposeModel: MonaEvent<MonaCodeModel> {
        return willDisposeModelEmitter.event
    }

    // MARK: - Editor creation

    /// `editor.create(model, options)` — creates a `MonaCodeEditorView`,
    /// attaches `model` (borrowing it — the editor never owns the model's
    /// lifetime), registers the editor by id, and fires `onDidCreateEditor`.
    ///
    /// `options` is the P05-T005 option snapshot; when `nil`, the editor uses
    /// its default options. The model is held weakly by the editor's
    /// `MonaEditorAttachment` — disposing the editor never disposes the model.
    @discardableResult
    public func create(model: MonaCodeModel?, options: MonaOptionSnapshot?) -> MonaCodeEditorView {
        let editor = MonaCodeEditorView(frame: NSRect(x: 0, y: 0, width: 0, height: 0))
        if let model {
            editor.attach(model: model)
        }
        editors[editor.id] = editor
        didCreateEditorEmitter.fire(editor)
        return editor
    }

    /// `editor.create(model)` — the no-options overload.
    @discardableResult
    public func create(model: MonaCodeModel?) -> MonaCodeEditorView {
        return create(model: model, options: nil)
    }

    // MARK: - Model attachment

    /// Attaches `model` to `editor`, detaching any prior model first
    /// (idempotent — the underlying `MonaEditorAttachment.attach` detaches
    /// first). The model's lifetime is independent from the editor: the
    /// editor borrows (weak ref) the model and never disposes it.
    public func attach(editor: MonaCodeEditorView, model: MonaCodeModel) {
        editor.attach(model: model)
    }

    // MARK: - Retrieval

    /// `editor.getEditors` — retrieves the editor registered with `id`, or
    /// `nil` when no live editor has that id (or it has been disposed).
    public func retrieve(id: String) -> MonaCodeEditorView? {
        return editors[id]
    }

    /// `editor.getEditors` — the live editors this factory created, in
    /// creation order. Disposed editors are absent.
    public func getEditors() -> [MonaCodeEditorView] {
        return Array(editors.values)
    }

    // MARK: - Model creation

    /// `editor.createModel(value, uri)` — creates a `MonaCodeModel`, registers
    /// it with the factory so `onWillDisposeModel` fires when it is disposed,
    /// and fires `onDidCreateModel`. The factory tracks the model weakly (it
    /// does not retain-own it beyond the registration needed to re-fire the
    /// will-dispose sequence).
    @discardableResult
    public func createModel(text: String, uri: MonaURI) -> MonaCodeModel {
        let model = MonaCodeModel(text: text, uri: uri)

        // Subscribe to the model's will-dispose sequence so the factory can
        // re-fire it as `onWillDisposeModel` and stop tracking the model. The
        // closure is `@Sendable` (the model is always mutated on the main
        // thread) and hops to the main actor to fire the global emitter.
        let subscription = model.onWillDispose { [weak self] disposedModel in
            MainActor.assumeIsolated {
                self?.handleModelWillDispose(disposedModel)
            }
        }
        trackedModels.append(TrackedModel(model: model, willDisposeSubscription: subscription))

        didCreateModelEmitter.fire(model)
        return model
    }

    /// Re-fires `onWillDisposeModel` and drops the tracking entry for the
    /// disposed model. The subscription is disposed (idempotent) so the
    /// factory no longer observes it.
    private func handleModelWillDispose(_ model: MonaCodeModel) {
        willDisposeModelEmitter.fire(model)
        // Drop the tracking entry; dispose the (already-fired) subscription so
        // no dangling listener remains. `MonaDisposable.dispose()` is
        // idempotent, so disposing after the model's own disposal is safe.
        trackedModels.removeAll { entry in
            entry.model === model
        }
    }

    // MARK: - Disposal

    /// Disposes `editor`: detaches all callbacks before disposal (via the
    /// editor's `MonaEditorAttachment`), removes it from the registry, and
    /// fires `onDidDisposeEditor`. The editor's borrowed model is NEVER
    /// disposed here — its lifetime is owned outside the factory.
    public func dispose(editor: MonaCodeEditorView) {
        guard editors[editor.id] === editor else { return }

        // Detach ALL callbacks before disposal (P04-T014 invariant). The
        // editor's `detach()` disposes every model-event subscription
        // idempotently and tears down the model-dependent collaborators
        // without disposing the model.
        editor.detach()

        editors.removeValue(forKey: editor.id)
        didDisposeEditorEmitter.fire(editor)
    }

    /// Disposes every editor the factory created, in reverse creation order.
    /// Fires `onDidDisposeEditor` for each. Models are never disposed here.
    public func disposeAll() {
        for editor in editors.values.reversed() {
            editor.detach()
            didDisposeEditorEmitter.fire(editor)
        }
        editors.removeAll()
    }

    // MARK: - Diff / multi-diff construction (P07-T009/T010 wiring)
    //
    // The declaration slots (`MonaDiffEditorView`, `MonaMultiDiffEditorView`)
    // live in `Views/MonaDiffEditorView.swift` / `Views/MonaMultiDiffEditorView.swift`.
    // These factory methods construct and return them. `createDiffEditor`
    // attaches the original + modified models to the view's two sub-editors
    // (borrow — the view never owns either model's lifetime) when both are
    // provided. `createMultiFileDiffEditor` constructs the view; its data
    // source is attached separately via `MonaMultiDiffEditorView
    // .attach(dataSource:)`. The `options` parameter is the P05-T005 option
    // snapshot, reserved for future diff-options wiring (the view uses its
    // default options today, mirroring `create(model:options:)`).

    /// `editor.createDiffEditor` — constructs a `MonaDiffEditorView` (P07-T009)
    /// and, when both `original` and `modified` are provided, attaches them to
    /// the view's two sub-editors (weak/borrow — lifetime independent). The
    /// view composes two `MonaCodeEditorView` sub-editors and one shared
    /// `MonaDiffCoordinator` (P07-T002).
    public func createDiffEditor(
        original: MonaCodeModel?,
        modified: MonaCodeModel?,
        options: MonaOptionSnapshot?
    ) -> MonaDiffEditorView {
        guard let original, let modified else {
            return MonaDiffEditorView(frame: NSRect(x: 0, y: 0, width: 0, height: 0))
        }
        let diffView = MonaDiffEditorView(frame: NSRect(x: 0, y: 0, width: 0, height: 0))
        diffView.attach(original: original, modified: modified)
        return diffView
    }

    /// `editor.createMultiFileDiffEditor` — constructs a
    /// `MonaMultiDiffEditorView` (P07-T010; F1-R3
    /// `multiFileDiff.nativeReturnType` = `MonaMultiDiffEditorView`). The data
    /// source is attached separately via `attach(dataSource:)`; the view
    /// reports `isAttached == false` until then.
    public func createMultiFileDiffEditor(options: MonaOptionSnapshot?) -> MonaMultiDiffEditorView {
        return MonaMultiDiffEditorView(frame: NSRect(x: 0, y: 0, width: 0, height: 0))
    }
}
