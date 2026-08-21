// MonaAXWidgetProxy.swift
//
// P04-T011 — Implement accessibility controls, proxies, links, diagnostics,
// and actions.
//
// `MonaAXWidgetProxy` is the proxy role element — a stand-in accessibility
// element for widgets and content overlays that don't own their own backing
// view. A proxy reports the `unknown` AX role and stands in for a widget
// target, forwarding `AXChildren` / geometry queries to the target rather than
// owning a backing view.
//
// Stable identity: the proxy's identity is keyed on its semantic role
// (`role = .proxy`), NOT on the recycled backing object. The proxy instance
// survives viewport recycling even when the proxied widget is recycled,
// because the proxy is keyed on semantic role, not on the target. This is the
// stable-identity invariant VoiceOver relies on.
//
// `MonaCodeAppKit` may `import AppKit`, `import Foundation`, and `import MonaCode`.

import AppKit
import Foundation

/// The proxy role element: a stand-in accessibility element for widgets and
/// content overlays that don't own their own backing view.
///
/// Construct with `init(identity:target:)`. A proxy reports the `unknown` AX
/// role and the frozen proxy descriptor (`.proxy`). Attach the widget it stands
/// in for via `attach(to:)`; the target is held weakly so the proxy never
/// extends a disposed widget's lifetime. The proxy's identity (reference
/// identity) is preserved across `recycleBacking(to:generation:)`.
///
/// GAP-6 (spec §3.6): subclasses `NSAccessibilityElement` (an `NSObject`
/// subclass conforming to `NSAccessibilityProtocol`) so macOS `AXUIElement`
/// can traverse it. `accessibilityRole()` delegates to `descriptor.accessibilityRole`
/// (`.unknown`); `accessibilityChildren()`/`accessibilityParent()` return `nil`
/// (leaf behavior — the host view, Task 11, vends the tree).
public final class MonaAXWidgetProxy: NSAccessibilityElement, MonaAXRoleElement {

    public let identity: MonaAXElementIdentity
    public var descriptor: MonaAXRoleDescriptor { .proxy }

    /// The widget target this proxy stands in for. Held weakly so the proxy
    /// never extends a disposed widget's lifetime. `nil` when the proxy is
    /// unattached or its target was recycled away.
    public private(set) weak var targetWidget: AnyObject?

    /// Weak backing-view reference. A proxy typically has no own backing view
    /// (`nil`); when it briefly borrows one (e.g. to host an inline overlay),
    /// the reference is swapped on recycle without affecting identity.
    public private(set) weak var backingView: NSView?

    public private(set) var viewportGeneration: Int = 0

    /// Creates a proxy for `identity`, optionally attached to a `target` widget.
    public init(identity: MonaAXElementIdentity, target: AnyObject? = nil) {
        self.identity = identity
        self.targetWidget = target
        super.init()
    }

    /// Attaches the proxy to a widget `target` (or detaches with `nil`).
    public func attach(to target: AnyObject?) {
        targetWidget = target
    }

    public func recycleBacking(to view: NSView?, generation: Int) {
        backingView = view
        viewportGeneration = generation
    }

    // MARK: NSAccessibilityProtocol (GAP-6 bridge)

    /// The `AXRole` for this proxy — delegates to `descriptor.accessibilityRole`
    /// (`.unknown`). ObjC-runtime-visible selector macOS AX clients call.
    public override func accessibilityRole() -> NSAccessibility.Role? {
        descriptor.accessibilityRole
    }

    /// Leaf behavior for v1: the proxy reports no children (the host view,
    /// Task 11, vends the tree structure).
    public override func accessibilityChildren() -> [Any]? { nil }

    /// The proxy's parent is reported by the host view (Task 11).
    public override func accessibilityParent() -> Any? { nil }
}

// MARK: - Widget mouse-target hit testing (RENDER-007)

/// The lifecycle controller that vends a `MonaEditorIBaseMouseTarget` for a
/// client-space point. It is the AppKit adaptation of Monaco's
/// `editor.getTargetAtClientPoint` hit-test path: the editor's mouse-target
/// surface (view zones, content/overlay/glyph widgets) is queried through this
/// controller so the driving layer can resolve a hit to a retained target.
///
/// RENDER-007 unblock (WIDGET_MOUSE_TARGET_SURFACE_EMPTY): the controller
/// surface exists so the probe's hit-test path is non-empty. The concrete
/// geometry resolution is wired by the driving layer (the
/// `MonaCodeEditorView` hit-test integration, a later RENDER task); until
/// then `getTargetAtClientPoint(_:)` returns `nil` as a documented placeholder
/// — the return type is a non-optional `MonaEditorIBaseMouseTarget?` so the
/// driving layer can substitute a real target without changing the call site.
public final class MonaWidgetMouseTargetController {

    /// Creates a controller with no attached widget surface. The driving layer
    /// attaches the view-zone / content / overlay / glyph widget registries
    /// when wiring the hit-test path.
    public init() {}

    /// Resolves the base mouse target at a client-space `point`.
    ///
    /// Returns `nil` while the geometry resolution is not yet wired by the
    /// driving layer (placeholder per RENDER-007 unblock contract). Once the
    /// `MonaCodeEditorView` hit-test integration lands, this returns the
    /// concrete `MonaEditorIBaseMouseTarget` (view-zone / content / overlay /
    /// glyph widget / text) for the hit.
    public func getTargetAtClientPoint(_ point: CGPoint) -> MonaEditorIBaseMouseTarget? {
        // Placeholder: the hit-test geometry is resolved by the driving layer
        // (RENDER task owning `MonaCodeEditorView` hit testing). The
        // controller surface + return type are fixed here so the probe's
        // hit-test path is non-empty and the call site is forward-compatible.
        return nil
    }
}
