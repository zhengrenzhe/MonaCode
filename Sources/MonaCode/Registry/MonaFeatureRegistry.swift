// MonaFeatureRegistry.swift
//
// P05-T002 — Implement command, action, contribution, and pure-text registries.
//
// `MonaFeatureRegistry` holds the frozen feature-flag identities of
// monaco-editor 0.56.0, registered in the source order recorded by the F1-R3
// scope manifest. Feature flags gate editor capabilities (e.g.
// `anchorSelect`, `bracketMatching`). Cut feature flags (the WebGPU debug flag)
// and later mobile (iPadOS) flags are recorded as explicit UNAVAILABLE
// dispositions with NO live registration.
///
/// The frozen identities + their source order come from the F1-R3 scope manifest
/// (`sourceGraph.featureEntries`), emitted WITHOUT renaming or coalescing.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

// MARK: - MonaFeatureIdentity

/// A frozen feature-flag identity, recorded in source order.
public struct MonaFeatureIdentity: Hashable, Sendable {

    /// The feature ID (e.g. `"anchorSelect"`, `"bracketMatching"`).
    public let id: String

    /// The disposition (retained-macos vs cut-webgpu-debug vs later-ipados).
    public let disposition: MonaRegistryDisposition

    /// `true` when this feature is a live production identity.
    public var isLive: Bool { disposition.isLive }

    public init(id: String, disposition: MonaRegistryDisposition) {
        self.id = id
        self.disposition = disposition
    }
}

// MARK: - MonaFeatureRegistry

/// Holds the frozen feature-flag identities of monaco-editor 0.56.0 in source
/// order.
///
/// Live (retained-macos) features are registered and queryable; the WebGPU debug
/// feature flag and the later iPadOS flag are recorded as UNAVAILABLE
/// dispositions and are never registered as live.
///
/// Disposal is idempotent: after `dispose()`, the registry is marked disposed
/// and further `dispose()` calls are no-ops.
public final class MonaFeatureRegistry {

    /// Every frozen feature identity in source order (live + cut).
    public static let frozenIdentities: [MonaFeatureIdentity] = [
        MonaFeatureIdentity(id: "anchorSelect", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "bracketMatching", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "caretOperations", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "clipboard", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "codeAction", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "codeEditor", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "codelens", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "codicon", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "colorPicker", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "comment", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "contextmenu", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "cursorUndo", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "diffEditor", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "diffEditorBreadcrumbs", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "dnd", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "documentSymbols", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "dropOrPasteInto", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "find", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "floatingMenu", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "folding", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "fontZoom", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "format", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "gotoError", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "gotoLine", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "gotoSymbol", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "gpu", disposition: .cutWebGpuDebug),
        MonaFeatureIdentity(id: "hover", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "iPadShowKeyboard", disposition: .laterIpados),
        MonaFeatureIdentity(id: "inPlaceReplace", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "indentation", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "inlayHints", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "inlineCompletions", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "inlineProgress", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "insertFinalNewLine", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "inspectTokens", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "lineSelection", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "linesOperations", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "linkedEditing", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "links", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "longLinesHelper", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "middleScroll", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "multicursor", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "parameterHints", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "placeholderText", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "quickCommand", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "quickHelp", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "quickOutline", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "readOnlyMessage", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "referenceSearch", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "rename", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "sectionHeaders", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "semanticTokens", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "smartSelect", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "snippet", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "stickyScroll", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "suggest", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "toggleHighContrast", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "toggleTabFocusMode", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "tokenization", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "unicodeHighlighter", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "unusualLineTerminators", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "wordHighlighter", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "wordOperations", disposition: .retainedMacos),
        MonaFeatureIdentity(id: "wordPartOperations", disposition: .retainedMacos)
    ]

    /// The live (retained-macos) feature identities, in source order.
    public let liveIdentities: [MonaFeatureIdentity]

    /// The cut (UNAVAILABLE) feature identities, in source order.
    public let cutIdentities: [MonaFeatureIdentity]

    private let byId: [String: MonaFeatureIdentity]
    private var _isDisposed = false
    private let _lock = NSLock()

    /// Creates a registry populated with all frozen feature identities.
    public init() {
        let frozen = Self.frozenIdentities
        self.liveIdentities = frozen.filter { $0.isLive }
        self.cutIdentities = frozen.filter { !$0.isLive }
        var map: [String: MonaFeatureIdentity] = [:]
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

    /// Returns the identity for `id`, or `nil` if no live feature is registered
    /// with that ID.
    public func identity(for id: String) -> MonaFeatureIdentity? {
        byId[id]
    }

    /// Returns `true` when a live feature with `id` is registered.
    public func contains(_ id: String) -> Bool {
        byId[id] != nil
    }

    // MARK: - Enablement

    /// Returns `true` when a live feature with `id` is registered and the
    /// registry is not disposed. Features carry no when-clause precondition.
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
