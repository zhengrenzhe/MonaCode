// MonaAXAnnouncementBridge.swift
//
// P04-T012 — Implement focus modes and the localized announcement bridge.
//
// `MonaAXAnnouncementBridge` is the VoiceOver announcement bridge for the AppKit
// editor. It deduplicates and serializes announcement text — the string
// VoiceOver speaks — WITHOUT any audio or unsupported notification UI. There is
// no `NSSpeechSynthesizer`, no `NSUserNotificationCenter`, no sound: this is
// purely the AX announcement-text surface.
//
// Announcement text is resolved through the explicit N1 localization profile
// (`MonaCodeEnvironmentProfile`), NOT through `Bundle.main.localizedString` or
// the runtime system locale. The profile is the explicit UI message profile from
// `MonaCodeEnvironment` (P00-T007): selected only from an explicit environment
// option, never auto-derived from the runtime locale. The bridge takes the
// profile directly so it cannot accidentally consult the runtime locale.
//
// Resolution follows the N1-R localization manifest lookup semantics
// (monacode-n1r-localization-manifest.json, observableSemantics.lookup):
//   "A string locale entry wins; null or absent locale entries use the English
//    fallback string; absence of both yields a typed missing-message failure."
//
// The announcement message catalog is N1-owned data (manifest acceptance C07:
// "Native controls, accessibility labels, announcements and action titles use
// the selected profile and preserve event ordering"). It is resolved through
// the same `MonaCodeEnvironmentProfile` selection mechanism; the full 2120-key
// N1 message table is generated in the N1-R closure — this bridge carries the
// announcement-specific subset it needs, resolved through the profile.
//
// This bridge sits on top of the AX element graph (P04-T011) and is fed by the
// focus coordinator (P04-T012); the AX mutation gateway (P04-T013) validates
// focus before commit.
//
// `MonaCodeAppKit` may `import AppKit`, `import Foundation`, and `import MonaCode`.

import AppKit
import Foundation
import MonaCode

/// The announcement message keys the bridge resolves through the N1 profile.
///
/// Each key identifies one accessibility announcement (the string VoiceOver
/// speaks for an AX event). The resolved text is profile-specific per the N1
/// lookup semantics.
public enum MonaAXAnnouncementKey: String, Sendable, CaseIterable {

    /// Focus moved to the editor (text area).
    case focusMovedToEditor

    /// Focus moved to an overlay widget.
    case focusMovedToWidget

    /// Focus moved to the accessibility-optimized target.
    case focusMovedToAccessibilityOptimized

    /// Focus moved via keyboard tab navigation.
    case focusMovedToTabFocus

    /// A temporary focus grab was entered.
    case temporaryFocusGrabbed

    /// A temporary focus grab was released (focus restored).
    case temporaryFocusReleased

    /// The text selection changed.
    case selectionChanged
}

/// A typed missing-message failure raised when an announcement key has neither a
/// profile-specific entry nor a default (English) fallback entry.
public enum MonaAXAnnouncementError: Error, Equatable {

    /// The announcement `key` has no resolvable entry for `profile` — no
    /// profile-specific entry and no `"default"` fallback.
    case missingMessage(key: MonaAXAnnouncementKey, profile: MonaCodeEnvironmentProfile)
}

/// The VoiceOver announcement bridge: deduplicates and serializes announcement
/// text, resolving each announcement through the explicit N1 localization
/// profile.
///
/// This is purely the AX announcement-text surface — the string VoiceOver
/// speaks. There is no audio, no `NSSpeechSynthesizer`, no
/// `NSUserNotificationCenter`, no sound.
///
/// Construct with `init(profile:catalog:)` (the catalog defaults to the
/// announcement N1 message table). Enqueue announcements with `enqueue(_:)`,
/// which deduplicates a repeat of the just-announced string and serializes the
/// rest in FIFO order. Drain with `nextAnnouncement()`.
public final class MonaAXAnnouncementBridge {

    /// The explicit N1 localization profile. Announcement text is resolved
    /// through this profile, never the runtime system locale.
    public let profile: MonaCodeEnvironmentProfile

    /// The just-announced string (the last value returned by
    /// `nextAnnouncement()`). Dedup compares against this: a repeat is dropped.
    public private(set) var lastAnnounced: String?

    /// The number of queued (serialized, not yet announced) announcements.
    public var pendingCount: Int { queue.count }

    /// The profile-keyed announcement message catalog. Maps each announcement
    /// key to a table of profile-identifier → string. The `"default"` entry is
    /// the English fallback; profile-specific entries (e.g. `"zh-cn"`) win over
    /// the default.
    private let catalog: [MonaAXAnnouncementKey: [String: String]]

