// MonaAXDiagnosticElement.swift
//
// P04-T011 — Implement accessibility controls, proxies, links, diagnostics,
// and actions.
//
// `MonaAXDiagnosticElement` is the diagnostic role element — a squiggly-wave /
// marker accessibility element for an error, warning, info, or hint in the text.
// It reports the `group` AX role with an `AXDescription` of the diagnostic
// message and an `AXValue` of its severity.
//
// Stable identity: a diagnostic's identity is keyed on the semantic line it
// marks (`role = .diagnostic`, `line = N`), NOT on the recycled marker view.
// When the viewport recycles the marker's backing view, the diagnostic element
// instance survives (only its weak backing-view reference is swapped), so
// VoiceOver keeps tracking the same diagnostic across scroll-driven recycling.
//
// `MonaCodeAppKit` may `import AppKit`, `import Foundation`, and `import MonaCode`.

import AppKit
import Foundation

/// The severity of a diagnostic marker, as accessibility clients perceive it.
/// Surfaced as the diagnostic element's `AXValue`.
public enum MonaAXDiagnosticSeverity: String, Sendable {

    /// An error marker (red squiggle).
    case error

    /// A warning marker (yellow squiggle).
    case warning

    /// An informational marker (blue squiggle).
    case info

    /// A hint marker (grey squiggle).
    case hint
}

/// The diagnostic role element: a squiggly-wave / marker accessibility element
/// for an error, warning, info, or hint in the text.
///
/// Construct with `init(identity:severity:message:markerRange:)`. The element
/// reports the `group` AX role and the frozen diagnostic descriptor
/// (`.diagnostic`). The diagnostic message is surfaced as `AXDescription`; the
/// severity as `AXValue`. The element's identity is keyed on the semantic line
/// it marks, so it survives viewport recycling of its marker view.
public final class MonaAXDiagnosticElement: MonaAXRoleElement {

    public let identity: MonaAXElementIdentity
    public var descriptor: MonaAXRoleDescriptor { .diagnostic }
    public var accessibilityRole: NSAccessibility.Role { .group }

    /// The diagnostic severity (error / warning / info / hint).
    public var severity: MonaAXDiagnosticSeverity

    /// The diagnostic message, surfaced as `AXDescription`.
    public var message: String

    /// The marker range in UTF-16 units (AX integer range), or `nil` when the
    /// diagnostic is unanchored.
    public var markerRange: NSRange?

    /// Weak backing-view reference (the squiggly-underline marker view). Swapped
    /// on viewport recycle; the element identity is preserved.
    public private(set) weak var backingView: NSView?

    public private(set) var viewportGeneration: Int = 0

    /// Creates a diagnostic element for `identity` with the given `severity`,
    /// `message`, and optional `markerRange`.
    public init(
        identity: MonaAXElementIdentity,
        severity: MonaAXDiagnosticSeverity = .warning,
        message: String = "",
        markerRange: NSRange? = nil
    ) {
        self.identity = identity
        self.severity = severity
        self.message = message
        self.markerRange = markerRange
    }

    public func recycleBacking(to view: NSView?, generation: Int) {
        backingView = view
        viewportGeneration = generation
    }
}
