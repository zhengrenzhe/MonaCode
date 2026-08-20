// MonaAXElementGraph.swift
//
// P04-T011 — Implement accessibility controls, proxies, links, diagnostics,
// and actions.
//
// `MonaAXElementGraph` is the accessibility element-graph root + role nodes for
// the AppKit editor — the role tree that macOS accessibility clients (VoiceOver,
// the AXUIElement API) traverse. It sits on top of the native-text surface
// (P04-T010 `MonaAXTextArea`) and feeds the focus coordinator (P04-T012) and
// the AX mutation gateway (P04-T013).
//
// The graph instantiates EXACTLY the six required roles — editor, gutter,
// widget, link, diagnostic, and proxy — no more, no fewer. Each role exposes
// its frozen selector / attribute / parameterized-attribute / action sets (the
// macOS AX capabilities a code editor exposes). The graph owns the parent→
// children relationships AX clients walk.
//
// Stable identity invariant: viewport recycling must NOT change the identity
// (stable AX identifier) of an element whose semantic ownership is unchanged.
// Element identity is keyed on the semantic role/line, NOT on the recycled
// backing view object. When the viewport recycles, only the weak backing-view
// reference is swapped; the element instance (and thus its AX identity)
// survives. This is the contract VoiceOver depends on to keep tracking an
// element across scroll-driven view recycling.
//
// Ownership: the model and geometry barrier are held indirectly (weak) so an AX
// element never extends a disposed model's lifetime — mirroring `MonaAXTextArea`
// (P04-T010). The graph reuses `MonaQueryGeometryBarrier` (P03-T007) for any
// geometry the roles expose, same as P04-T010.
//
// `MonaCodeAppKit` may `import AppKit`, `import Foundation`, and `import MonaCode`.

import AppKit
import Foundation
import MonaCode

// MARK: - MonaAXRole

/// The six accessibility roles the AppKit editor exposes — no more, no fewer.
///
/// A code editor exposes exactly these AX roles: editor (text area), gutter
/// (line-number margin), widget (overlay content), link (navigateable link),
/// diagnostic (error/warning marker), and proxy (widget stand-in). The element
/// graph never instantiates a role outside this set.
public enum MonaAXRole: String, Sendable, CaseIterable {

    /// The text area — the native-text surface (P04-T010 `MonaAXTextArea`).
    case editor

    /// The line-number margin.
    case gutter

    /// Overlay content (hover widgets, suggestions, inline hints).
    case widget

    /// A navigateable link within the text.
    case link

    /// A squiggly-wave error/warning/info/hint marker.
    case diagnostic

    /// A stand-in AX element for widgets/content overlays that don't own their
    /// own backing view.
    case proxy
}

// MARK: - MonaAXRoleDescriptor

/// The frozen selector / attribute / parameterized-attribute / action sets a
/// role exposes to macOS accessibility clients.
///
/// Construct via the static members (`.editor`, `.gutter`, `.widget`, `.link`,
/// `.diagnostic`, `.proxy`). The sets are the capabilities a code editor exposes
/// per role; they are declared once here and never mutated at runtime.
public struct MonaAXRoleDescriptor: Sendable {

    /// The role this descriptor describes.
    public let role: MonaAXRole

    /// The `NSAccessibility.Role` the role reports as its `AXRole`.
    public let accessibilityRole: NSAccessibility.Role

    /// The frozen accessibility-selector set (the native-text selectors the role
    /// responds to, e.g. `"accessibilityValue"`). Non-text roles have an empty
    /// selector set.
    public let selectors: Set<String>

    /// The frozen AX attribute set (e.g. `AXRole`, `AXValue`, `AXChildren`).
    public let attributes: Set<NSAccessibility.Attribute>

    /// The frozen parameterized-attribute set (e.g.
    /// `AXBoundsForRangeParameterizedAttribute`). Only the editor (text area)
    /// exposes parameterized attributes; other roles have an empty set.
    public let parameterizedAttributes: Set<NSAccessibility.Attribute>

    /// The frozen AX action set (e.g. `AXPressAction`, `AXShowMenuAction`).
    public let actions: Set<NSAccessibility.Action>

    private init(
        role: MonaAXRole,
        accessibilityRole: NSAccessibility.Role,
        selectors: Set<String> = [],
        attributes: Set<NSAccessibility.Attribute> = [],
        parameterizedAttributes: Set<NSAccessibility.Attribute> = [],
        actions: Set<NSAccessibility.Action> = []
    ) {
        self.role = role
        self.accessibilityRole = accessibilityRole
        self.selectors = selectors
        self.attributes = attributes
        self.parameterizedAttributes = parameterizedAttributes
        self.actions = actions
    }

