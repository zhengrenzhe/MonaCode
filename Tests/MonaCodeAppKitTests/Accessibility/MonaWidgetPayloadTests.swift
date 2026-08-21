// MonaWidgetPayloadTests.swift
//
// RENDER-007 (Task 2: WIDGET payload) — Behavior test for the view-zone,
// content/overlay/glyph-margin widget, and base mouse-target protocols, plus
// the widget mouse-target controller hit-test surface.
//
// Verifies that `MonaEditorIViewZone`, `MonaEditorIContentWidget`,
// `MonaEditorIOverlayWidget`, `MonaEditorIGlyphMarginWidget`, and
// `MonaEditorIBaseMouseTarget` declare concrete payload members (not
// zero-member shells), and that a concrete conforming widget / target carries
// its `afterLineNumber` / `id` / `type` through the protocol witness.
//
// Also verifies that `MonaWidgetMouseTargetController` exists as a concrete
// `final class` and exposes `getTargetAtClientPoint(_:) -> MonaEditorIBaseMouseTarget?`,
// returning `nil` as the documented placeholder until the driving layer wires
// the hit-test geometry.
//
// This is an exit-only behavior test (Ruling I): it guards against the
// protocols collapsing back to empty `{}` shells by asserting the payload is
// readable through the protocol type — a conformance that lacks the required
// member would not compile, and an empty protocol would offer no payload to
// read. The controller test guards against the hit-test path going missing.

import XCTest
import CoreGraphics
import MonaCode
import MonaCodeAppKit
@testable import MonaCodeAppKit

final class MonaWidgetPayloadTests: XCTestCase {

    // MARK: - IViewZone

    /// A concrete view zone carrying its anchor line number. The `let` stored
    /// property satisfies the protocol's `{ get }` requirement.
    private struct TestViewZone: MonaEditorIViewZone {
        let afterLineNumber: Int
    }

    func testViewZoneCarriesAfterLineNumberThroughProtocol() {
        let zone: MonaEditorIViewZone = TestViewZone(afterLineNumber: 12)

        // The anchor line is readable through the protocol witness.
        XCTAssertEqual(zone.afterLineNumber, 12,
                       "IViewZone: afterLineNumber carries through the protocol")
    }

    func testViewZoneSupportsZeroAnchorForBeforeFirstLine() {
        // 0 places the zone before the first line (monaco contract).
        let zone: MonaEditorIViewZone = TestViewZone(afterLineNumber: 0)
        XCTAssertEqual(zone.afterLineNumber, 0,
                       "IViewZone: afterLineNumber=0 preserves the before-first-line sentinel")
    }

    // MARK: - IContentWidget

    private struct TestContentWidget: MonaEditorIContentWidget {
        let id: String
    }

    func testContentWidgetCarriesIdentifierThroughProtocol() {
        let widget: MonaEditorIContentWidget = TestContentWidget(id: "content.hover.tip")

        XCTAssertEqual(widget.id, "content.hover.tip",
                       "IContentWidget: id carries through the protocol")
    }

    // MARK: - IOverlayWidget

    private struct TestOverlayWidget: MonaEditorIOverlayWidget {
        let id: String
    }

    func testOverlayWidgetCarriesIdentifierThroughProtocol() {
        let widget: MonaEditorIOverlayWidget = TestOverlayWidget(id: "overlay.minimap")

        XCTAssertEqual(widget.id, "overlay.minimap",
                       "IOverlayWidget: id carries through the protocol")
    }

    // MARK: - IGlyphMarginWidget

    private struct TestGlyphMarginWidget: MonaEditorIGlyphMarginWidget {
        let id: String
    }

    func testGlyphMarginWidgetCarriesIdentifierThroughProtocol() {
        let widget: MonaEditorIGlyphMarginWidget = TestGlyphMarginWidget(id: "glyph.breakpoint")

        XCTAssertEqual(widget.id, "glyph.breakpoint",
                       "IGlyphMarginWidget: id carries through the protocol")
    }

    // MARK: - IBaseMouseTarget

    private struct TestBaseMouseTarget: MonaEditorIBaseMouseTarget {
        let type: Int
    }

    func testBaseMouseTargetCarriesTypeDiscriminatorThroughProtocol() {
        // The MouseTargetType discriminator is carried as an Int on the base
        // target (AppKit adaptation of the per-subtype `readonly type`).
        let target: MonaEditorIBaseMouseTarget = TestBaseMouseTarget(type: 7)

        XCTAssertEqual(target.type, 7,
                       "IBaseMouseTarget: type discriminator carries through the protocol")
    }

    // MARK: - MonaWidgetMouseTargetController (RENDER-007 hit-test surface)

    func testControllerExistsAndReturnsNilPlaceholderBeforeDrivingLayerWiring() {
        let controller = MonaWidgetMouseTargetController()

        // The hit-test path is non-empty and returns an optional base target.
        // Until the driving layer (the MonaCodeEditorView hit-test RENDER task)
        // wires the geometry resolution, the controller returns nil as the
        // documented placeholder (RENDER-007 unblock contract).
        let target = controller.getTargetAtClientPoint(CGPoint(x: 42, y: 17))

        XCTAssertNil(target,
                      "MonaWidgetMouseTargetController: returns nil placeholder until the driving layer wires hit-test geometry")
    }
}
