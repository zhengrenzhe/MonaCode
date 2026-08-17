// MonaCodeEditor.swift
//
// P04-T015 — Deliver MonaCodeEditor and MonaSwiftUIEditorController lifecycle wrappers.
//
// `MonaCodeEditor` is the SwiftUI→AppKit bridge: a `public struct
// MonaCodeEditor: NSViewRepresentable` that wraps `MonaCodeEditorView` (P04-T014).
// It is the public SwiftUI surface (`MonaCodeSwiftUI` product) that SwiftUI
// consumers use to embed the editor.
//
// It is a THIN bridge — all real logic stays in the AppKit view + Core:
//   - `makeNSView(context:)` creates the `MonaCodeEditorView` ONCE via the
//     controller; SwiftUI re-renders never recreate the view.
//   - `updateNSView(_:context:)` propagates declared option/model/focus changes
//     ONLY — it never re-runs text semantics, rendering, input, or provider
//     logic. It delegates entirely to `MonaSwiftUIEditorController` /
//     `MonaCodeEditorView` / `MonaEditorAttachment` (P04-T014).
//
// Stable identity: the controller (`MonaSwiftUIEditorController`) is the single
// owner of the model + view attachment. SwiftUI body re-evaluations create new
// `MonaCodeEditor` struct instances, but each holds a REFERENCE to the same
// controller — so the view + model persist. SwiftUI maps into the controller,
// not around it.
//
// Usage: the consumer holds the controller stably (e.g. via `@State`) and passes
// it to `MonaCodeEditor` along with declared option/focus state:
//
//   @State private var controller = MonaSwiftUIEditorController(model: model)
//   var body: some View {
//       MonaCodeEditor(controller: controller,
//                       options: .defaults,
//                       focusRequest: .none)
//   }
//
// `@MainActor` isolation matches P04-T014's convention (the AppKit view + model
// are main-actor-isolated). The declared-state value types
// (`MonaCodeEditorOptions`, `MonaCodeEditorFocusRequest`) are `Equatable` so
// SwiftUI can diff them and call `updateNSView` only when they change.

import AppKit
import SwiftUI
import MonaCode
import MonaCodeAppKit

// MARK: - Declared-state value types

/// A snapshot of declared editor options (e.g. font/theme). The wrapper records
/// this snapshot and delegates application to the AppKit view — it runs no
/// rendering/semantics logic itself.
public struct MonaCodeEditorOptions: Equatable, Sendable {
    public let fontName: String
    public let fontSize: Int
    public let themeName: String

    public init(fontName: String, fontSize: Int, themeName: String) {
        self.fontName = fontName
        self.fontSize = fontSize
        self.themeName = themeName
    }

    /// The default declared options (Menlo 12, light theme).
    public static let defaults = MonaCodeEditorOptions(
        fontName: "Menlo",
        fontSize: 12,
        themeName: "light"
    )
}

/// A declared focus request. The wrapper records this and delegates focus
/// application to the AppKit view's accessibility surface (P04-T012); it runs
/// no focus logic itself.
public enum MonaCodeEditorFocusRequest: Equatable, Sendable {
    case none
    case focus
    case unfocus
}

// MARK: - MonaCodeEditor (SwiftUI → AppKit bridge)

/// The SwiftUI→AppKit bridge wrapping `MonaCodeEditorView` (P04-T014).
///
/// `makeNSView(context:)` creates the AppKit view ONCE via the controller;
/// `updateNSView(_:context:)` propagates declared option/model/focus changes
/// ONLY — never re-running text semantics, rendering, input, or provider logic.
///
/// The controller (`MonaSwiftUIEditorController`) is the single owner of the
/// model + view attachment with stable identity across SwiftUI body
/// re-evaluations. SwiftUI maps into the controller, not around it.
public struct MonaCodeEditor: NSViewRepresentable {

    // MARK: - Declared state
    //
    // The SwiftUI snapshot. A body re-evaluation that changes any of these
    // triggers `updateNSView`, which maps into the controller. These are the
    // ONLY stored properties — the wrapper owns no logic-bearing collaborators
    // (no renderer, input barrier, provider executor, or command handler).

    /// The controller that owns the model + view attachment (stable identity).
    public let controller: MonaSwiftUIEditorController

    /// The declared editor-options snapshot.
    public let options: MonaCodeEditorOptions

    /// The declared focus request.
    public let focusRequest: MonaCodeEditorFocusRequest

    // MARK: - Init

    /// Creates the SwiftUI editor bridge.
    ///
    /// - Parameters:
    ///   - controller: The controller owning the model + view attachment. The
    ///     consumer must hold this stably (e.g. via `@State`) so SwiftUI body
    ///     re-evaluations map into the SAME controller — never recreate it.
    ///   - options: The declared editor-options snapshot.
    ///   - focusRequest: The declared focus request.
    public init(
        controller: MonaSwiftUIEditorController,
        options: MonaCodeEditorOptions = .defaults,
        focusRequest: MonaCodeEditorFocusRequest = .none
    ) {
        self.controller = controller
        self.options = options
        self.focusRequest = focusRequest
    }

    // MARK: - NSViewRepresentable

    /// Creates the `MonaCodeEditorView` ONCE via the controller. SwiftUI calls
    /// this once per view identity; subsequent body re-evaluations call only
    /// `updateNSView`, which reuses the SAME view instance.
    public func makeNSView(context: Context) -> MonaCodeEditorView {
        // The controller is the single owner: it creates the view once and
        // attaches the model. The view borrows the model weakly (P04-T014).
        return controller.makeEditorView(frame: .zero)
    }

    /// Propagates declared option/model/focus changes ONLY. Delegates entirely
    /// to the controller, which applies model changes (re-attach in place) and
    /// records the options/focus snapshot — it never re-runs text semantics,
    /// rendering, input, or provider logic.
    public func updateNSView(_ nsView: MonaCodeEditorView, context: Context) {
        controller.applyDeclaredChanges(
            model: controller.model,
            options: options,
            focusRequest: focusRequest
        )
    }
}