    // MARK: - Editor (text area)

    /// The editor role: the native-text surface. Carries the P04-T010
    /// native-text selectors and the full parameterized-attribute set a text
    /// area exposes.
    public static let editor: MonaAXRoleDescriptor = {
        let selectors: Set<String> = [
            "accessibilityValue",
            "accessibilitySelectedText",
            "accessibilitySelectedTextRange",
            "accessibilityNumberOfCharacters",
            "accessibilityVisibleCharacterRange",
            "accessibilityAttributedStringForRange:",
            "accessibilityRangeForPosition:",
            "accessibilityBoundsForRange:",
            "accessibilityPositionForRange:",
            "accessibilityLineForCharacterIndex:",
            "accessibilityRangeForLine:",
        ]
        let attributes: Set<NSAccessibility.Attribute> = [
            .role,
            .value,
            .children,
            .parent,
            NSAccessibility.Attribute(rawValue: "AXFrame"),
            NSAccessibility.Attribute(rawValue: "AXPosition"),
            NSAccessibility.Attribute(rawValue: "AXSize"),
            .enabled,
            .focused,
            .selectedText,
            .selectedTextRange,
            .numberOfCharacters,
            .visibleCharacterRange,
            .sharedFocusElements,
            .focusedWindow,
        ]
        let params: Set<NSAccessibility.Attribute> = [
            NSAccessibility.Attribute(rawValue: "AXBoundsForRangeParameterizedAttribute"),
            NSAccessibility.Attribute(rawValue: "AXRangeForLineParameterizedAttribute"),
            NSAccessibility.Attribute(rawValue: "AXRangeForPositionParameterizedAttribute"),
            NSAccessibility.Attribute(rawValue: "AXStringForRangeParameterizedAttribute"),
            NSAccessibility.Attribute(rawValue: "AXAttributedStringForRangeParameterizedAttribute"),
            NSAccessibility.Attribute(rawValue: "AXRangeForIndexParameterizedAttribute"),
            NSAccessibility.Attribute(rawValue: "AXStyleRangeForIndexParameterizedAttribute"),
        ]
        return MonaAXRoleDescriptor(
            role: .editor,
            accessibilityRole: .textArea,
            selectors: selectors,
            attributes: attributes,
            parameterizedAttributes: params,
            actions: [.showMenu]
        )
    }()

    // MARK: - Gutter (line-number margin)

    /// The gutter role: the line-number margin. A group with no parameterized
    /// attributes and a context-menu action.
    public static let gutter: MonaAXRoleDescriptor = MonaAXRoleDescriptor(
        role: .gutter,
        accessibilityRole: .group,
        selectors: [],
        attributes: [
            .role,
            .children,
            .parent,
            NSAccessibility.Attribute(rawValue: "AXFrame"),
            NSAccessibility.Attribute(rawValue: "AXPosition"),
            NSAccessibility.Attribute(rawValue: "AXSize"),
            .enabled,
            .description,
        ],
        parameterizedAttributes: [],
        actions: [.showMenu]
    )

    // MARK: - Widget (overlay content)

    /// The widget role: overlay content (hover widgets, suggestions, inline
    /// hints). A pressable group.
    public static let widget: MonaAXRoleDescriptor = MonaAXRoleDescriptor(
        role: .widget,
        accessibilityRole: .group,
        selectors: [],
        attributes: [
            .role,
            .children,
            .parent,
            NSAccessibility.Attribute(rawValue: "AXFrame"),
            NSAccessibility.Attribute(rawValue: "AXPosition"),
            NSAccessibility.Attribute(rawValue: "AXSize"),
            .enabled,
            .description,
        ],
        parameterizedAttributes: [],
        actions: [.press, .showMenu]
    )

    // MARK: - Link (navigateable link)

    /// The link role: a navigateable link within the text. Carries a URL and a
    /// press (open) action.
    public static let link: MonaAXRoleDescriptor = MonaAXRoleDescriptor(
        role: .link,
        accessibilityRole: .link,
        selectors: [],
        attributes: [
            .role,
            .value,
            .parent,
            NSAccessibility.Attribute(rawValue: "AXFrame"),
            NSAccessibility.Attribute(rawValue: "AXPosition"),
            NSAccessibility.Attribute(rawValue: "AXSize"),
            .enabled,
            .url,
            .description,
        ],
        parameterizedAttributes: [],
        actions: [.press, .showMenu]
    )

    // MARK: - Diagnostic (error/warning marker)

