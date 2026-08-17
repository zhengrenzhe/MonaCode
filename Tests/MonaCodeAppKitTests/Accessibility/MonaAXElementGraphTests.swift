// MonaAXElementGraphTests.swift
//
// P04-T011 — Implement accessibility controls, proxies, links, diagnostics,
// and actions.
//
// Verifies the AX element graph: the role tree that macOS accessibility clients
// (VoiceOver / the AXUIElement API) traverse. The graph sits on top of the
// native-text surface (P04-T010 `MonaAXTextArea`) and exposes the frozen
// selector / attribute / parameterized-attribute / action sets per role, the
// parent→children relationships, and — critically — stable element identity
// across viewport recycling.
//
// Test contract (P04-T011):
//   1. Instantiate EXACTLY the six required roles — editor, gutter, widget,
//      link, diagnostic, and proxy — no more, no fewer.
//   2. Expose the frozen selector, attribute, parameterized-attribute, and
//      action sets per role.
//   3. Preserve stable element identity across viewport recycling while
//      semantic ownership remains unchanged.

import XCTest
import AppKit
import MonaCode
import MonaCodeAppKit
@testable import MonaCodeAppKit

final class MonaAXElementGraphTests: XCTestCase {

    /// Builds a model from a `String` for the graph under test.
    private func makeModel(_ text: String = "abc\ndef\nghi") -> MonaCodeModel {
        return MonaCodeModel(text: text, uri: MonaURI(scheme: "inmemory", path: "/ax-graph"))
    }

    // MARK: - Operation 1: Instantiate exactly the required roles

    /// The graph instantiates EXACTLY the six required roles — editor, gutter,
    /// widget, link, diagnostic, and proxy — no more, no fewer. The root of the
    /// tree is the editor (text area); the other roles are its descendants.
    func testGraphInstantiatesExactlySixRequiredRoles() {
        let graph = MonaAXElementGraph(model: makeModel())

        // The role set is exactly the six required roles.
        let roles = graph.roles
        XCTAssertEqual(roles.count, 6, "graph must declare exactly six roles")
        XCTAssertEqual(roles, Set(MonaAXRole.allCases))
        XCTAssertTrue(roles.contains(.editor))
        XCTAssertTrue(roles.contains(.gutter))
        XCTAssertTrue(roles.contains(.widget))
        XCTAssertTrue(roles.contains(.link))
        XCTAssertTrue(roles.contains(.diagnostic))
        XCTAssertTrue(roles.contains(.proxy))

        // The root of the tree is the editor role node.
        XCTAssertEqual(graph.root.identity.role, .editor)
        XCTAssertEqual(graph.root.identity.line, nil)

        // Each of the six roles has a stable root element.
        for role in MonaAXRole.allCases {
            let identity = MonaAXElementIdentity(role: role, line: nil)
            XCTAssertNotNil(graph.element(for: identity),
                            "root element for role \(role) must exist")
        }

        // The editor roots the parent→children tree: gutter, widget, and proxy
        // are its direct children (AX clients walk this tree).
        let editorChildren = graph.children(of: MonaAXElementIdentity(role: .editor, line: nil))
        let editorChildRoles = Set(editorChildren.map { $0.identity.role })
        XCTAssertTrue(editorChildRoles.contains(.gutter))
        XCTAssertTrue(editorChildRoles.contains(.widget))
        XCTAssertTrue(editorChildRoles.contains(.proxy))
    }

    // MARK: - Operation 2: Frozen selector / attribute / parameterized-attribute / action sets per role

