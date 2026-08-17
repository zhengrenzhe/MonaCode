// MonaPointerScrollMenuTests.swift
//
// P04-T006 — Project pointer, scroll, and context-menu events through AppKit.
//
// Verifies the three native gateways that translate AppKit mouse / scroll /
// context-menu NSEvents into platform-neutral Core values, resolving targets
// through the geometry barrier (P03-T007) before Core command dispatch:
//
//   - `MonaPointerGateway`   — translates NSEvent mouse events (mouseDown /
//                              mouseUp / mouseMoved / mouseDragged) into a
//                              neutral `MonaPointerEvent`. Translates button
//                              number, click count, modifiers, pressure (force
//                              touch), and viewport→content coordinates through
//                              the geometry barrier.
//   - `MonaScrollGateway`    — translates NSEvent scrollWheel events into a
//                              neutral `MonaScrollEvent`. Translates precise
//                              scrolling deltas (÷40), coarse deltas, scroll
//                              phases (began/changed/ended/cancelled/mayBegin),
//                              momentum phases, magnification (pinch zoom), and
//                              coordinates.
//   - `MonaContextMenuGateway` — builds a native `NSMenu` from the ordered Core
//                              menu model (items, separators, submenus, shortcuts)
//                              and presents it at the resolved position.
//
// The pointer / scroll event value types (`MonaPointerEvent`, `MonaScrollEvent`,
// `MonaPointerButton`, `MonaScrollPhase`) are authored here in `MonaCodeAppKit`
// as the native-boundary projection of the platform-neutral fields; the Core
// `MonaPublicInputEvents` (P04-T007) will project these into public
// native-adapted values. The menu model the gateway consumes is projected as
// `MonaAppMenuModel` here; the Core `MonaMenuModel` (P05-T004) will be adapted
// to it.
//
// macOS button numbering: left=0, right=1, middle=2, others≥3. Modifiers:
// Command→CtrlCmd, Control→WinCtrl, Option→Alt, Shift→Shift (matching the
// keyboard gateway P04-T002). Precise deltas are AppKit points ÷ 40 (the
// Monaco StandardWheel constant); coarse deltas are carried verbatim.

import XCTest
import AppKit
import CoreGraphics
import CoreText
import MonaCode
import MonaCodeAppKit
@testable import MonaCodeAppKit

final class MonaPointerScrollMenuTests: XCTestCase {

    // MARK: - Shared helpers

    /// Menlo is the default macOS monospace face and is always present.
    private let menlo = MonaFontDescriptor(familyName: "Menlo", size: 12)

    /// Builds a barrier over a real model + view graph + scroll model + builder
    /// (mirrors `MonaQueryGeometryBarrierTests.makeBarrier`).
    private func makeBarrier(
        text: String = "abc\ndef",
        lineHeight: Int = 20
    ) -> (MonaQueryGeometryBarrier, MonaCodeModel, MonaViewGraph, MonaScrollModel) {
        let model = MonaCodeModel(text: text, uri: MonaURI.parse("monacode:pointer")!)
        let viewGraph = MonaViewGraph(model: model, lineHeight: lineHeight)
        let scrollModel = MonaScrollModel(
            contentWidth: 400, contentHeight: Double(2 * lineHeight),
            viewportWidth: 400, viewportHeight: Double(lineHeight)
        )
        let resolver = MonaFontFallbackResolver(primary: menlo, fallback: [])
        let shaper = MonaTextShaper(primaryFont: menlo, fallback: resolver, direction: .ltr, scale: 1)
        let builder = MonaLineLayoutBuilder(shaper: shaper)
        let provider: (Int) -> [UInt16] = { lineNum in
            Array(model.getLineContent(lineNum).utf16)
        }
        let barrier = MonaQueryGeometryBarrier(
            viewGraph: viewGraph,
            scrollModel: scrollModel,
            builder: builder,
            lineHeight: lineHeight,
            codeUnitsForModelLine: provider
        )
        return (barrier, model, viewGraph, scrollModel)
    }

    /// Builds a synthetic mouse `NSEvent`.
    private func mouseEvent(
        type: NSEvent.EventType,
        location: CGPoint = CGPoint(x: 10, y: 20),
        modifierFlags: NSEvent.ModifierFlags = [],
        clickCount: Int = 1,
        pressure: Float = 1.0,
        timestamp: TimeInterval = 100.0
    ) -> NSEvent {
        return NSEvent.mouseEvent(
            with: type,
            location: location,
            modifierFlags: modifierFlags,
            timestamp: timestamp,
            windowNumber: 0,
            context: nil,
            eventNumber: 1,
            clickCount: clickCount,
            pressure: pressure
        )!
    }