    /// The diagnostic role: a squiggly-wave marker for an error, warning, info,
    /// or hint. A group with a description and a context-menu (code-action)
    /// action.
    public static let diagnostic: MonaAXRoleDescriptor = MonaAXRoleDescriptor(
        role: .diagnostic,
        accessibilityRole: .group,
        selectors: [],
        attributes: [
            .role,
            .value,
            .parent,
            NSAccessibility.Attribute(rawValue: "AXFrame"),
            NSAccessibility.Attribute(rawValue: "AXPosition"),
            NSAccessibility.Attribute(rawValue: "AXSize"),
            .enabled,
            .description,
        ],
        parameterizedAttributes: [],
        actions: [.showMenu]
    )

    // MARK: - Proxy (widget stand-in)

    /// The proxy role: a stand-in AX element for widgets/content overlays that
    /// don't own their own backing view. Reports the `unknown` AX role and is
    /// pressable.
    public static let proxy: MonaAXRoleDescriptor = MonaAXRoleDescriptor(
        role: .proxy,
        accessibilityRole: .unknown,
        selectors: [],
        attributes: [
            .role,
            .children,
            .parent,
            NSAccessibility.Attribute(rawValue: "AXFrame"),
            NSAccessibility.Attribute(rawValue: "AXPosition"),
            NSAccessibility.Attribute(rawValue: "AXSize"),
            .enabled,
            .description,
        ],
        parameterizedAttributes: [],
        actions: [.press, .showMenu]
    )
}

// MARK: - MonaAXElementIdentity

/// The stable identity of an AX element, keyed on semantic role and (for
/// line-scoped elements) line number — NOT on the recycled backing view object.
///
/// Two elements with the same identity are the same AX element. Viewport
/// recycling preserves identity: the backing view may be replaced, but the
/// element's `(role, line)` identity is unchanged, so the element instance
/// survives. This is the stable-identity invariant VoiceOver relies on across
/// scroll-driven view recycling.
public struct MonaAXElementIdentity: Hashable, Sendable {

    /// The semantic role.
    public let role: MonaAXRole

    /// The 1-based line for line-scoped roles (link, diagnostic); `nil` for
    /// stable roots (editor, gutter, widget, proxy, and the role-level
    /// link/diagnostic placeholders).
    public let line: Int?

    /// Creates an identity keyed on `role` and the optional `line`.
    public init(role: MonaAXRole, line: Int? = nil) {
        self.role = role
        self.line = line
    }
}

// MARK: - MonaAXRoleElement

/// A reference-typed accessibility element bearing a stable identity, a frozen
/// role descriptor, and a recyclable backing-view reference.
///
/// Conforming types are `AnyObject` so identity (reference equality, `===`) is
/// observable — this is what the stable-identity invariant is asserted against.
///
/// GAP-6 (spec §3.6): the concrete element classes (`MonaAXElementNode`,
/// `MonaAXWidgetProxy`, `MonaAXDiagnosticElement`) subclass
/// `NSAccessibilityElement` to gain the ObjC runtime + `NSAccessibilityProtocol`
/// conformance (so macOS `AXUIElement` can traverse them). The element's
/// `AXRole` is therefore reported via the `NSAccessibilityProtocol`
/// `accessibilityRole()` method (returning `NSAccessibility.Role?`), delegating
/// to `descriptor.accessibilityRole` — NOT via a property on this protocol.
/// The non-optional role remains available via `descriptor.accessibilityRole`.
/// This protocol stays `AnyObject`-rooted (a non-NSObject type could still
/// conform); only the concrete classes pick up the AppKit base.
public protocol MonaAXRoleElement: AnyObject {

    /// The stable semantic identity (role / line).
    var identity: MonaAXElementIdentity { get }

    /// The frozen role descriptor (selectors / attributes / parameterized
    /// attributes / actions). The descriptor's `accessibilityRole` is the
    /// non-optional role truth the `NSAccessibilityProtocol` method delegates to.
    var descriptor: MonaAXRoleDescriptor { get }

    /// The weak backing view. Replaced on viewport recycle; `nil` when the
    /// element has no current backing view (e.g. recycled out of view, or a
    /// proxy with no own backing).
    var backingView: NSView? { get }

    /// The viewport generation this element's backing was last recycled at.
    var viewportGeneration: Int { get }

    /// Swaps the backing view and records the recycle generation. The element
    /// instance (identity) is preserved.
    func recycleBacking(to view: NSView?, generation: Int)
}

// MARK: - MonaAXElementNode

