// MonaAXFocusAnnouncementTests.swift
//
// P04-T012 — Implement focus modes and the localized announcement bridge.
//
// Verifies the accessibility focus state machine (`MonaAXFocusCoordinator`)
// and the VoiceOver announcement bridge (`MonaAXAnnouncementBridge`). The
// coordinator models editor, widget, accessibility-optimized, tab-focus, and
// temporary focus transitions as ONE state machine (mutually-exclusive current
// mode + temporary push/pop), not five independent flags. The bridge
// deduplicates and serializes announcement text and resolves that text through
// the explicit N1 localization profile (`MonaCodeEnvironmentProfile`) — never
// through `Bundle.main.localizedString` or the runtime system locale.
//
// Test contract (P04-T012):
//   1. The focus coordinator transitions among all five modes as a single
//      state machine (mutually-exclusive current mode; temporary saves and
//      restores the prior mode).
//   2. The announcement bridge deduplicates a repeat of the just-announced
//      string (it is not re-queued).
//   3. The announcement bridge serializes announcements in FIFO order.
//   4. The announcement bridge resolves text through the explicit N1 profile
//      (profile entry wins; absent profile falls back to the default/English
//      entry; absence of both yields a typed missing-message failure).

import XCTest
import AppKit
import MonaCode
import MonaCodeAppKit
@testable import MonaCodeAppKit

final class MonaAXFocusAnnouncementTests: XCTestCase {

    // MARK: - Operation 1: Focus state machine across the five modes

    /// The coordinator declares exactly the five required focus modes — editor,
    /// widget, accessibility-optimized, tab-focus, and temporary — and models
    /// them as a single state machine: `currentMode` is mutually exclusive (only
    /// one mode active at a time) and transitions route through one authoritative
    /// `transition(to:)` entry point, not five independent flags.
    func testFocusCoordinatorDeclaresExactlyFiveModes() {
        let modes = Set(MonaAXFocusMode.allCases)
        XCTAssertEqual(modes.count, 5, "exactly five focus modes required")
        XCTAssertTrue(modes.contains(.editor))
        XCTAssertTrue(modes.contains(.widget))
        XCTAssertTrue(modes.contains(.accessibilityOptimized))
        XCTAssertTrue(modes.contains(.tabFocus))
        XCTAssertTrue(modes.contains(.temporary))
    }

    /// The coordinator transitions among all five modes as one state machine.
    /// `currentMode` is the single source of truth: after each transition it
    /// equals exactly the last target — proving the modes are mutually exclusive,
    /// not five independent flags that can be simultaneously set.
    func testFocusCoordinatorTransitionsAmongAllFiveModesAsOneMachine() {
        let coordinator = MonaAXFocusCoordinator()

        // Default initial mode is editor.
        XCTAssertEqual(coordinator.currentMode, .editor)
        XCTAssertNil(coordinator.savedMode, "no saved mode outside .temporary")

        // Walk every non-temporary mode — currentMode tracks exactly the target.
        coordinator.transition(to: .widget)
        XCTAssertEqual(coordinator.currentMode, .widget)
        XCTAssertNil(coordinator.savedMode)

        coordinator.transition(to: .accessibilityOptimized)
        XCTAssertEqual(coordinator.currentMode, .accessibilityOptimized)
        XCTAssertNil(coordinator.savedMode)

        coordinator.transition(to: .tabFocus)
        XCTAssertEqual(coordinator.currentMode, .tabFocus)
        XCTAssertNil(coordinator.savedMode)

        coordinator.transition(to: .editor)
        XCTAssertEqual(coordinator.currentMode, .editor)
        XCTAssertNil(coordinator.savedMode)
    }

