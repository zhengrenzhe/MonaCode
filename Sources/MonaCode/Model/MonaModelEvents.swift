// MonaModelEvents.swift
//
// P01-T008 — Implement all 70 retained text-model members on Piece Tree truth.
//
// This file defines the event payload types emitted by `MonaCodeModel` (the
// counterparts of Monaco's `IModelContentChangedEvent` family), the
// `MonaModelEditOperation` value type that describes a single edit, and the
// minimal Phase 02 placeholder value types (`MonaModelDecoration`,
// `MonaModelDecorationOptions`, `MonaFindMatch`, `MonaModelSearchScope`)
// needed by the stub method signatures for decorations, search, and word.
//
// Undo, decorations, word, RegExp, and search behavior are left behind explicit
// Phase 02 interfaces — the model exposes the 70 member signatures, but the
// Phase 02 members return default (empty / nil / plaintext) values here. The
// placeholder types are intentionally minimal: Phase 02 fills in the real
// decoration and search contracts.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

// MARK: - Content change events (Monaco IModelContentChangedEvent family)

/// A single text change recorded in a `MonaModelContentChangeEvent`.
///
/// Ported from Monaco's `IModelContentChange`. `range` is the range of the
/// inserted text in the post-edit coordinate system; `rangeLength` is the
/// UTF-16 length of the text that was replaced; `rangeOffset` is the UTF-16
/// offset of that replaced range; `text` is the inserted text.
public struct MonaModelTextChange: Equatable {

    /// The range of the inserted text, in post-edit coordinates.
    public let range: MonaRange

    /// The UTF-16 length of the replaced range (0 for a pure insert).
    public let rangeLength: Int

    /// The UTF-16 offset of the start of the replaced range.
    public let rangeOffset: Int

    /// The text that was inserted.
    public let text: String

    /// Creates a text change.
    public init(range: MonaRange, rangeLength: Int, rangeOffset: Int, text: String) {
        self.range = range
        self.rangeLength = rangeLength
        self.rangeOffset = rangeOffset
        self.text = text
    }
}

/// The content-change event payload, fired by `onDidChangeContent`.
///
/// Ported from Monaco's `IModelContentChangedEvent`. `isFlush` is `true` for a
/// whole-buffer replacement (e.g. `setValue`); `isUndoing`/`isRedoing` are
/// always `false` in Phase 01 (undo/redo is Phase 02).
public struct MonaModelContentChangeEvent: Equatable {

    /// The atomic text changes in this event, in application order.
    public let changes: [MonaModelTextChange]

    /// The EOL sequence in effect when the event fired.
    public let eol: MonaEndOfLineSequence

    /// The model version id after the change.
    public let versionId: Int

    /// `true` when the change is part of an undo operation (Phase 02).
    public let isUndoing: Bool

    /// `true` when the change is part of a redo operation (Phase 02).
    public let isRedoing: Bool

    /// `true` when the change is a whole-buffer flush (e.g. `setValue`).
    public let isFlush: Bool

    /// Creates the event payload.
    public init(
        changes: [MonaModelTextChange],
        eol: MonaEndOfLineSequence,
        versionId: Int,
        isUndoing: Bool,
        isRedoing: Bool,
        isFlush: Bool
    ) {
        self.changes = changes
        self.eol = eol
        self.versionId = versionId
        self.isUndoing = isUndoing
        self.isRedoing = isRedoing
        self.isFlush = isFlush
    }
}

// MARK: - Other model events

/// The decorations-change event payload, fired by `onDidChangeDecorations`.
///
/// Ported from Monaco's `IModelDecorationsChangedEvent`. Phase 01 never fires
/// this (decorations are Phase 02); the type exists so the event surface is
/// complete.
public struct MonaModelDecorationChangeEvent: Equatable {

    /// `true` when the minimap is affected by the decoration change.
    public let affectsMinimap: Bool

    /// `true` when the overview ruler is affected by the decoration change.
    public let affectsOverviewRuler: Bool

    /// Creates the event payload.
    public init(affectsMinimap: Bool = false, affectsOverviewRuler: Bool = false) {
        self.affectsMinimap = affectsMinimap
        self.affectsOverviewRuler = affectsOverviewRuler
    }
}