    // MARK: - MonaPointerButton mapping

    func testPointerButtonMapLeft() {
        XCTAssertEqual(MonaPointerGateway.monaButton(for: 0), .left)
    }

    func testPointerButtonMapRight() {
        XCTAssertEqual(MonaPointerGateway.monaButton(for: 1), .right)
    }

    func testPointerButtonMapMiddle() {
        XCTAssertEqual(MonaPointerGateway.monaButton(for: 2), .middle)
    }

    func testPointerButtonMapOtherButtonNumbers() {
        XCTAssertEqual(MonaPointerGateway.monaButton(for: 3), .other(3))
        XCTAssertEqual(MonaPointerGateway.monaButton(for: 5), .other(5))
        // Negative button numbers are preserved verbatim (defensive).
        XCTAssertEqual(MonaPointerGateway.monaButton(for: -1), .other(-1))
    }

    // MARK: - MonaPointerGateway: modifier mapping

    func testPointerGatewayMapsCommandToCtrlCmd() {
        XCTAssertEqual(MonaPointerGateway.monaModifiers(for: .command), .ctrlCmd)
    }

    func testPointerGatewayMapsControlToWinCtrl() {
        XCTAssertEqual(MonaPointerGateway.monaModifiers(for: .control), .winCtrl)
    }

    func testPointerGatewayMapsOptionToAlt() {
        XCTAssertEqual(MonaPointerGateway.monaModifiers(for: .option), .alt)
    }

    func testPointerGatewayMapsShiftToShift() {
        XCTAssertEqual(MonaPointerGateway.monaModifiers(for: .shift), .shift)
    }

    func testPointerGatewayMapsModifierCombination() {
        let mods = MonaPointerGateway.monaModifiers(for: [.command, .shift, .option, .control])
        XCTAssertTrue(mods.contains(.ctrlCmd))
        XCTAssertTrue(mods.contains(.shift))
        XCTAssertTrue(mods.contains(.alt))
        XCTAssertTrue(mods.contains(.winCtrl))
    }

    // MARK: - MonaPointerGateway: NSEvent → MonaPointerEvent

    func testPointerGatewayTranslatesLeftMouseDown() {
        let gateway = MonaPointerGateway()
        let event = mouseEvent(type: .leftMouseDown, clickCount: 1, pressure: 1.0)
        let translated = gateway.translate(
            event,
            phase: .down,
            viewportPoint: CGPoint(x: 10, y: 20),
            resolvingPositionThrough: nil
        )

        XCTAssertEqual(translated.button, .left)
        XCTAssertEqual(translated.phase, .down)
        XCTAssertEqual(translated.clickCount, 1)
        XCTAssertEqual(translated.pressure, 1.0, accuracy: 1e-9)
        XCTAssertEqual(translated.modifiers, [])
        XCTAssertEqual(translated.viewportPoint, CGPoint(x: 10, y: 20))
        XCTAssertNil(translated.resolvedPosition)
        XCTAssertEqual(translated.timestamp, 100.0, accuracy: 1e-9)
    }

    func testPointerGatewayTranslatesClickCountFromNSEvent() {
        // AppKit clickCount is carried verbatim as input; the Monaco 400 ms /
        // same-position clamp is a Core concern (not this gateway).
        let gateway = MonaPointerGateway()
        let triple = mouseEvent(type: .leftMouseDown, clickCount: 3)
        let translated = gateway.translate(
            triple,
            phase: .down,
            viewportPoint: .zero,
            resolvingPositionThrough: nil
        )
        XCTAssertEqual(translated.clickCount, 3)
    }

    func testPointerGatewayTranslatesPressureFromNSEvent() {
        // Force-touch pressure is carried as a Double in [0, 1].
        let gateway = MonaPointerGateway()
        let event = mouseEvent(type: .leftMouseDown, pressure: 0.625)
        let translated = gateway.translate(
            event,
            phase: .down,
            viewportPoint: .zero,
            resolvingPositionThrough: nil
        )
        XCTAssertEqual(translated.pressure, 0.625, accuracy: 1e-9)
    }

