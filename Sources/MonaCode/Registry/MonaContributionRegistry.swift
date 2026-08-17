// MonaContributionRegistry.swift
//
// P05-T002 — Implement command, action, contribution, and pure-text registries.
//
// `MonaContributionRegistry` holds the frozen contribution identities of
// monaco-editor 0.56.0, registered in the source order recorded by the F1-R3
// scope manifest. Contributions are the editor's per-instance feature plug-ins
// (code lens, hover, find, folding, etc.) instantiated when an editor is
// created. Each identity exposes its instantiation kind and an idempotent
/// disposal path. The later mobile (iPadOS) contribution is recorded as an
/// explicit UNAVAILABLE disposition with NO live registration.
///
/// The frozen identities + their source order come from the F1-R3 scope manifest
/// (`registries.contributions`), emitted WITHOUT renaming or coalescing.
///
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

// MARK: - MonaContributionInstantiation

/// The instantiation kind of a contribution: when it is created relative to the
/// editor lifecycle (ported from Monaco's `EditorContributionInstantiation`).
public enum MonaContributionInstantiation: Int, Sendable, Equatable, CaseIterable {

    /// Eagerly instantiated when the editor is created.
    case eager = 0

    /// Instantiated after the editor's model is attached.
    case afterModelAttached = 1

    /// Instantiated before the editor's first render.
    case beforeFirstRender = 2

    /// Lazily instantiated when the editor's DOM is ready.
    case onDomReady = 3

    /// Instantiated when the editor is lazily needed (event-driven).
    case lazy = 4
}

// MARK: - MonaContributionIdentity

/// A frozen contribution identity, recorded in source order.
public struct MonaContributionIdentity: Hashable, Sendable {

    /// The ordinal (source position) within the contributions registry.
    public let ordinal: Int

    /// The contribution ID (e.g. `"editor.contrib.findController"`).
    public let id: String

    /// The instantiation kind.
    public let instantiation: MonaContributionInstantiation

    /// The disposition (retained-macos vs later-ipados).
    public let disposition: MonaRegistryDisposition

    /// `true` when this contribution is a live production identity.
    public var isLive: Bool { disposition.isLive }

    public init(
        ordinal: Int,
        id: String,
        instantiation: Int,
        disposition: MonaRegistryDisposition
    ) {
        self.ordinal = ordinal
        self.id = id
        self.instantiation = MonaContributionInstantiation(rawValue: instantiation) ?? .eager
        self.disposition = disposition
    }
}

// MARK: - MonaContributionRegistry

/// Holds the frozen contribution identities of monaco-editor 0.56.0 in source
/// order.
///
/// Live (retained-macos) contributions are registered and queryable; the later
/// mobile (iPadOS) contribution is recorded as an UNAVAILABLE disposition and
/// is never registered as live.
///
/// Disposal is idempotent: after `dispose()`, the registry is marked disposed
/// and further `dispose()` calls are no-ops.
public final class MonaContributionRegistry {

