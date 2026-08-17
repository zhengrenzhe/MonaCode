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
public final class MonaAXWidgetProxy: MonaAXRoleElement {

    public let identity: MonaAXElementIdentity
    public var descriptor: MonaAXRoleDescriptor { .proxy }
    public var accessibilityRole: NSAccessibility.Role { .unknown }

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
    }

    /// Attaches the proxy to a widget `target` (or detaches with `nil`).
    public func attach(to target: AnyObject?) {
        targetWidget = target
    }

    public func recycleBacking(to view: NSView?, generation: Int) {
        backingView = view
        viewportGeneration = generation
    }
}