    func testPointerGatewayTranslatesModifiersFromNSEvent() {
        let gateway = MonaPointerGateway()
        let event = mouseEvent(type: .leftMouseDown, modifierFlags: [.command, .shift])
        let translated = gateway.translate(
            event,
            phase: .down,
            viewportPoint: .zero,
            resolvingPositionThrough: nil
        )
        XCTAssertTrue(translated.modifiers.contains(.ctrlCmd))
        XCTAssertTrue(translated.modifiers.contains(.shift))
    }

    func testPointerGatewayTranslatesMouseMovedPhase() {
        let gateway = MonaPointerGateway()
        let event = mouseEvent(type: .mouseMoved, clickCount: 0, pressure: 0.0)
        let translated = gateway.translate(
            event,
            phase: .moved,
            viewportPoint: CGPoint(x: 5, y: 7),
            resolvingPositionThrough: nil
        )
        XCTAssertEqual(translated.phase, .moved)
        XCTAssertEqual(translated.button, .left)
        XCTAssertEqual(translated.clickCount, 0)
        XCTAssertEqual(translated.pressure, 0.0, accuracy: 1e-9)
        XCTAssertEqual(translated.viewportPoint, CGPoint(x: 5, y: 7))
    }

    func testPointerGatewayTranslatesMouseDraggedPhase() {
        let gateway = MonaPointerGateway()
        let event = mouseEvent(type: .leftMouseDragged, modifierFlags: .shift, clickCount: 0)
        let translated = gateway.translate(
            event,
            phase: .dragged,
            viewportPoint: CGPoint(x: 11, y: 21),
            resolvingPositionThrough: nil
        )
        XCTAssertEqual(translated.phase, .dragged)
        XCTAssertEqual(translated.modifiers, .shift)
    }

    func testPointerGatewayTranslationIsStableAcrossRepeatedCalls() {
        // Stateless: two calls with equal inputs produce equal outputs.
        let gateway = MonaPointerGateway()
        let event = mouseEvent(type: .leftMouseDown, clickCount: 2, pressure: 0.5)
        let first = gateway.translate(
            event, phase: .down, viewportPoint: .zero, resolvingPositionThrough: nil)
        let second = gateway.translate(
            event, phase: .down, viewportPoint: .zero, resolvingPositionThrough: nil)
        XCTAssertEqual(first, second)
    }

    // MARK: - MonaPointerGateway: coordinate resolution through the barrier

    func testPointerGatewayWithoutBarrierLeavesPositionUnresolved() {
        let gateway = MonaPointerGateway()
        let event = mouseEvent(type: .leftMouseDown)
        let translated = gateway.translate(
            event, phase: .down, viewportPoint: CGPoint(x: 0, y: 10),
            resolvingPositionThrough: nil)
        XCTAssertNil(translated.resolvedPosition)
    }

    func testPointerGatewayWithUnpublishedBarrierLeavesPositionUnresolved() {
        // A barrier with no complete generation returns .noCompleteGeneration;
        // the gateway carries nil rather than a partial position.
        let gateway = MonaPointerGateway()
        let (barrier, _, _, _) = makeBarrier()
        let event = mouseEvent(type: .leftMouseDown)
        let translated = gateway.translate(
            event, phase: .down, viewportPoint: CGPoint(x: 0, y: 10),
            resolvingPositionThrough: barrier)
        XCTAssertNil(translated.resolvedPosition)
    }

    func testPointerGatewayResolvesPositionThroughPublishedBarrier() {
        // With a complete generation published, the viewport point is resolved
        // to a model position through the geometry barrier before Core dispatch.
        let gateway = MonaPointerGateway()
        let (barrier, _, _, _) = makeBarrier()
        _ = barrier.publishGeneration(visibleViewLines: 1...2)

        let event = mouseEvent(type: .leftMouseDown)
        let translated = gateway.translate(
            event, phase: .down, viewportPoint: CGPoint(x: 0, y: 10),
            resolvingPositionThrough: barrier)

        XCTAssertEqual(translated.resolvedPosition, MonaPosition(line: 1, column: 1))
        // The viewport point is carried alongside the resolved position.
        XCTAssertEqual(translated.viewportPoint, CGPoint(x: 0, y: 10))
    }