    /// Every frozen contribution identity in source order (live + cut).
    public static let frozenIdentities: [MonaContributionIdentity] = [
        MonaContributionIdentity(ordinal: 0, id: "editor.contrib.markerDecorations", instantiation: 0, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 1, id: "editor.contrib.selectionAnchorController", instantiation: 4, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 2, id: "editor.contrib.bracketMatchingController", instantiation: 1, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 3, id: "editor.contrib.messageController", instantiation: 4, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 4, id: "editor.contrib.codeActionController", instantiation: 3, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 5, id: "editor.contrib.lightbulbWidget", instantiation: 4, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 6, id: "css.editor.codeLens", instantiation: 1, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 7, id: "editor.contrib.referenceController", instantiation: 0, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 8, id: "editor.contrib.colorContribution", instantiation: 2, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 9, id: "editor.contrib.standaloneColorPickerController", instantiation: 1, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 10, id: "editor.contrib.colorDetector", instantiation: 1, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 11, id: "editor.contrib.contextmenu", instantiation: 2, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 12, id: "editor.contrib.cursorUndoRedoController", instantiation: 0, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 13, id: "editor.contrib.dragAndDrop", instantiation: 2, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 14, id: "editor.contrib.copyPasteActionController", instantiation: 0, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 15, id: "editor.contrib.dropIntoEditorController", instantiation: 2, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 16, id: "editor.contrib.findController", instantiation: 0, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 17, id: "editor.contrib.folding", instantiation: 0, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 18, id: "editor.contrib.autoFormat", instantiation: 2, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 19, id: "editor.contrib.formatOnPaste", instantiation: 2, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 20, id: "editor.contrib.markerController", instantiation: 4, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 21, id: "snippetController2", instantiation: 4, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 22, id: "editor.contrib.renameController", instantiation: 4, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 23, id: "editor.contrib.suggestController", instantiation: 2, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 24, id: "editor.contrib.inlineCompletionsController", instantiation: 3, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 25, id: "editor.contrib.gotodefinitionatposition", instantiation: 2, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 26, id: "editor.contrib.markerSelectionStatus", instantiation: 1, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 27, id: "editor.contrib.contentHover", instantiation: 2, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 28, id: "editor.contrib.marginHover", instantiation: 2, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 29, id: "editor.contrib.autoIndentOnPaste", instantiation: 2, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 30, id: "editor.contrib.InlayHints", instantiation: 1, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 31, id: "editor.contrib.inPlaceReplaceController", instantiation: 4, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 32, id: "editor.contrib.linkedEditing", instantiation: 1, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 33, id: "editor.linkDetector", instantiation: 1, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 34, id: "editor.contrib.longLinesHelper", instantiation: 2, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 35, id: "editor.contrib.middleScroll", instantiation: 2, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 36, id: "editor.contrib.multiCursorController", instantiation: 4, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 37, id: "editor.contrib.selectionHighlighter", instantiation: 1, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 38, id: "editor.controller.parameterHints", instantiation: 2, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 39, id: "editor.contrib.placeholderText", instantiation: 0, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 40, id: "editor.sectionHeaderDetector", instantiation: 1, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 41, id: "editor.contrib.viewportSemanticTokens", instantiation: 1, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 42, id: "editor.contrib.smartSelectController", instantiation: 4, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 43, id: "store.contrib.stickyScrollController", instantiation: 1, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 44, id: "editor.contrib.unicodeHighlighter", instantiation: 1, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 45, id: "editor.contrib.unusualLineTerminatorsDetector", instantiation: 1, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 46, id: "editor.contrib.wordHighlighter", instantiation: 0, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 47, id: "editor.contrib.readOnlyMessageController", instantiation: 2, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 48, id: "editor.contrib.floatingToolbar", instantiation: 1, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 49, id: "editor.contrib.iPadShowKeyboard", instantiation: 3, disposition: .laterIpados),
        MonaContributionIdentity(ordinal: 50, id: "editor.contrib.inspectTokens", instantiation: 4, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 51, id: "editor.contrib.referencesController", instantiation: 4, disposition: .retainedMacos),
        MonaContributionIdentity(ordinal: 52, id: "editor.controller.quickInput", instantiation: 4, disposition: .retainedMacos)
    ]

    /// The live (retained-macos) contribution identities, in source order.
    public let liveIdentities: [MonaContributionIdentity]

    /// The cut (UNAVAILABLE) contribution identities, in source order.
    public let cutIdentities: [MonaContributionIdentity]

    private let byId: [String: MonaContributionIdentity]
    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates a registry populated with all frozen contribution identities.
    public init() {
        let frozen = Self.frozenIdentities
        self.liveIdentities = frozen.filter { $0.isLive }
        self.cutIdentities = frozen.filter { !$0.isLive }
        var map: [String: MonaContributionIdentity] = [:]
        for identity in frozen where identity.isLive {
            map[identity.id] = identity
        }
        self.byId = map
    }

    /// `true` after `dispose()` has been called.
    public var isDisposed: Bool {
        _lock.lock()
        defer { _lock.unlock() }
        return _isDisposed
    }

    public var totalCount: Int { Self.frozenIdentities.count }
    public var liveCount: Int { liveIdentities.count }
    public var cutCount: Int { cutIdentities.count }

    // MARK: - Lookup

    /// Returns the identity for `id`, or `nil` if no live contribution is
    /// registered with that ID.
    public func identity(for id: String) -> MonaContributionIdentity? {
        byId[id]
    }

    /// Returns `true` when a live contribution with `id` is registered.
    public func contains(_ id: String) -> Bool {
        byId[id] != nil
    }

    /// Returns the instantiation kind for `id`, or `nil` if no live
    /// contribution is registered with that ID.
    public func instantiation(for id: String) -> MonaContributionInstantiation? {
        byId[id]?.instantiation
    }

    // MARK: - Enablement

    /// Returns `true` when a live contribution with `id` is registered and the
    /// registry is not disposed. Contributions carry no when-clause precondition;
    /// they are enabled whenever live and registered.
    public func isEnabled(_ id: String, context: MonaKeybindingContext) -> Bool {
        guard !isDisposed else { return false }
        return byId[id] != nil
    }

    // MARK: - Disposal

    /// Disposes the registry. Idempotent: calling it again is a no-op.
    public func dispose() {
        _lock.lock()
        _isDisposed = true
        _lock.unlock()
    }
}