/// The generic accessibility element node — used for the editor, gutter,
/// widget, and link roles (the roles without role-specific state). The proxy
/// and diagnostic roles have their own dedicated element types
/// (`MonaAXWidgetProxy`, `MonaAXDiagnosticElement`).
///
/// GAP-6 (spec §3.6): subclasses `NSAccessibilityElement` (an `NSObject`
/// subclass that conforms to `NSAccessibilityProtocol`) so macOS
/// `AXUIElement`/VoiceOver can traverse the element as a first-class
/// accessibility object. The element is a LEAF in the AX tree for v1 —
/// `accessibilityChildren()` returns `nil` and `accessibilityParent()` returns
/// `nil`; the host view (Task 11) vends the tree structure from its own
/// `accessibilityChildren`. The `AXRole` delegates to
/// `descriptor.accessibilityRole` (`.textArea` for the editor node).
public final class MonaAXElementNode: NSAccessibilityElement, MonaAXRoleElement {

    public let identity: MonaAXElementIdentity
    public let descriptor: MonaAXRoleDescriptor

    /// Weak backing-view reference. Replaced on viewport recycle; the element
    /// identity is unaffected.
    public private(set) weak var backingView: NSView?

    public private(set) var viewportGeneration: Int = 0

    public init(identity: MonaAXElementIdentity, descriptor: MonaAXRoleDescriptor) {
        self.identity = identity
        self.descriptor = descriptor
        super.init()
    }

    public func recycleBacking(to view: NSView?, generation: Int) {
        backingView = view
        viewportGeneration = generation
    }

    // MARK: NSAccessibilityProtocol (GAP-6 bridge)

    /// The `AXRole` for this element — delegates to the frozen descriptor
    /// (`.textArea` for editor, `.group` for gutter/widget, `.link` for link).
    /// This is the ObjC-runtime-visible selector macOS AX clients call.
    public override func accessibilityRole() -> NSAccessibility.Role? {
        descriptor.accessibilityRole
    }

    /// Leaf behavior for v1: the element reports no children. The host view
    /// (Task 11) vends the element-tree structure from its own
    /// `accessibilityChildren()`. A future task can add per-node children
    /// (weak graph ref or closure) if VoiceOver needs tree walking.
    public override func accessibilityChildren() -> [Any]? { nil }

    /// The element's parent is reported by the host view (Task 11); the node
    /// itself reports `nil` so it is not its own AX container.
    public override func accessibilityParent() -> Any? { nil }
}

// MARK: - MonaAXElementGraph

/// The accessibility element-graph root: owns the six required role elements,
/// the parent→children relationships AX clients walk, and the viewport-recycle
/// machinery that preserves element identity across backing-view recycling.
public final class MonaAXElementGraph {

    // MARK: - Backing references (indirect, mirroring MonaAXTextArea)

    /// The model supplying raw UTF-16 text truth. Held weakly so the graph never
    /// extends a disposed model's lifetime.
    private weak var model: MonaCodeModel?

    /// The complete-generation geometry barrier (P03-T007). Held weakly; all
    /// geometry the roles expose routes through this barrier, same as P04-T010.
    private weak var geometryBarrier: MonaQueryGeometryBarrier?

    /// Supplies the current viewport size (wired to the live view size by the
    /// AX element graph's host). Used by the native-text surface.
    private let viewportSizeProvider: () -> CGSize?

    /// The native-text accessibility surface (P04-T010) backing the editor role.
    public let textArea: MonaAXTextArea

    // MARK: - Stable root elements (one per role)

    private let editorNode: MonaAXElementNode
    private let gutterNode: MonaAXElementNode
    private let widgetNode: MonaAXElementNode
    private let linkRoot: MonaAXElementNode
    private let diagnosticRoot: MonaAXDiagnosticElement
    private let proxyElement: MonaAXWidgetProxy

    // MARK: - Element + child registries

    private var elementByIdentity: [MonaAXElementIdentity: MonaAXRoleElement] = [:]
    private var childIdentities: [MonaAXElementIdentity: [MonaAXElementIdentity]] = [:]

    /// The viewport generation, advanced on each `recycleViewport`.
    public private(set) var viewportGeneration: Int = 0

    // MARK: - Init