    func testPointerGatewayResolvesDistinctViewportPoints() {
        let gateway = MonaPointerGateway()
        let (barrier, _, _, _) = makeBarrier()
        _ = barrier.publishGeneration(visibleViewLines: 1...2)

        let downEvent = mouseEvent(type: .leftMouseDown)
        let onLine1 = gateway.translate(
            downEvent, phase: .down, viewportPoint: CGPoint(x: 0, y: 10),
            resolvingPositionThrough: barrier)
        let onLine2 = gateway.translate(
            downEvent, phase: .down, viewportPoint: CGPoint(x: 0, y: 30),
            resolvingPositionThrough: barrier)

        XCTAssertEqual(onLine1.resolvedPosition, MonaPosition(line: 1, column: 1))
        XCTAssertEqual(onLine2.resolvedPosition, MonaPosition(line: 2, column: 1))
    }

    // MARK: - MonaScrollPhase mapping

    func testScrollPhaseMappingFromNSEventPhase() {
        XCTAssertEqual(MonaScrollGateway.monaPhase(for: []), .none)
        XCTAssertEqual(MonaScrollGateway.monaPhase(for: .began), .began)
        XCTAssertEqual(MonaScrollGateway.monaPhase(for: .changed), .changed)
        XCTAssertEqual(MonaScrollGateway.monaPhase(for: .ended), .ended)
        XCTAssertEqual(MonaScrollGateway.monaPhase(for: .cancelled), .cancelled)
        XCTAssertEqual(MonaScrollGateway.monaPhase(for: .mayBegin), .mayBegin)
    }

    // MARK: - MonaScrollGateway: pure field translation (precise / coarse)

    func testScrollGatewayPreciseDeltaDividedByForty() {
        // Precise deltas (hasPreciseScrollingDeltas=true) are AppKit points ÷ 40
        // (the Monaco StandardWheel constant). 120 px → 3.0.
        let gateway = MonaScrollGateway()
        let event = gateway.translateFields(
            scrollingDeltaX: 0, scrollingDeltaY: 120,
            hasPreciseScrollingDeltas: true,
            phase: [], momentumPhase: [],
            magnification: 0,
            modifiers: [],
            viewportPoint: .zero, timestamp: 1.0,
            resolvingPositionThrough: nil)
        XCTAssertEqual(event.deltaY, 3.0, accuracy: 1e-9)
        XCTAssertEqual(event.deltaX, 0.0, accuracy: 1e-9)
        XCTAssertTrue(event.isPrecise)
    }

    func testScrollGatewayCoarseDeltaCarriedVerbatim() {
        // Coarse deltas (line-based) are carried verbatim — NOT divided.
        let gateway = MonaScrollGateway()
        let event = gateway.translateFields(
            scrollingDeltaX: 0, scrollingDeltaY: 3,
            hasPreciseScrollingDeltas: false,
            phase: [], momentumPhase: [],
            magnification: 0,
            modifiers: [],
            viewportPoint: .zero, timestamp: 1.0,
            resolvingPositionThrough: nil)
        XCTAssertEqual(event.deltaY, 3.0, accuracy: 1e-9)
        XCTAssertFalse(event.isPrecise)
    }

    func testScrollGatewayPreservesDoubleResidual() {
        // Precise deltas preserve the Double residual (no integer rounding here).
        let gateway = MonaScrollGateway()
        let event = gateway.translateFields(
            scrollingDeltaX: 0, scrollingDeltaY: 50,
            hasPreciseScrollingDeltas: true,
            phase: [], momentumPhase: [],
            magnification: 0,
            modifiers: [],
            viewportPoint: .zero, timestamp: 1.0,
            resolvingPositionThrough: nil)
        XCTAssertEqual(event.deltaY, 1.25, accuracy: 1e-9)
    }

    func testScrollGatewayDoesNotReverseAppKitDirection() {
        // AppKit's positive direction already matches Monaco's StandardWheel and
        // is already reversed for natural scrolling; the gateway MUST NOT reverse
        // again. A positive deltaY stays positive.
        let gateway = MonaScrollGateway()
        let event = gateway.translateFields(
            scrollingDeltaX: 0, scrollingDeltaY: 40,
            hasPreciseScrollingDeltas: true,
            phase: [], momentumPhase: [],
            magnification: 0,
            modifiers: [],
            viewportPoint: .zero, timestamp: 1.0,
            resolvingPositionThrough: nil)
        XCTAssertEqual(event.deltaY, 1.0, accuracy: 1e-9)
    }