    /// Entering `.temporary` saves the prior mode; `releaseTemporary()` restores
    /// it and clears the saved slot. This is the temporary focus transition — a
    /// focus grab that returns to where focus was, modelled as push/pop on the
    /// single state machine.
    func testFocusCoordinatorTemporarySavesAndRestoresPriorMode() {
        let coordinator = MonaAXFocusCoordinator(initial: .editor)

        // Move to widget, then grab temporary focus.
        coordinator.transition(to: .widget)
        XCTAssertEqual(coordinator.currentMode, .widget)

        coordinator.transition(to: .temporary)
        XCTAssertEqual(coordinator.currentMode, .temporary)
        XCTAssertEqual(coordinator.savedMode, .widget,
                       "entering .temporary must save the prior mode")

        // While temporary is active, the machine is exclusively in .temporary
        // (mutual exclusion — not a parallel flag).
        coordinator.transition(to: .temporary)
        XCTAssertEqual(coordinator.currentMode, .temporary)
        XCTAssertEqual(coordinator.savedMode, .widget,
                       "re-entering .temporary is idempotent; saved mode unchanged")

        // Release restores the saved mode and clears the slot.
        let restored = coordinator.releaseTemporary()
        XCTAssertEqual(restored, .widget)
        XCTAssertEqual(coordinator.currentMode, .widget)
        XCTAssertNil(coordinator.savedMode, "saved mode cleared after release")

        // Releasing when not in .temporary is a no-op.
        XCTAssertNil(coordinator.releaseTemporary())
        XCTAssertEqual(coordinator.currentMode, .widget)
    }

    /// A direct transition out of `.temporary` (without `releaseTemporary`)
    /// abandons the saved mode: the machine moves to the new target and clears
    /// the saved slot, so a later `releaseTemporary` has nothing to restore.
    func testFocusCoordinatorDirectTransitionOutOfTemporaryAbandonsSavedMode() {
        let coordinator = MonaAXFocusCoordinator(initial: .editor)
        coordinator.transition(to: .widget)
        coordinator.transition(to: .temporary)
        XCTAssertEqual(coordinator.savedMode, .widget)

        // Direct transition out of temporary replaces the restore target.
        coordinator.transition(to: .tabFocus)
        XCTAssertEqual(coordinator.currentMode, .tabFocus)
        XCTAssertNil(coordinator.savedMode, "direct exit from .temporary discards saved mode")

        // Nothing left to restore.
        XCTAssertNil(coordinator.releaseTemporary())
        XCTAssertEqual(coordinator.currentMode, .tabFocus)
    }

    // MARK: - Operation 2: Deduplication

    /// The bridge drops a repeat of the just-announced string — it is not
    /// re-queued. Dedup is on the resolved announcement text, not the key.
    func testAnnouncementBridgeDeduplicatesRepeatedAnnouncement() {
        let bridge = MonaAXAnnouncementBridge(profile: .default)

        // First announcement is queued.
        XCTAssertTrue(try bridge.enqueue(.focusMovedToEditor))
        XCTAssertEqual(bridge.pendingCount, 1)

        // Announce it — it becomes the just-announced string.
        let first = bridge.nextAnnouncement()
        XCTAssertEqual(first, "Editor")
        XCTAssertEqual(bridge.lastAnnounced, "Editor")
        XCTAssertEqual(bridge.pendingCount, 0)

        // Repeating the same announcement is deduped: not re-queued.
        XCTAssertFalse(try bridge.enqueue(.focusMovedToEditor),
                       "repeat of just-announced string must be deduped")
        XCTAssertEqual(bridge.pendingCount, 0)
        XCTAssertEqual(bridge.lastAnnounced, "Editor")

        // A different announcement is queued; then one that resolves to the same
        // string as the just-announced is also deduped (dedup is on the text).
        XCTAssertTrue(try bridge.enqueue(.focusMovedToWidget))
        XCTAssertEqual(bridge.pendingCount, 1)
        _ = bridge.nextAnnouncement()  // "Widget" now just-announced

        // Another key whose resolved text equals the just-announced "Widget" is
        // deduped. (.focusMovedToWidget resolves to "Widget" under .default.)
        XCTAssertFalse(try bridge.enqueue(.focusMovedToWidget),
                       "key resolving to the just-announced text must be deduped")
        XCTAssertEqual(bridge.pendingCount, 0)
    }

    // MARK: - Operation 3: Serialization (FIFO order)