    /// Creates the element graph over `model`, optionally wired to a geometry
    /// barrier and viewport-size provider (mirroring `MonaAXTextArea`).
    public init(
        model: MonaCodeModel,
        geometryBarrier: MonaQueryGeometryBarrier? = nil,
        viewportSize: @escaping () -> CGSize? = { nil }
    ) {
        self.model = model
        self.geometryBarrier = geometryBarrier
        self.viewportSizeProvider = viewportSize
        self.textArea = MonaAXTextArea(
            model: model, geometryBarrier: geometryBarrier, viewportSize: viewportSize
        )

        // Instantiate EXACTLY the six required role roots — no more, no fewer.
        editorNode = MonaAXElementNode(identity: .init(role: .editor), descriptor: .editor)
        gutterNode = MonaAXElementNode(identity: .init(role: .gutter), descriptor: .gutter)
        widgetNode = MonaAXElementNode(identity: .init(role: .widget), descriptor: .widget)
        linkRoot = MonaAXElementNode(identity: .init(role: .link), descriptor: .link)
        diagnosticRoot = MonaAXDiagnosticElement(identity: .init(role: .diagnostic))
        proxyElement = MonaAXWidgetProxy(identity: .init(role: .proxy))

        let roots: [MonaAXRoleElement] = [
            editorNode, gutterNode, widgetNode, linkRoot, diagnosticRoot, proxyElement,
        ]
        for element in roots {
            elementByIdentity[element.identity] = element
        }

        // Parent→children relationships AX clients walk. The editor roots the
        // tree; gutter, widget, and proxy are its direct children. Widget
        // overlays content (link + diagnostic) under the editor subtree.
        childIdentities[MonaAXElementIdentity(role: .editor)] = [
            MonaAXElementIdentity(role: .gutter),
            MonaAXElementIdentity(role: .widget),
            MonaAXElementIdentity(role: .proxy),
        ]
        childIdentities[MonaAXElementIdentity(role: .widget)] = [
            MonaAXElementIdentity(role: .link),
            MonaAXElementIdentity(role: .diagnostic),
        ]
    }

    // MARK: - Role set (exactly six)

    /// The six required roles the graph instantiates — editor, gutter, widget,
    /// link, diagnostic, and proxy. No more, no fewer.
    public var roles: Set<MonaAXRole> { Set(MonaAXRole.allCases) }

    /// The root of the element tree: the editor (text area).
    public var root: MonaAXElementNode { editorNode }

    /// The proxy role element (widget stand-in).
    public var proxy: MonaAXWidgetProxy { proxyElement }

    /// The frozen descriptor for `role`.
    public func descriptor(for role: MonaAXRole) -> MonaAXRoleDescriptor {
        switch role {
        case .editor: return .editor
        case .gutter: return .gutter
        case .widget: return .widget
        case .link: return .link
        case .diagnostic: return .diagnostic
        case .proxy: return .proxy
        }
    }

    // MARK: - Element lookup

    /// Returns the element for `identity`, lazily creating line-scoped link and
    /// diagnostic elements on first access. Root elements (line == nil) always
    /// exist (created at init).
    ///
    /// Identity is keyed on `(role, line)`, NOT on the recycled backing view —
    /// so the same identity always resolves to the same element instance across
    /// viewport recycling.
    public func element(for identity: MonaAXElementIdentity) -> MonaAXRoleElement? {
        if let existing = elementByIdentity[identity] {
            return existing
        }
        // Lazily create line-scoped elements (link / diagnostic) so identity is
        // keyed on (role, line), not on the recycled backing view.
        switch identity.role {
        case .diagnostic:
            guard identity.line != nil else { return nil }
            let element = MonaAXDiagnosticElement(identity: identity)
            elementByIdentity[identity] = element
            return element
        case .link:
            guard identity.line != nil else { return nil }
            let element = MonaAXElementNode(identity: identity, descriptor: .link)
            elementByIdentity[identity] = element
            return element
        case .editor, .gutter, .widget, .proxy:
            return nil
        }
    }

    /// The child elements of the element at `identity`, in tree order.
    public func children(of identity: MonaAXElementIdentity) -> [MonaAXRoleElement] {
        (childIdentities[identity] ?? []).compactMap { elementByIdentity[$0] }
    }

    // MARK: - Viewport recycling (preserves identity)

    /// Recycles the backing views for the given identities, advancing the
    /// viewport generation.
    ///
    /// Element IDENTITY is preserved: the same element instance (reference
    /// identity) for a given `(role, line)` survives — only its weak backing-
    /// view reference is swapped. This is the stable-identity invariant VoiceOver
    /// relies on across scroll-driven view recycling: a recycled backing object
    /// never changes the AX identity of an element whose semantic ownership is
    /// unchanged.
    public func recycleViewport(backingViews: [MonaAXElementIdentity: NSView]) {
        viewportGeneration += 1
        for (identity, view) in backingViews {
            element(for: identity)?.recycleBacking(to: view, generation: viewportGeneration)
        }
    }
}