/// The language-change event payload, fired by `onDidChangeLanguage`.
///
/// Ported from Monaco's `IModelLanguageChangedEvent`. Phase 01 never fires this
/// (the model is permanently `plaintext`); the type exists so the event surface
/// is complete.
public struct MonaModelLanguageChangeEvent: Equatable {

    /// The language id in effect before the change.
    public let oldLanguageId: String

    /// The language id in effect after the change.
    public let newLanguageId: String

    /// Creates the event payload.
    public init(oldLanguageId: String, newLanguageId: String) {
        self.oldLanguageId = oldLanguageId
        self.newLanguageId = newLanguageId
    }
}

/// The attached-change event payload, fired by `onDidChangeAttached`.
///
/// Ported from Monaco's `IModelAttachedChangedEvent`.
public struct MonaModelAttachedChangeEvent: Equatable {

    /// `true` when the model became attached to an editor, `false` when detached.
    public let isAttached: Bool

    /// Creates the event payload.
    public init(isAttached: Bool) {
        self.isAttached = isAttached
    }
}

// MARK: - Edit operation

/// A single edit operation applied to the model.
///
/// Ported from Monaco's `IIdentifiedSingleEditOperation`. `range` is the range
/// to replace (in pre-edit coordinates); `text` is the replacement text;
/// `forceMoveMarkers` controls marker affinity (Phase 02 decorations concern).
public struct MonaModelEditOperation: Equatable {

    /// The range of text to replace.
    public var range: MonaRange

    /// The text to insert in place of the range.
    public var text: String

    /// `true` when markers at the range boundary should move with the edit.
    public var forceMoveMarkers: Bool

    /// Creates an edit operation.
    public init(range: MonaRange, text: String, forceMoveMarkers: Bool = false) {
        self.range = range
        self.text = text
        self.forceMoveMarkers = forceMoveMarkers
    }
}

// MARK: - Phase 02 placeholder value types (decorations / search / word)

/// The search scope for `findMatches` and friends.
///
/// Phase 02 search supports arbitrary ranges; Phase 01 exposes only the
/// `.fullModel` scope, which the stub search members accept and ignore.
public struct MonaModelSearchScope: Equatable {

    private enum Kind: Equatable {
        case fullModel
        case range(MonaRange)
    }

    private let kind: Kind

    private init(kind: Kind) {
        self.kind = kind
    }

    /// The whole model range.
    ///
    /// A computed property (rather than a stored `static let`) so the type does
    /// not need to be `Sendable` for Swift 6's global-mutable-state check in
    /// Phase 01; concurrency isolation is established in Phase 02 (A+/R1).
    public static var fullModel: MonaModelSearchScope {
        return MonaModelSearchScope(kind: .fullModel)
    }

    /// A specific range scope (Phase 02).
    public static func range(_ range: MonaRange) -> MonaModelSearchScope {
        return MonaModelSearchScope(kind: .range(range))
    }
}

/// A minimal decoration-options placeholder.
///
/// Phase 02 fills in the real decoration contract (rendering options, ranges,
/// stickiness, etc.). Phase 01 accepts and discards it.
public struct MonaModelDecorationOptions: Equatable {

    /// Creates empty placeholder options.
    public init() {}
}

/// A minimal decoration placeholder.
///
/// Phase 02 fills in the real decoration contract. Phase 01 stubs return empty
/// arrays of these.
public struct MonaModelDecoration: Equatable {

    /// The decoration id.
    public let id: String

    /// The decoration range.
    public let range: MonaRange

    /// The decoration options.
    public let options: MonaModelDecorationOptions

    /// Creates a decoration.
    public init(id: String, range: MonaRange, options: MonaModelDecorationOptions) {
        self.id = id
        self.range = range
        self.options = options
    }
}

/// A minimal find-match placeholder.
///
/// Phase 02 fills in the real search contract (capture groups, match text).
/// Phase 01 stubs return empty arrays / nil of these.
public struct MonaFindMatch: Equatable {

    /// The matched range.
    public let range: MonaRange

    /// Creates a find match.
    public init(range: MonaRange) {
        self.range = range
    }
}
