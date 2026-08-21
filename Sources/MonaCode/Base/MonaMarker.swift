// MonaMarker.swift
//
// P01-T004 — Implement key, modifier, token, and marker value types.
//
// This file ports Monaco's marker-related standalone enums and wraps them in a
// `MonaMarker` value type that carries a severity and an optional tag.
//
//   - `MonaMarkerSeverity` — ported verbatim from `monaco.MarkerSeverity`.
//     The raw values keep Monaco's bit-flag layout (Hint = 1, Info = 2,
//     Warning = 4, Error = 8): the gap between Info and Warning is intentional
//     and load-bearing (the values double as bit flags), so the enum is NOT
//     reordered or compressed. `Comparable` orders by severity, giving
//     Error > Warning > Info > Hint.
//   - `MonaMarkerTag`      — ported verbatim from `monaco.MarkerTag`
//     (Unnecessary = 1, Deprecated = 2).
//   - `MonaMarker`         — a value type carrying a `severity`, a `message`,
//     and an optional `tag`. Equality is over all three fields.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The severity of a marker, ported from `monaco.MarkerSeverity`.
///
/// The raw values are Monaco's bit flags (Hint = 1, Info = 2, Warning = 4,
/// Error = 8) — they are NOT reordered or compressed. `Comparable` orders by
/// severity: `Error > Warning > Info > Hint`.
public enum MonaMarkerSeverity: Int, Equatable, Hashable, Sendable, Comparable {

    /// The least severe marker (1).
    case hint = 1

    /// An informational marker (2).
    case info = 2

    /// A warning marker (4).
    case warning = 4

    /// The most severe marker — an error (8).
    case error = 8

    /// The least severity (`hint`).
    public static let min: MonaMarkerSeverity = .hint

    /// The greatest severity (`error`).
    public static let max: MonaMarkerSeverity = .error

    /// Orders by severity: `hint < info < warning < error`.
    public static func < (lhs: MonaMarkerSeverity, rhs: MonaMarkerSeverity) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// A marker tag, ported from `monaco.MarkerTag`.
public enum MonaMarkerTag: Int, Equatable, Hashable, Sendable {

    /// Marks a marker as pointing at unnecessary code (1).
    case unnecessary = 1

    /// Marks a marker as pointing at deprecated code (2).
    case deprecated = 2
}

/// A marker: a severity-bearing diagnostic value.
///
/// Carries the severity, a human-readable `message`, and an optional `tag`.
/// Equality is over all three fields. Severity ordering is provided by
/// `MonaMarkerSeverity`'s `Comparable` conformance.
public struct MonaMarker: Equatable, Hashable, Sendable {

    /// The severity of the marker.
    public let severity: MonaMarkerSeverity

    /// The human-readable marker message.
    public let message: String

    /// An optional marker tag (e.g. `.unnecessary`, `.deprecated`). `nil` when
    /// the marker carries no tag.
    public let tag: MonaMarkerTag?

    /// Creates a marker with a severity, message, and optional tag.
    public init(severity: MonaMarkerSeverity, message: String, tag: MonaMarkerTag? = nil) {
        self.severity = severity
        self.message = message
        self.tag = tag
    }
}

/// A change event fired by `MonaMarkerService` when markers are set or removed.
///
/// Carries the ids of the models whose markers changed so subscribers can
/// re-read markers for the affected models. This is the Swift counterpart of
/// Monaco's `IMarkerService` `onMarkerChanged` event payload.
public struct MonaMarkerChangeEvent: Sendable, Equatable {

    /// The ids of the models whose marker set changed in this mutation.
    public let affectedModelIds: [String]

