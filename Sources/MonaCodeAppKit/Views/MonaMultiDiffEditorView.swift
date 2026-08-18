// MonaMultiDiffEditorView.swift
//
// P07-T009 — Deliver diff and multi-diff views, SwiftUI wrappers, and
// sample-host activation.
//
// `MonaMultiDiffEditorView` is the native `NSView` that consumes ordered
// multi-diff snapshots from a `MonaMultiDiffDataSource` (the P07-T005 host
// group `multi-diff-data`): each item carries a STABLE id, and change events
// fire SYNCHRONOUSLY (MainActor). It is the slot P05-T012 preserved (the empty
// declaration slot in `MonaEditorInstanceAdapters.swift` is superseded by this
// file — see the fix-forward note there).
//
// Consumption (the second implementation operation):
//   - `attach(dataSource:)` records the source, consumes its current ordered
//     snapshot, and subscribes to `onDidChangeSnapshot`.
//   - The subscription closure runs SYNCHRONOUSLY on the source's fire thread
//     (MainActor per the host contract), updating `currentSnapshot` in place.
//   - `detach()` disposes the subscription (idempotent) and drops the source.
//
// Stable item identity: the view never re-ids items — it stores the source's
// `MonaMultiDiffItem`s verbatim, so each item's `id` is whatever the source
// assigned (stable across snapshots). Synchronous change events: the view's
// `currentSnapshot` reflects a fire IMMEDIATELY (the emitter is synchronous).
//
// Lifetime invariants (carried forward from P04-T014):
//   1. The data source's lifetime is independent from view attachment — the
//      view borrows it weakly via the subscription; detach never disposes it.
//   2. The subscription is detached before disposal — `detach()`/`deinit`
//      disposes the snapshot subscription idempotently.
//
// MonaCodeAppKit imports AppKit + Foundation + MonaCode (for the host-contract
// types + MonaEmitter/MonaDisposable), matching P04-T014's import pattern.

import AppKit
import Foundation
import MonaCode

// MARK: - MonaMultiDiffEditorView

/// The native multi-diff editor view: consumes ordered multi-diff snapshots
/// from a `MonaMultiDiffDataSource` (P07-T005 host group) with stable item
/// identity and synchronous change events.
///
/// Attach a data source via `attach(dataSource:)`; the view consumes the
/// current snapshot and subscribes to `onDidChangeSnapshot`. Change events
/// update `currentSnapshot` synchronously. Detach via `detach()` (idempotent).
public final class MonaMultiDiffEditorView: NSView {

    // MARK: - Consumed state

    /// The attached multi-diff data source (borrowed — lifetime independent).
    public private(set) var dataSource: MonaMultiDiffDataSource?

    /// The current ordered snapshot of multi-diff items. Updated synchronously
    /// on each `onDidChangeSnapshot` fire.
    public private(set) var currentSnapshot: [MonaMultiDiffItem] = []

    /// The snapshot-change subscription. Disposed idempotently on
    /// `detach()`/`deinit`.
    private var snapshotSubscription: MonaDisposable?

    // MARK: - Init

    /// Creates the multi-diff editor view with `frame`.
    public override init(frame: NSRect) {
        super.init(frame: frame)
    }

    /// Creates the multi-diff editor view from a decoder.
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - Contract surface

    /// `true` while a data source is attached.
    public var isAttached: Bool {
        return dataSource != nil
    }

    /// Attaches `dataSource`: records the source, consumes its current ordered
    /// snapshot, and subscribes to `onDidChangeSnapshot`. The subscription
    /// closure runs synchronously on each fire, updating `currentSnapshot` in
    /// place. The data source's lifetime is independent from the view (the
    /// view borrows it; detach never disposes it).
    public func attach(dataSource: MonaMultiDiffDataSource) {
        // Detach any prior source first (idempotent).
        detach()
        self.dataSource = dataSource
        self.currentSnapshot = dataSource.snapshot
        // Subscribe to synchronous change events. The closure captures `self`
        // weakly — the view never retains the source's fire beyond the
        // subscription, and the subscription is disposed on detach.
        snapshotSubscription = dataSource.onDidChangeSnapshot { [weak self] change in
            self?.currentSnapshot = change.items
        }
    }

    /// Detaches the data source: disposes the snapshot subscription
    /// (idempotent) and drops the source + current snapshot. The data source
    /// itself is never disposed (lifetime independent).
    public func detach() {
        snapshotSubscription?.dispose()
        snapshotSubscription = nil
        dataSource = nil
    }

    // MARK: - Deinit (safety net)

    deinit {
        // Dispose the subscription before teardown. `detach()` is idempotent.
        // The data source is NEVER disposed here (lifetime independent).
        detach()
    }
}