    /// The serialization queue (FIFO). Dedup drops a repeat of `lastAnnounced`
    /// before it reaches the queue.
    private var queue: [String] = []

    /// Creates the bridge for `profile`, optionally with a custom `catalog`
    /// (defaults to the announcement N1 message table, `defaultCatalog`).
    public init(
        profile: MonaCodeEnvironmentProfile,
        catalog: [MonaAXAnnouncementKey: [String: String]] = MonaAXAnnouncementBridge.defaultCatalog
    ) {
        self.profile = profile
        self.catalog = catalog
    }

    // MARK: - Resolution (N1 lookup semantics)

    /// Resolves the announcement text for `key` under the bridge's profile.
    ///
    /// N1 lookup semantics (monacode-n1r-localization-manifest.json,
    /// observableSemantics.lookup):
    ///   1. A profile-specific entry wins.
    ///   2. An absent profile entry falls back to the `"default"` (English) entry.
    ///   3. Absence of both yields `MonaAXAnnouncementError.missingMessage`.
    ///
    /// This never consults `Bundle.main.localizedString` or the runtime system
    /// locale.
    ///
    /// - Throws: `MonaAXAnnouncementError.missingMessage` when `key` has no
    ///   resolvable entry for the profile.
    public func resolve(_ key: MonaAXAnnouncementKey) throws -> String {
        let entries = catalog[key] ?? [:]
        if let specific = entries[profileKey(for: profile)] {
            return specific
        }
        if let fallback = entries["default"] {
            return fallback
        }
        throw MonaAXAnnouncementError.missingMessage(key: key, profile: profile)
    }

    /// The catalog lookup key for `profile` — `"default"` for `.default`, the
    /// custom identifier for `.custom(id)`. This mirrors the N1 profile-
    /// identifier space ("en", "zh-cn", ...); `.default` is the English source
    /// profile.
    private func profileKey(for profile: MonaCodeEnvironmentProfile) -> String {
        switch profile {
        case .default: return "default"
        case .custom(let identifier): return identifier
        }
    }

    // MARK: - Enqueue (dedup + serialize)

    /// Enqueues the announcement for `key`, resolving its text through the N1
    /// profile.
    ///
    /// Dedup: if the resolved text equals `lastAnnounced` (the just-announced
    /// string), the announcement is dropped (not re-queued) and this returns
    /// `false`.
    ///
    /// Serialize: otherwise the text is appended to the FIFO queue and this
    /// returns `true`.
    ///
    /// - Returns: `true` if the announcement was queued; `false` if it was
    ///   deduplicated.
    /// - Throws: `MonaAXAnnouncementError.missingMessage` if `key` has no
    ///   resolvable entry for the profile (no profile-specific and no default).
    @discardableResult
    public func enqueue(_ key: MonaAXAnnouncementKey) throws -> Bool {
        let text = try resolve(key)
        if text == lastAnnounced {
            return false
        }
        queue.append(text)
        return true
    }

    // MARK: - Drain (FIFO)

    /// Pops the next serialized announcement (FIFO order) and records it as
    /// `lastAnnounced`. Returns `nil` when the queue is empty.
    @discardableResult
    public func nextAnnouncement() -> String? {
        guard !queue.isEmpty else { return nil }
        let text = queue.removeFirst()
        lastAnnounced = text
        return text
    }

    // MARK: - Default announcement catalog (N1-owned data, profile-keyed)

    /// The default announcement message table — profile-keyed, following the N1
    /// lookup semantics (profile entry wins; `"default"` is the English
    /// fallback). This is the announcement-specific N1 data surface
    /// (acceptance C07); the full 2120-key N1 message table is generated in the
    /// N1-R closure.
    public static let defaultCatalog: [MonaAXAnnouncementKey: [String: String]] = [
        .focusMovedToEditor: [
            "default": "Editor",
            "zh-cn": "编辑器",
            "ja": "エディター",
        ],
        .focusMovedToWidget: [
            "default": "Widget",
            "zh-cn": "小组件",
        ],
        .focusMovedToAccessibilityOptimized: [
            "default": "Accessibility optimized",
        ],
        .focusMovedToTabFocus: [
            "default": "Tab focus",
        ],
        .temporaryFocusGrabbed: [
            "default": "Temporary focus",
        ],
        .temporaryFocusReleased: [
            "default": "Focus restored",
        ],
        .selectionChanged: [
            "default": "Selection changed",
        ],
    ]
}
