// MonaMultiDiffEditor.swift
//
// P07-T009 — Deliver diff and multi-diff views, SwiftUI wrappers, and
// sample-host activation.
//
// `MonaMultiDiffEditor` is the SwiftUI→AppKit bridge: a `public struct
// MonaMultiDiffEditor: NSViewRepresentable` that wraps
// `MonaMultiDiffEditorView` (P07-T009). It is the public SwiftUI surface
// (`MonaCodeSwiftUI` product) that SwiftUI consumers use to embed the
// multi-file diff navigator.
//
// It is a THIN, lifecycle-only bridge — all real logic stays in the AppKit
// view + Core (same invariants as P04-T015's `MonaCodeEditor`):
//   - `makeNSView(context:)` creates the `MonaMultiDiffEditorView` ONCE via
//     the controller; SwiftUI re-renders never recreate the view.
//   - `updateNSView(_:context:)` propagates declared data-source changes ONLY
//     — it never re-runs diff semantics or rendering. It delegates entirely to
//     `MonaMultiDiffEditorController` / `MonaMultiDiffEditorView` (P07-T009).
//
// Stable identity: the controller (`MonaMultiDiffEditorController`) is the
// single owner of the data source + view attachment. SwiftUI body
// re-evaluations create new `MonaMultiDiffEditor` struct instances, but each
// holds a REFERENCE to the same controller — so the view + data source
// persist. SwiftUI maps into the controller, not around it.
//
// Usage: the consumer holds the controller stably (e.g. via `@State`) and
// passes it to `MonaMultiDiffEditor`:
//
//   @State private var controller: MonaMultiDiffEditorController
//   var body: some View {
//       MonaMultiDiffEditor(controller: controller)
//   }
//
// `@MainActor` isolation matches P04-T015's convention (the AppKit view +
// data source are main-actor-isolated). The controller owns the data source
// strongly; the view borrows it via the subscription (detach never disposes
// it), so the data source's lifetime is independent from view attachment.

import AppKit
import SwiftUI
import MonaCode
import MonaCodeAppKit

// MARK: - MonaMultiDiffEditorController

/// The explicit controller that owns the multi-diff data source + the
/// `MonaMultiDiffEditorView` attachment with STABLE IDENTITY across SwiftUI
/// body re-evaluations.
///
/// SwiftUI re-renders create new `MonaMultiDiffEditor` struct instances, but
/// those structs hold a REFERENCE to this controller — so the controller (and
/// the view + data source it owns) persists. SwiftUI maps into the controller;
/// it never recreates the multi-diff view or resets the data source.
@MainActor
public final class MonaMultiDiffEditorController {

    // MARK: - Stable identity

    /// A token that is stable for the controller's entire lifetime. SwiftUI
    /// body re-evaluations never change it. Used by the lifecycle tests to
    /// assert that a re-render maps into the SAME controller (not a new one).
    public let identityToken: UUID = UUID()

    // MARK: - Single-owned state

    /// The multi-diff data source the controller owns (strong — single owner).
    /// The view borrows it via the snapshot subscription; detach never disposes
    /// it. Lifetime is independent from view attachment.
    public private(set) var dataSource: MonaMultiDiffDataSource?

    /// The `MonaMultiDiffEditorView` the controller created in
    /// `makeMultiDiffView`. `nil` until first called. Created ONCE; subsequent
    /// calls reuse the SAME instance (stable identity).
    public private(set) var multiDiffView: MonaMultiDiffEditorView?

    // MARK: - Init

    /// Creates a controller owning `dataSource` (strong — single owner). The
    /// view borrows it via the subscription when attached.
    public init(dataSource: MonaMultiDiffDataSource) {
        self.dataSource = dataSource
    }

    // MARK: - makeNSView equivalent

    /// Creates the `MonaMultiDiffEditorView` ONCE and attaches the owned data
    /// source. Idempotent: a no-op returning the existing view when called
    /// again — SwiftUI body re-evaluations must NOT recreate the view.
    public func makeMultiDiffView(frame: NSRect) -> MonaMultiDiffEditorView {
        if let existing = multiDiffView {
            // Stable identity: reuse the SAME view instance across re-renders.
            return existing
        }
        let view = MonaMultiDiffEditorView(frame: frame)
        if let ds = dataSource {
            view.attach(dataSource: ds)
        }
        multiDiffView = view
        return view
    }

    // MARK: - updateNSView equivalent

    /// Applies a declared data-source change to the existing view ONLY. This
    /// is the entire `updateNSView` mapping — it does NOT re-run diff
    /// semantics or rendering.
    ///
    /// When the declared data source is the SAME instance as the owned one, no
    /// re-attach occurs (re-attaching would re-subscribe + re-consume). A
    /// declared DATA-SOURCE change re-attaches IN PLACE: the view instance is
    /// reused, not recreated. The prior data source is never disposed — its
    /// lifetime is independent.
    public func applyDeclaredChanges(dataSource: MonaMultiDiffDataSource) {
        // No-op re-render (same data source): do NOT re-attach — re-attaching
        // would re-subscribe + re-consume the snapshot.
        guard dataSource !== self.dataSource else {
            return
        }

        // Adopt the new data source (single owner — strong ref).
        self.dataSource = dataSource

        // Re-attach IN PLACE: the view instance is reused, not recreated.
        // `MonaMultiDiffEditorView.attach(dataSource:)` detaches the prior
        // subscription first (idempotent) and attaches the new source.
        multiDiffView?.attach(dataSource: dataSource)
    }
}

// MARK: - MonaMultiDiffEditor (SwiftUI → AppKit bridge)

/// The SwiftUI→AppKit bridge wrapping `MonaMultiDiffEditorView` (P07-T009).
///
/// `makeNSView(context:)` creates the AppKit view ONCE via the controller;
/// `updateNSView(_:context:)` propagates declared data-source changes ONLY —
/// never re-running diff semantics or rendering.
///
/// The controller (`MonaMultiDiffEditorController`) is the single owner of
/// the data source + view attachment with stable identity across SwiftUI body
/// re-evaluations. SwiftUI maps into the controller, not around it.
public struct MonaMultiDiffEditor: NSViewRepresentable {

    // MARK: - Declared state

    /// The controller that owns the data source + view attachment (stable
    /// identity).
    public let controller: MonaMultiDiffEditorController

    // MARK: - Init

    /// Creates the SwiftUI multi-diff editor bridge.
    ///
    /// - Parameters:
    ///   - controller: The controller owning the data source + view
    ///     attachment. The consumer must hold this stably (e.g. via `@State`)
    ///     so SwiftUI body re-evaluations map into the SAME controller —
    ///     never recreate it.
    public init(controller: MonaMultiDiffEditorController) {
        self.controller = controller
    }

    // MARK: - NSViewRepresentable

    /// Creates the `MonaMultiDiffEditorView` ONCE via the controller. SwiftUI
    /// calls this once per view identity; subsequent body re-evaluations call
    /// only `updateNSView`, which reuses the SAME view instance.
    public func makeNSView(context: Context) -> MonaMultiDiffEditorView {
        return controller.makeMultiDiffView(frame: .zero)
    }

    /// Propagates declared data-source changes ONLY. Delegates entirely to the
    /// controller, which applies data-source changes (re-attach in place) — it
    /// never re-runs diff semantics or rendering.
    public func updateNSView(_ nsView: MonaMultiDiffEditorView, context: Context) {
        if let ds = controller.dataSource {
            controller.applyDeclaredChanges(dataSource: ds)
        }
    }
}