    /// Each role exposes its frozen selector, attribute, parameterized-attribute,
    /// and action sets. The editor (text area) carries the P04-T010 native-text
    /// selectors and the full parameterized-attribute set; non-text roles carry
    /// their own frozen sets and no parameterized attributes.
    func testEachRoleExposesFrozenSelectorAttributeParameterizedAttributeActionSets() {
        let graph = MonaAXElementGraph(model: makeModel())

        // Editor: text area with native-text selectors + parameterized attrs.
        let editor = graph.descriptor(for: .editor)
        XCTAssertEqual(editor.accessibilityRole, .textArea)
        XCTAssertFalse(editor.selectors.isEmpty)
        XCTAssertTrue(editor.selectors.contains("accessibilityValue"))
        XCTAssertTrue(editor.selectors.contains("accessibilitySelectedTextRange"))
        XCTAssertTrue(editor.selectors.contains("accessibilityVisibleCharacterRange"))
        XCTAssertTrue(editor.selectors.contains("accessibilityAttributedStringForRange:"))
        XCTAssertTrue(editor.selectors.contains("accessibilityRangeForPosition:"))
        XCTAssertTrue(editor.selectors.contains("accessibilityBoundsForRange:"))
        XCTAssertTrue(editor.attributes.contains(.role))
        XCTAssertTrue(editor.attributes.contains(.value))
        XCTAssertTrue(editor.attributes.contains(.children))
        XCTAssertTrue(editor.attributes.contains(.selectedTextRange))
        XCTAssertTrue(editor.attributes.contains(.numberOfCharacters))
        XCTAssertTrue(editor.attributes.contains(.visibleCharacterRange))
        XCTAssertFalse(editor.parameterizedAttributes.isEmpty)
        XCTAssertTrue(editor.parameterizedAttributes.contains(
            NSAccessibility.Attribute(rawValue: "AXBoundsForRangeParameterizedAttribute")))
        XCTAssertTrue(editor.parameterizedAttributes.contains(
            NSAccessibility.Attribute(rawValue: "AXRangeForLineParameterizedAttribute")))
        XCTAssertTrue(editor.parameterizedAttributes.contains(
            NSAccessibility.Attribute(rawValue: "AXRangeForPositionParameterizedAttribute")))
        XCTAssertTrue(editor.parameterizedAttributes.contains(
            NSAccessibility.Attribute(rawValue: "AXAttributedStringForRangeParameterizedAttribute")))
        XCTAssertTrue(editor.actions.contains(.showMenu))

        // Gutter: line-number margin (group), no parameterized attrs.
        let gutter = graph.descriptor(for: .gutter)
        XCTAssertEqual(gutter.accessibilityRole, .group)
        XCTAssertTrue(gutter.attributes.contains(.children))
        XCTAssertTrue(gutter.attributes.contains(.description))
        XCTAssertTrue(gutter.parameterizedAttributes.isEmpty)
        XCTAssertTrue(gutter.actions.contains(.showMenu))

        // Widget: overlay content (group), pressable.
        let widget = graph.descriptor(for: .widget)
        XCTAssertEqual(widget.accessibilityRole, .group)
        XCTAssertTrue(widget.attributes.contains(.children))
        XCTAssertTrue(widget.actions.contains(.press))

        // Link: navigateable link with a URL.
        let link = graph.descriptor(for: .link)
        XCTAssertEqual(link.accessibilityRole, .link)
        XCTAssertTrue(link.attributes.contains(.url))
        XCTAssertTrue(link.attributes.contains(.value))
        XCTAssertTrue(link.actions.contains(.press))

        // Diagnostic: error/warning marker (group with description).
        let diagnostic = graph.descriptor(for: .diagnostic)
        XCTAssertEqual(diagnostic.accessibilityRole, .group)
        XCTAssertTrue(diagnostic.attributes.contains(.description))
        XCTAssertTrue(diagnostic.actions.contains(.showMenu))

        // Proxy: widget stand-in (unknown role), pressable.
        let proxy = graph.descriptor(for: .proxy)
        XCTAssertEqual(proxy.accessibilityRole, .unknown)
        XCTAssertTrue(proxy.attributes.contains(.children))
        XCTAssertTrue(proxy.actions.contains(.press))
    }

    // MARK: - Operation 3: Stable identity across viewport recycling

    /// Viewport recycling must NOT change the identity (stable AX identifier) of
    /// an element whose semantic ownership is unchanged. The AX element instance
    /// (reference identity) for a given semantic role/line survives a recycle:
    /// only its weak backing-view reference is swapped, the element object stays.
    func testStableElementIdentitySurvivesViewportRecycle() {
        let graph = MonaAXElementGraph(model: makeModel())

        // A stable root (proxy) and a line-scoped element (diagnostic on line 2).
        let proxyIdentity = MonaAXElementIdentity(role: .proxy, line: nil)
        let diagnosticIdentity = MonaAXElementIdentity(role: .diagnostic, line: 2)

        guard let beforeProxy = graph.element(for: proxyIdentity) else {
            return XCTFail("proxy element must exist before recycle")
        }
        guard let beforeDiagnostic = graph.element(for: diagnosticIdentity) else {
            return XCTFail("diagnostic element for line 2 must exist before recycle")
        }
        let beforeGeneration = graph.viewportGeneration

        // Simulate viewport recycling: new backing views replace the old ones.
        // The backing objects change; the semantic ownership (role/line) is
        // unchanged, so the element identities must survive.
        graph.recycleViewport(backingViews: [
            proxyIdentity: NSView(),
            diagnosticIdentity: NSView(),
        ])

        guard let afterProxy = graph.element(for: proxyIdentity) else {
            return XCTFail("proxy element must exist after recycle")
        }
        guard let afterDiagnostic = graph.element(for: diagnosticIdentity) else {
            return XCTFail("diagnostic element for line 2 must exist after recycle")
        }

        // Identity preserved: same element instance (reference identity).
        XCTAssertTrue(beforeProxy === afterProxy,
                      "proxy element identity must survive viewport recycle")
        XCTAssertTrue(beforeDiagnostic === afterDiagnostic,
                      "diagnostic element identity must survive viewport recycle")
        // The recycle advanced the viewport generation.
        XCTAssertEqual(graph.viewportGeneration, beforeGeneration + 1)
    }
}