    // MARK: - MonaScrollGateway: phases, momentum, magnification

    func testScrollGatewayCarriesPhase() {
        let gateway = MonaScrollGateway()
        let began = gateway.translateFields(
            scrollingDeltaX: 0, scrollingDeltaY: 0,
            hasPreciseScrollingDeltas: true,
            phase: .began, momentumPhase: [],
            magnification: 0, modifiers: [],
            viewportPoint: .zero, timestamp: 1.0,
            resolvingPositionThrough: nil)
        XCTAssertEqual(began.phase, .began)

        let changed = gateway.translateFields(
            scrollingDeltaX: 0, scrollingDeltaY: 40,
            hasPreciseScrollingDeltas: true,
            phase: .changed, momentumPhase: [],
            magnification: 0, modifiers: [],
            viewportPoint: .zero, timestamp: 1.0,
            resolvingPositionThrough: nil)
        XCTAssertEqual(changed.phase, .changed)
        XCTAssertEqual(changed.deltaY, 1.0, accuracy: 1e-9)

        let ended = gateway.translateFields(
            scrollingDeltaX: 0, scrollingDeltaY: 0,
            hasPreciseScrollingDeltas: true,
            phase: .ended, momentumPhase: [],
            magnification: 0, modifiers: [],
            viewportPoint: .zero, timestamp: 1.0,
            resolvingPositionThrough: nil)
        XCTAssertEqual(ended.phase, .ended)
    }

    func testScrollGatewayCarriesMomentumPhase() {
        // After the user lifts their fingers, AppKit delivers momentum scroll
        // events with phase=.none and momentumPhase=.began/.changed/.ended.
        let gateway = MonaScrollGateway()
        let momentum = gateway.translateFields(
            scrollingDeltaX: 0, scrollingDeltaY: 80,
            hasPreciseScrollingDeltas: true,
            phase: [], momentumPhase: .changed,
            magnification: 0, modifiers: [],
            viewportPoint: .zero, timestamp: 1.0,
            resolvingPositionThrough: nil)
        XCTAssertEqual(momentum.phase, .none)
        XCTAssertEqual(momentum.momentumPhase, .changed)
        XCTAssertEqual(momentum.deltaY, 2.0, accuracy: 1e-9)
    }

    func testScrollGatewayCarriesMagnification() {
        // Pinch-zoom magnification is carried verbatim as a Double.
        let gateway = MonaScrollGateway()
        let pinch = gateway.translateFields(
            scrollingDeltaX: 0, scrollingDeltaY: 0,
            hasPreciseScrollingDeltas: false,
            phase: .changed, momentumPhase: [],
            magnification: 0.1, modifiers: [],
            viewportPoint: .zero, timestamp: 1.0,
            resolvingPositionThrough: nil)
        XCTAssertEqual(pinch.magnification, 0.1, accuracy: 1e-9)
        XCTAssertEqual(pinch.deltaY, 0.0, accuracy: 1e-9)
    }

    func testScrollGatewayCarriesModifiersAndTimestamp() {
        let gateway = MonaScrollGateway()
        let event = gateway.translateFields(
            scrollingDeltaX: 0, scrollingDeltaY: 3,
            hasPreciseScrollingDeltas: false,
            phase: [], momentumPhase: [],
            magnification: 0,
            modifiers: [.command, .option],
            viewportPoint: CGPoint(x: 5, y: 5), timestamp: 42.0,
            resolvingPositionThrough: nil)
        XCTAssertTrue(event.modifiers.contains(.ctrlCmd))
        XCTAssertTrue(event.modifiers.contains(.alt))
        XCTAssertEqual(event.timestamp, 42.0, accuracy: 1e-9)
        XCTAssertEqual(event.viewportPoint, CGPoint(x: 5, y: 5))
    }

    // MARK: - MonaScrollGateway: NSEvent end-to-end (scrollWheel)