    /// Creates a change event carrying the affected model ids.
    public init(affectedModelIds: [String]) {
        self.affectedModelIds = affectedModelIds
    }
}

/// The process-global marker service — the Swift counterpart of Monaco's
/// `IMarkerService` / `MarkerService` (monaco-editor 0.56.0).
///
/// Owns markers keyed by `(model id, owner)`. Monaco's marker service is a
/// `registerSingleton` standalone service (S1-R disposition
/// `retained-native-core`): one instance for the whole process, so
/// `MonaMarkerService.shared` is the production entry point.
///
/// - `setModelMarkers(_:for:owner:)` replaces the markers for one
///   `(model, owner)` pair (matching Monaco's `IMarkerService.changeOne`/
///   `editor.setModelMarkers`).
/// - `getModelMarkers(for:)` reads all markers recorded for a model across
///   every owner.
/// - `removeAllMarkers(owner:)` clears by owner (across all models) or, when
///   `owner` is `nil`, clears everything.
/// - `onDidChangeMarkers` is the change event; every mutation fires it once
///   with the affected model ids.
///
/// Each mutation fires `onDidChangeMarkers` synchronously (the underlying
/// `MonaEmitter` is deterministic and reentrancy-safe).
///
/// Thread-safe: `byOwner` is guarded by an `NSLock`. `@unchecked Sendable`
/// because the lock is the synchronization boundary — the service is safe to
/// share across isolation domains, which is its intended use as a
/// process-global singleton (S1-R `IMarkerService` is `registerSingleton`).
/// Change events are fired OUTSIDE the lock so a listener that calls back
/// into the service cannot deadlock (NSLock is non-reentrant).
public final class MonaMarkerService: @unchecked Sendable {

    /// The process-global singleton (S1-R `IMarkerService` is a
    /// `registerSingleton` service).
    public static let shared = MonaMarkerService()

    /// Internal storage key: markers are owned per `(model id, owner)`.
    private struct OwnerKey: Hashable {
        let modelId: String
        let owner: String
    }

    /// Per-`(model, owner)` marker storage.
    private var byOwner: [OwnerKey: [MonaMarker]] = [:]

    /// The change emitter; fires `MonaMarkerChangeEvent` on every mutation.
    private let changeEmitter = MonaEmitter<MonaMarkerChangeEvent>()

    /// Synchronization lock for `byOwner`.
    private let lock = NSLock()

    /// Creates a marker service.
    ///
    /// Public so tests can construct isolated instances; production code uses
    /// `MonaMarkerService.shared`.
    public init() {}

    /// Replaces the markers recorded for `model` under `owner` with `markers`,
    /// then fires `onDidChangeMarkers` carrying `model.id`.
    public func setModelMarkers(
        _ markers: [MonaMarker],
        for model: MonaCodeModel,
        owner: String
    ) {
        let key = OwnerKey(modelId: model.id, owner: owner)
        lock.lock()
        byOwner[key] = markers
        lock.unlock()
        changeEmitter.fire(MonaMarkerChangeEvent(affectedModelIds: [model.id]))
    }

    /// Returns every marker recorded for `model` across all owners.
    public func getModelMarkers(for model: MonaCodeModel) -> [MonaMarker] {
        var result: [MonaMarker] = []
        lock.lock()
        for (key, markers) in byOwner where key.modelId == model.id {
            result.append(contentsOf: markers)
        }
        lock.unlock()
        return result
    }

    /// Removes markers. When `owner` is `nil`, clears every marker for every
    /// model and owner; otherwise clears only the markers recorded under that
    /// owner (across all models). Fires a single `onDidChangeMarkers` event
    /// carrying the affected model ids when anything was removed.
    public func removeAllMarkers(owner: String? = nil) {
        var affected: Set<String> = []
        lock.lock()
        if let owner = owner {
            let keysToRemove = byOwner.keys.filter { $0.owner == owner }
            for key in keysToRemove {
                affected.insert(key.modelId)
                byOwner.removeValue(forKey: key)
            }
        } else {
            for key in byOwner.keys {
                affected.insert(key.modelId)
            }
            byOwner.removeAll()
        }
        lock.unlock()
        if !affected.isEmpty {
            changeEmitter.fire(
                MonaMarkerChangeEvent(affectedModelIds: Array(affected))
            )
        }
    }

    /// Subscribe to marker-change events. The returned `MonaDisposable`
    /// removes the listener when disposed.
    public var onDidChangeMarkers: MonaEvent<MonaMarkerChangeEvent> {
        return changeEmitter.event
    }
}