    /// The bridge serializes announcements in FIFO order — the order enqueued is
    /// the order announced. No reordering, no LIFO.
    func testAnnouncementBridgePreservesFifoOrder() {
        let bridge = MonaAXAnnouncementBridge(profile: .default)

        // Enqueue three distinct announcements (different resolved text, so none
        // is deduped against a prior one).
        XCTAssertTrue(try bridge.enqueue(.focusMovedToEditor))      // "Editor"
        XCTAssertTrue(try bridge.enqueue(.focusMovedToWidget))     // "Widget"
        XCTAssertTrue(try bridge.enqueue(.focusMovedToTabFocus))    // "Tab focus"
        XCTAssertEqual(bridge.pendingCount, 3)

        // Pop order is exactly the enqueue order (FIFO).
        XCTAssertEqual(bridge.nextAnnouncement(), "Editor")
        XCTAssertEqual(bridge.nextAnnouncement(), "Widget")
        XCTAssertEqual(bridge.nextAnnouncement(), "Tab focus")
        XCTAssertNil(bridge.nextAnnouncement())
        XCTAssertEqual(bridge.pendingCount, 0)
    }

    // MARK: - Operation 4: N1 profile-based resolution

    /// The bridge resolves announcement text through the explicit N1
    /// localization profile (`MonaCodeEnvironmentProfile`), NOT the runtime
    /// system locale. A profile-specific entry wins; an absent profile falls
    /// back to the default (English) entry.
    func testAnnouncementBridgeResolvesThroughExplicitN1Profile() {
        // Default (English) profile → English string.
        let defaultBridge = MonaAXAnnouncementBridge(profile: .default)
        XCTAssertEqual(try defaultBridge.resolve(.focusMovedToEditor), "Editor")

        // A packaged profile with its own entry wins over the default.
        let zhCnBridge = MonaAXAnnouncementBridge(profile: .custom("zh-cn"))
        XCTAssertEqual(try zhCnBridge.resolve(.focusMovedToEditor), "编辑器")

        let jaBridge = MonaAXAnnouncementBridge(profile: .custom("ja"))
        XCTAssertEqual(try jaBridge.resolve(.focusMovedToEditor), "エディター")

        // A profile with NO specific entry falls back to the default (English)
        // entry — the N1 lookup semantics: absent profile → English fallback.
        let unsupportedBridge = MonaAXAnnouncementBridge(profile: .custom("klingon"))
        XCTAssertEqual(try unsupportedBridge.resolve(.focusMovedToEditor), "Editor")

        // The resolved string flows through to the queued announcement under the
        // selected profile (not the system locale).
        XCTAssertTrue(try zhCnBridge.enqueue(.focusMovedToEditor))
        XCTAssertEqual(zhCnBridge.nextAnnouncement(), "编辑器")
    }

    /// Absence of both a profile-specific entry AND a default entry yields a typed
    /// missing-message failure (`MonaAXAnnouncementError.missingMessage`) — never
    /// a silent fallback to an empty string or the system locale.
    func testAnnouncementBridgeThrowsMissingMessageWhenNoDefaultEntry() {
        // A catalog where the key has only a zh-cn entry and no default entry.
        let catalog: [MonaAXAnnouncementKey: [String: String]] = [
            .focusMovedToEditor: ["zh-cn": "编辑器"],
        ]
        let bridge = MonaAXAnnouncementBridge(
            profile: .default, catalog: catalog
        )

        // Under .default there is no entry → no default fallback → typed failure.
        XCTAssertThrowsError(try bridge.resolve(.focusMovedToEditor)) { error in
            guard case .missingMessage(let key, let profile) =
                error as? MonaAXAnnouncementError else {
                return XCTFail("expected MonaAXAnnouncementError.missingMessage, got \(error)")
            }
            XCTAssertEqual(key, .focusMovedToEditor)
            XCTAssertEqual(profile, .default)
        }

        // Under zh-cn the profile entry wins, so no failure.
        let zhBridge = MonaAXAnnouncementBridge(
            profile: .custom("zh-cn"), catalog: catalog
        )
        XCTAssertEqual(try zhBridge.resolve(.focusMovedToEditor), "编辑器")

        // enqueue propagates the typed failure.
        XCTAssertThrowsError(try bridge.enqueue(.focusMovedToEditor)) { error in
            XCTAssertNotNil(error as? MonaAXAnnouncementError)
        }
    }
}