    func testScrollGatewayTranslatesCoarseScrollWheelNSEvent() {
        // A line-based scrollWheel event (coarse) carries its delta verbatim.
        let gateway = MonaScrollGateway()
        guard let cg = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1,
                               wheel1: 3, wheel2: 0, wheel3: 0) else {
            return XCTFail("could not build CGEvent scrollWheel")
        }
        guard let event = NSEvent(cgEvent: cg) else {
            return XCTFail("could not wrap CGEvent as NSEvent")
        }
        let translated = gateway.translate(
            event,
            viewportPoint: CGPoint(x: 5, y: 5),
            resolvingPositionThrough: nil)
        // Coarse: deltaY carried verbatim (3.0), isPrecise=false, no phase.
        XCTAssertEqual(translated.deltaY, 3.0, accuracy: 1e-9)
        XCTAssertFalse(translated.isPrecise)
        XCTAssertEqual(translated.phase, .none)
        XCTAssertEqual(translated.momentumPhase, .none)
        // magnification is 0 for scrollWheel events (reading it would throw).
        XCTAssertEqual(translated.magnification, 0.0, accuracy: 1e-9)
    }

    func testScrollGatewayTranslatesPreciseScrollWheelNSEvent() {
        // A pixel-based scrollWheel event (precise) divides the delta by 40.
        let gateway = MonaScrollGateway()
        guard let cg = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1,
                               wheel1: 120, wheel2: 0, wheel3: 0) else {
            return XCTFail("could not build CGEvent scrollWheel")
        }
        guard let event = NSEvent(cgEvent: cg) else {
            return XCTFail("could not wrap CGEvent as NSEvent")
        }
        let translated = gateway.translate(
            event,
            viewportPoint: .zero,
            resolvingPositionThrough: nil)
        XCTAssertEqual(translated.deltaY, 3.0, accuracy: 1e-9)
        XCTAssertTrue(translated.isPrecise)
    }

    // MARK: - MonaScrollGateway: coordinate resolution

    func testScrollGatewayResolvesPositionThroughBarrier() {
        let gateway = MonaScrollGateway()
        let (barrier, _, _, _) = makeBarrier()
        _ = barrier.publishGeneration(visibleViewLines: 1...2)

        let translated = gateway.translateFields(
            scrollingDeltaX: 0, scrollingDeltaY: 3,
            hasPreciseScrollingDeltas: false,
            phase: [], momentumPhase: [],
            magnification: 0, modifiers: [],
            viewportPoint: CGPoint(x: 0, y: 10), timestamp: 1.0,
            resolvingPositionThrough: barrier)
        XCTAssertEqual(translated.resolvedPosition, MonaPosition(line: 1, column: 1))
    }

    // MARK: - MonaContextMenuGateway: build NSMenu from menu model

    func testContextMenuGatewayBuildsMenuWithActionItems() {
        let gateway = MonaContextMenuGateway()
        let model = MonaAppMenuModel(items: [
            .action(id: "cut", label: "Cut", shortcut: MonaAppMenuShortcut(keyText: "x", modifiers: .ctrlCmd), isEnabled: true, isChecked: false),
            .action(id: "copy", label: "Copy", shortcut: MonaAppMenuShortcut(keyText: "c", modifiers: .ctrlCmd), isEnabled: true, isChecked: false),
            .action(id: "paste", label: "Paste", shortcut: nil, isEnabled: false, isChecked: false)
        ])
        let menu = gateway.buildMenu(from: model)

        XCTAssertEqual(menu.items.count, 3)
        XCTAssertEqual(menu.items[0].title, "Cut")
        XCTAssertEqual(menu.items[1].title, "Copy")
        XCTAssertEqual(menu.items[2].title, "Paste")
        // Enabled state is projected from the model.
        XCTAssertTrue(menu.items[0].isEnabled)
        XCTAssertTrue(menu.items[1].isEnabled)
        XCTAssertFalse(menu.items[2].isEnabled)
    }

    func testContextMenuGatewayBuildsMenuWithSeparators() {
        let gateway = MonaContextMenuGateway()
        let model = MonaAppMenuModel(items: [
            .action(id: "a", label: "A", shortcut: nil, isEnabled: true, isChecked: false),
            .separator,
            .action(id: "b", label: "B", shortcut: nil, isEnabled: true, isChecked: false)
        ])
        let menu = gateway.buildMenu(from: model)

        XCTAssertEqual(menu.items.count, 3)
        XCTAssertTrue(menu.items[1].isSeparatorItem)
        XCTAssertEqual(menu.items[0].title, "A")
        XCTAssertEqual(menu.items[2].title, "B")
    }

    func testContextMenuGatewayBuildsSubmenu() {
        let gateway = MonaContextMenuGateway()
        let model = MonaAppMenuModel(items: [
            .submenu(label: "Format", items: [
                .action(id: "bold", label: "Bold", shortcut: nil, isEnabled: true, isChecked: false),
                .action(id: "italic", label: "Italic", shortcut: nil, isEnabled: true, isChecked: false)
            ], isEnabled: true)
        ])
        let menu = gateway.buildMenu(from: model)

        XCTAssertEqual(menu.items.count, 1)
        let submenuItem = menu.items[0]
        XCTAssertEqual(submenuItem.title, "Format")
        XCTAssertNotNil(submenuItem.submenu)
        XCTAssertEqual(submenuItem.submenu?.items.count, 2)
        XCTAssertEqual(submenuItem.submenu?.items[0].title, "Bold")
        XCTAssertEqual(submenuItem.submenu?.items[1].title, "Italic")
    }

    func testContextMenuGatewayProjectsShortcutsOntoNSMenuItem() {
        // A shortcut's keyText becomes the NSMenuItem keyEquivalent (lowercased)
        // and its modifiers become the keyEquivalentModifierMask.
        let gateway = MonaContextMenuGateway()
        let model = MonaAppMenuModel(items: [
            .action(id: "cut", label: "Cut",
                    shortcut: MonaAppMenuShortcut(keyText: "x", modifiers: .ctrlCmd),
                    isEnabled: true, isChecked: false)
        ])
        let menu = gateway.buildMenu(from: model)

        XCTAssertEqual(menu.items[0].keyEquivalent, "x")
        XCTAssertTrue(menu.items[0].keyEquivalentModifierMask.contains(.command))
    }

    func testContextMenuGatewayProjectsCheckedState() {
        let gateway = MonaContextMenuGateway()
        let model = MonaAppMenuModel(items: [
            .action(id: "wordWrap", label: "Word Wrap", shortcut: nil, isEnabled: true, isChecked: true)
        ])
        let menu = gateway.buildMenu(from: model)
        XCTAssertEqual(menu.items[0].state, .on)
    }

    func testContextMenuGatewayEmptyModelProducesEmptyMenu() {
        let gateway = MonaContextMenuGateway()
        let menu = gateway.buildMenu(from: MonaAppMenuModel(items: []))
        XCTAssertEqual(menu.items.count, 0)
    }

    func testContextMenuGatewayDisabledSubmenuHasNoItems() {
        // A disabled submenu still has its title but the items are present
        // (enabled state is per-item); the submenu item itself is disabled.
        let gateway = MonaContextMenuGateway()
        let model = MonaAppMenuModel(items: [
            .submenu(label: "Format", items: [
                .action(id: "bold", label: "Bold", shortcut: nil, isEnabled: true, isChecked: false)
            ], isEnabled: false)
        ])
        let menu = gateway.buildMenu(from: model)
        XCTAssertEqual(menu.items[0].title, "Format")
        XCTAssertFalse(menu.items[0].isEnabled)
        XCTAssertEqual(menu.items[0].submenu?.items.count, 1)
    }

    // MARK: - MonaContextMenuGateway: present at resolved position

    func testContextMenuGatewayResolvesPresentationPositionThroughBarrier() {
        // `present(menu:at:in:with:)` resolves the model position's caret rect
        // (viewport space) through the barrier and returns the resolved rect.
        // It does NOT pop up the menu (no live window in a unit test); it only
        // proves the geometry path resolves before presentation.
        let gateway = MonaContextMenuGateway()
        let (barrier, _, _, _) = makeBarrier()
        _ = barrier.publishGeneration(visibleViewLines: 1...2)

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Cut", action: nil, keyEquivalent: ""))

        let resolved = gateway.resolvePresentationRect(
            for: MonaPosition(line: 1, column: 1),
            in: nil,
            with: barrier)
        // The caret rect for line 1, column 1 resolves through the barrier
        // (viewport space, no scroll offset → origin.y at the top of line 1).
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.origin.y ?? -1, 0.0, accuracy: 1e-9)
    }

    func testContextMenuGatewayReturnsNilPositionWithoutBarrier() {
        let gateway = MonaContextMenuGateway()
        let resolved = gateway.resolvePresentationRect(
            for: MonaPosition(line: 1, column: 1),
            in: nil,
            with: nil)
        XCTAssertNil(resolved)
    }
}
