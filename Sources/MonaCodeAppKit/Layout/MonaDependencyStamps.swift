// MonaDependencyStamps.swift
//
// P03-T004 — Define seven non-contradictory dependency stamp domains.
//
// The renderer keys every cached projection, layout, paint, surface, and frame
// artifact by one of seven immutable dependency-stamp values. A stamp captures
// exactly the inputs that define its domain's identity; anything not in the
// stamp cannot change the domain's output. Viewport position is deliberately
// excluded from every stamp except `MonaFrameStamp`, so that an artifact is
// reusable across viewport positions as long as its shaping/projection/paint
// inputs are unchanged (the P03-T003 "key records by complete dependency
// stamps rather than viewport position alone" invariant).
//
// The seven domains (from V1-R3 "Plane dependencies"):
//   1. MonaProjectionStamp        — projection state (folding, wrapping,
//                                    injections, view zones).
//   2. MonaVerticalStamp         — vertical layout state (line heights, zones).
//   3. MonaScrollDimensionStamp   — scroll dimensions (content size, viewport).
//   4. MonaGeometryStamp         — line geometry inputs (glyph runs, advances,
//                                    baselines — from P03-T003).
//   5. MonaPaintStamp            — paint state (colors, themes, decorations).
//   6. MonaSurfaceStamp          — surface state (render target, scale, mode).
//   7. MonaFrameStamp            — frame state (viewport position, scroll).
//
// A frozen mutation-to-domain edge map (`MonaDependencyStampEdgeMap`)
// enumerates which mutations invalidate which stamps, derived from V1-R3
// (layout final closure) and V1-R4 (cross-engine contract). The map rejects
// both missing invalidations (a mutation that should invalidate a stamp but
// doesn't) and fanout beyond the frozen edge set (a mutation that invalidates
// too many stamps).

import Foundation
import CoreGraphics

// MARK: - MonaStampDomain

/// The seven dependency-stamp domains.
///
/// Each case corresponds 1:1 to one of the immutable stamp structs declared in
/// this file. The enum is the currency type used by `MonaDependencyStampEdgeMap`
/// to describe which domains a mutation invalidates.
public enum MonaStampDomain: String, Equatable, Hashable, Sendable, CaseIterable {
    case projection
    case vertical
    case scrollDimension
    case geometry
    case paint
    case surface
    case frame
}

// MARK: - Supporting enums for MonaSurfaceStamp

/// The render target that owns a surface's pixels.
public enum MonaRenderTargetKind: String, Equatable, Hashable, Sendable, CaseIterable {
    /// Core Graphics tiled renderer (the permanent correctness path and the
    /// first-shipped renderer per V1-R4's CG-first state machine).
    case coreGraphics
    /// Metal renderer (only built if CG fails the renderer-owned metrics gate;
    /// consumes the same `MonaLineLayoutRecord` as CG).
    case metal
}

/// The display mode a surface is rasterized for.
public enum MonaDisplayMode: String, Equatable, Hashable, Sendable, CaseIterable {
    /// Standard DPI display.
    case standard
    /// High-DPI (Retina) display.
    case highDPI
}

// MARK: - 1. MonaProjectionStamp

/// The immutable stamp for the **projection** domain.
///
/// Captures every input that defines the model→view-line projection mapping:
/// the model version, the view-line count, the wrapping column, and digests of
/// the folded ranges, hidden ranges, injected text, and view zones. A change to
/// any of these invalidates the projection; a change to font, paint, surface,
/// or scroll offset does NOT (those belong to other domains).
///
/// V1-R3 "Plane dependencies": projection is its own domain; V1-R3 hit 02
/// requires setWrappingSettings to synchronously rebuild all projections.
public struct MonaProjectionStamp: Equatable, Hashable, Sendable {

    /// The projection generation (monotonic; bumped on every rebuild).
    public let generation: Int

    /// The model version observed when this projection was built.
    public let modelVersion: Int

    /// The number of view lines produced by the projection.
    public let viewLineCount: Int

    /// The word-wrap column (`nil` = no wrapping).
    public let wrappingColumn: Int?

    /// A digest of the folded ranges (model ranges hidden by folding).
    public let foldedRangeDigest: Int

    /// A digest of the hidden (non-folded) ranges.
    public let hiddenRangeDigest: Int

    /// A digest of the injected-text / inlay segments.
    public let injectionDigest: Int

    /// A digest of the view zones (id, afterLineNumber, height, ordering).
    public let viewZoneDigest: Int

    /// Creates a projection stamp.
    public init(
        generation: Int,
        modelVersion: Int,
        viewLineCount: Int,
        wrappingColumn: Int?,
        foldedRangeDigest: Int,
        hiddenRangeDigest: Int,
        injectionDigest: Int,
        viewZoneDigest: Int
    ) {
        self.generation = generation
        self.modelVersion = modelVersion
        self.viewLineCount = viewLineCount
        self.wrappingColumn = wrappingColumn
        self.foldedRangeDigest = foldedRangeDigest
        self.hiddenRangeDigest = hiddenRangeDigest
        self.injectionDigest = injectionDigest
        self.viewZoneDigest = viewZoneDigest
    }

    /// The domain this stamp belongs to.
    public static let domain: MonaStampDomain = .projection
}

// MARK: - 2. MonaVerticalStamp

/// The immutable stamp for the **vertical** domain.
///
/// Captures every input that defines vertical layout: the projection
/// generation, the configured line height, the view-line count, a digest of
/// view-zone heights, and the total content height. Glyph shaping inputs
/// (font, scale, direction) are NOT part of vertical — they belong to the
/// geometry domain; vertical only owns the vertical spacing and stacking.
///
/// V1-R3 "纵向数值": line/custom-height and vertical prefix sums are Double
/// logical points; the vertical stamp records the identity of this stack.
public struct MonaVerticalStamp: Equatable, Hashable, Sendable {

    /// The projection generation this vertical stack was built against.
    public let generation: Int

    /// The configured line height (logical points).
    public let lineHeight: Int

    /// The number of view lines stacked.
    public let viewLineCount: Int

    /// A digest of the view-zone heights contributing to the stack.
    public let viewZoneHeightDigest: Int

    /// The total content height (logical points).
    public let totalHeight: Int

    /// Creates a vertical stamp.
    public init(
        generation: Int,
        lineHeight: Int,
        viewLineCount: Int,
        viewZoneHeightDigest: Int,
        totalHeight: Int
    ) {
        self.generation = generation
        self.lineHeight = lineHeight
        self.viewLineCount = viewLineCount
        self.viewZoneHeightDigest = viewZoneHeightDigest
        self.totalHeight = totalHeight
    }

    /// The domain this stamp belongs to.
    public static let domain: MonaStampDomain = .vertical
}

// MARK: - 3. MonaScrollDimensionStamp

/// The immutable stamp for the **scroll-dimension** domain.
///
/// Captures the published scroll dimensions: content width, content height,
/// viewport width, viewport height, and the derived viewport column. These are
/// the integer logical-point values that define the scrollable extent and the
/// clamping envelope (V1-R3: "scrollTop/Left、content dimensions: 整数逻辑点").
///
/// Content width is the *observed* value (V1-R3 "Observed width": "horizontal
/// scrollWidth 明确为已观测值"); it changes when geometry advances change or
/// when the projection changes the longest line.
public struct MonaScrollDimensionStamp: Equatable, Hashable, Sendable {

    /// The observed content width (logical points).
    public let contentWidth: Int

    /// The content height (logical points).
    public let contentHeight: Int

    /// The viewport width (logical points).
    public let viewportWidth: Int

    /// The viewport height (logical points).
    public let viewportHeight: Int

    /// The derived viewport column count.
    public let viewportColumn: Int

    /// Creates a scroll-dimension stamp.
    public init(
        contentWidth: Int,
        contentHeight: Int,
        viewportWidth: Int,
        viewportHeight: Int,
        viewportColumn: Int
    ) {
        self.contentWidth = contentWidth
        self.contentHeight = contentHeight
        self.viewportWidth = viewportWidth
        self.viewportHeight = viewportHeight
        self.viewportColumn = viewportColumn
    }

    /// The domain this stamp belongs to.
    public static let domain: MonaStampDomain = .scrollDimension
}

// MARK: - 4. MonaGeometryStamp

/// The immutable stamp for the **geometry** domain.
///
/// Captures the shared per-line shaping inputs: the font descriptor, the
/// device-space scale, the base writing direction, and the wrapping column.
/// These are exactly the fields of `MonaLineLayoutDependencyStamp` from
/// P03-T003; the domain-level `MonaGeometryStamp` is the identity used by the
/// mutation-to-domain edge map to decide whether a mutation dirties line
/// geometry (and therefore every cached `MonaLineLayoutRecord`).
///
/// V1-R4 hit 04: CG and Metal consume the same immutable LineLayoutRecord, so a
/// render-target switch does NOT invalidate geometry. V1-R3 hit 09: paint-only
/// selection/caret updates do NOT invalidate geometry (no re-rasterization).
public struct MonaGeometryStamp: Equatable, Hashable, Sendable {

    /// The font descriptor that shaped the lines.
    public let fontDescriptor: MonaFontDescriptor

    /// The device-space scale applied during shaping.
    public let scale: CGFloat

    /// The base writing direction.
    public let direction: MonaTextDirection

    /// The word-wrap column (`nil` = no wrapping).
    public let wrappingColumn: Int?

    /// Creates a geometry stamp.
    public init(
        fontDescriptor: MonaFontDescriptor,
        scale: CGFloat,
        direction: MonaTextDirection,
        wrappingColumn: Int?
    ) {
        self.fontDescriptor = fontDescriptor
        self.scale = scale
        self.direction = direction
        self.wrappingColumn = wrappingColumn
    }

    /// The domain this stamp belongs to.
    public static let domain: MonaStampDomain = .geometry
}

// MARK: - 5. MonaPaintStamp

/// The immutable stamp for the **paint** domain.
///
/// Captures the paint-only state: the theme, the decorations, the selection,
/// and the caret. V1-R3 hit 09 requires that paint-only selection/caret
/// updates do NOT require text re-rasterization — so the paint stamp is
/// independent of the geometry stamp, and a paint-only mutation invalidates
/// only `paint` and `frame` (the frame must be recomposited because the old
/// text plus a new cursor must not form an accepted frame).
public struct MonaPaintStamp: Equatable, Hashable, Sendable {

    /// A digest of the active theme (colors, token styles).
    public let themeDigest: Int

    /// A digest of the line decorations.
    public let decorationDigest: Int

    /// A digest of the selection ranges.
    public let selectionDigest: Int

    /// A digest of the caret state.
    public let caretDigest: Int

    /// Creates a paint stamp.
    public init(
        themeDigest: Int,
        decorationDigest: Int,
        selectionDigest: Int,
        caretDigest: Int
    ) {
        self.themeDigest = themeDigest
        self.decorationDigest = decorationDigest
        self.selectionDigest = selectionDigest
        self.caretDigest = caretDigest
    }

    /// The domain this stamp belongs to.
    public static let domain: MonaStampDomain = .paint
}

// MARK: - 6. MonaSurfaceStamp

/// The immutable stamp for the **surface** domain.
///
/// Captures the rasterization surface: the render target kind (Core Graphics or
/// Metal), the scale factor, the display mode, and the surface generation. A
/// geometry or paint change does NOT invalidate the surface — the surface is
/// only invalidated when the render target, scale, or display mode changes.
///
/// V1-R4 hit 06: CG-only is a terminal state; Metal is built only on a
/// renderer-owned metric failure. V1-R4 hit 04: a render-target switch does
/// not invalidate geometry (both renderers consume the same record).
public struct MonaSurfaceStamp: Equatable, Hashable, Sendable {

    /// The render target owning this surface's pixels.
    public let renderTargetKind: MonaRenderTargetKind

    /// The device-space scale factor (e.g. 2.0 for Retina).
    public let scaleFactor: CGFloat

    /// The display mode the surface is rasterized for.
    public let displayMode: MonaDisplayMode

    /// The surface generation (bumped on render-target / scale / mode switch).
    public let generation: Int

    /// Creates a surface stamp.
    public init(
        renderTargetKind: MonaRenderTargetKind,
        scaleFactor: CGFloat,
        displayMode: MonaDisplayMode,
        generation: Int
    ) {
        self.renderTargetKind = renderTargetKind
        self.scaleFactor = scaleFactor
        self.displayMode = displayMode
        self.generation = generation
    }

    /// The domain this stamp belongs to.
    public static let domain: MonaStampDomain = .surface
}

// MARK: - 7. MonaFrameStamp

/// The immutable stamp for the **frame** domain.
///
/// Captures the composited frame's viewport position: the scroll offset X/Y
/// and the frame generation. The frame is the only composite domain — any
/// mutation that invalidates projection, vertical, scroll-dimension, geometry,
/// paint, or surface also invalidates the frame (V1-R3 "Plane dependencies":
/// "model/geometry 变化后，旧文字与新 cursor 不得组成 accepted frame"). In
/// addition, a pure scroll-offset change invalidates ONLY the frame.
public struct MonaFrameStamp: Equatable, Hashable, Sendable {

    /// The published horizontal scroll offset (integer logical points).
    public let scrollOffsetX: Int

    /// The published vertical scroll offset (integer logical points).
    public let scrollOffsetY: Int

    /// The frame generation (bumped on every accepted frame).
    public let generation: Int

    /// Creates a frame stamp.
    public init(
        scrollOffsetX: Int,
        scrollOffsetY: Int,
        generation: Int
    ) {
        self.scrollOffsetX = scrollOffsetX
        self.scrollOffsetY = scrollOffsetY
        self.generation = generation
    }

    /// The domain this stamp belongs to.
    public static let domain: MonaStampDomain = .frame
}

// MARK: - MonaMutation

/// Every mutation that can invalidate one or more stamp domains.
///
/// The cases are derived from V1-R3 (layout final closure) and V1-R4
/// (cross-engine contract). Each case maps, via `MonaDependencyStampEdgeMap`,
/// to the exact set of stamp domains it invalidates — no more, no less.
public enum MonaMutation: String, Equatable, Hashable, Sendable, CaseIterable {

    // -- Model / projection inputs --
    /// A model edit (text content changed).
    case modelEdit
    /// Fold ranges changed.
    case foldChanged
    /// Injected text / inlay segments changed.
    case injectedTextChanged
    /// The word-wrap column / wrapping settings changed (V1-R3 hit 02).
    case wordWrapChanged
    /// View zones changed.
    case viewZonesChanged
    /// The configured line height changed.
    case lineHeightChanged

    // -- Geometry inputs --
    /// The font descriptor changed (font registration epoch).
    case fontChanged
    /// The base writing direction changed.
    case baseDirectionChanged

    // -- Paint inputs --
    /// The theme changed (color space / token styles).
    case themeChanged
    /// Line decorations changed.
    case decorationsChanged
    /// The selection changed (paint-only; V1-R3 hit 09).
    case selectionChanged
    /// The caret changed (paint-only; V1-R3 hit 09).
    case caretChanged

    // -- Scroll-dimension inputs --
    /// The observed content width changed (V1-R3: triggers projection).
    case contentWidthChanged
    /// The viewport size changed.
    case viewportSizeChanged

    // -- Surface inputs --
    /// The device scale factor changed.
    case scaleFactorChanged
    /// The display mode changed (e.g. standard ↔ high-DPI).
    case displayModeChanged

    // -- Frame inputs --
    /// The scroll offset changed (pure scroll; invalidates only the frame).
    case scrollOffsetChanged
    /// The render target changed (CG ↔ Metal; V1-R4 hit 04).
    case renderTargetChanged
}

// MARK: - MonaStampEdgeValidation

/// The result of validating a claimed invalidation set against the frozen
/// mutation-to-domain edge map.
///
/// A validation is valid (`isValid == true`) if and only if the claimed set
/// exactly equals the frozen set for the mutation. Two failure modes are
/// reported distinctly so callers can distinguish them:
///   - `missing`: stamp domains the frozen set requires that the claim omits.
///   - `fanout`:  stamp domains the claim includes that the frozen set forbids.
/// Both may be non-empty simultaneously.
public struct MonaStampEdgeValidation: Equatable, Hashable, Sendable {

    /// The mutation being validated.
    public let mutation: MonaMutation

    /// Stamp domains required by the frozen edge set but absent from the claim.
    public let missing: Set<MonaStampDomain>

    /// Stamp domains present in the claim but not permitted by the frozen set.
    public let fanout: Set<MonaStampDomain>

    /// `true` iff the claim exactly matches the frozen edge set.
    public var isValid: Bool { missing.isEmpty && fanout.isEmpty }

    /// Creates a validation result.
    public init(
        mutation: MonaMutation,
        missing: Set<MonaStampDomain>,
        fanout: Set<MonaStampDomain>
    ) {
        self.mutation = mutation
        self.missing = missing
        self.fanout = fanout
    }
}

// MARK: - MonaDependencyStampEdgeMap

/// The frozen, authoritative mapping from `MonaMutation` to the set of
/// `MonaStampDomain`s it invalidates.
///
/// Derived from V1-R3 (layout final closure) and V1-R4 (cross-engine contract).
/// The map is the single source of truth for which mutations dirty which stamp
/// domains; it rejects both:
///   - **missing invalidations**: a claim that omits a stamp the frozen set
///     requires for that mutation, and
///   - **fanout beyond the frozen edge set**: a claim that includes a stamp
///     the frozen set does not permit for that mutation.
///
/// The frozen edges are non-contradictory: each stamp domain's identity inputs
/// are touched by exactly the mutations that list it, and the frame domain
/// (the only composite) is invalidated by every mutation because the frame is
/// recomposited whenever any of its inputs or the scroll offset changes.
public struct MonaDependencyStampEdgeMap: Equatable, Hashable, Sendable {

    /// The standard frozen edge map shared across the renderer.
    public static let standard = MonaDependencyStampEdgeMap()

    /// Creates the frozen edge map.
    public init() {}

    /// Returns the frozen set of stamp domains invalidated by `mutation`.
    ///
    /// Every mutation has a non-empty frozen edge set; an unmapped mutation
    /// would itself be a missing-invalidation failure and is treated as
    /// invalidating every domain (the maximally conservative rejection) so that
    /// a registration gap can never silently produce an under-validated frame.
    public func invalidatedDomains(for mutation: MonaMutation) -> Set<MonaStampDomain> {
        return Self.frozenEdges[mutation] ?? Set(MonaStampDomain.allCases)
    }

    /// Validates a claimed invalidation set for `mutation` against the frozen
    /// edge set, reporting any missing or fanout domains.
    public func validate(
        mutation: MonaMutation,
        claimedInvalidated claimed: Set<MonaStampDomain>
    ) -> MonaStampEdgeValidation {
        let frozen = invalidatedDomains(for: mutation)
        let missing = frozen.subtracting(claimed)
        let fanout = claimed.subtracting(frozen)
        return MonaStampEdgeValidation(
            mutation: mutation,
            missing: missing,
            fanout: fanout
        )
    }

    // MARK: - Frozen edges

    /// The authoritative mutation→domain edge set.
    ///
    /// Each entry is justified by a V1-R3 / V1-R4 invariant:
    ///   - `modelEdit` dirties projection (model→view mapping), vertical
    ///     (line count/stack), scrollDimension (content size), geometry
    ///     (re-shape changed text), and frame (old text + new cursor rule).
    ///   - `foldChanged` dirties projection + vertical + scrollDimension +
    ///     frame; it does NOT dirty geometry (visible lines are not reshaped).
    ///   - `injectedTextChanged` dirties projection + geometry (injection
    ///     width is part of the line record) + scrollDimension + frame.
    ///   - `wordWrapChanged` dirties projection (V1-R3 hit 02) + vertical
    ///     (view-line count) + scrollDimension + geometry (wrapping column is
    ///     a shaping input) + frame.
    ///   - `viewZonesChanged` dirties projection + vertical (zone heights) +
    ///     scrollDimension + frame; NOT geometry.
    ///   - `lineHeightChanged` dirties vertical + scrollDimension + frame;
    ///     NOT geometry (glyph shapes are font-metric, not lineHeight).
    ///   - `fontChanged` dirties geometry (re-shape) + scrollDimension (pixel
    ///     content width) + frame; NOT projection (column mapping unchanged).
    ///   - `baseDirectionChanged` dirties geometry (bidi) + frame.
    ///   - `themeChanged` / `decorationsChanged` / `selectionChanged` /
    ///     `caretChanged` dirty paint + frame; NOT geometry (V1-R3 hit 09).
    ///   - `contentWidthChanged` dirties projection (V1-R3) + scrollDimension
    ///     + frame.
    ///   - `viewportSizeChanged` dirties scrollDimension + frame.
    ///   - `scaleFactorChanged` dirties surface + geometry (scale is a shaping
    ///     input) + scrollDimension (pixel content size) + frame.
    ///   - `displayModeChanged` dirties surface + frame.
    ///   - `scrollOffsetChanged` dirties ONLY frame (canonical pure scroll).
    ///   - `renderTargetChanged` dirties surface + frame; NOT geometry
    ///     (V1-R4 hit 04: same record).
    private static let frozenEdges: [MonaMutation: Set<MonaStampDomain>] = [
        .modelEdit:           [.projection, .vertical, .scrollDimension, .geometry, .frame],
        .foldChanged:         [.projection, .vertical, .scrollDimension, .frame],
        .injectedTextChanged: [.projection, .geometry, .scrollDimension, .frame],
        .wordWrapChanged:     [.projection, .vertical, .scrollDimension, .geometry, .frame],
        .viewZonesChanged:    [.projection, .vertical, .scrollDimension, .frame],
        .lineHeightChanged:   [.vertical, .scrollDimension, .frame],
        .fontChanged:         [.geometry, .scrollDimension, .frame],
        .baseDirectionChanged:[.geometry, .frame],
        .themeChanged:        [.paint, .frame],
        .decorationsChanged:  [.paint, .frame],
        .selectionChanged:    [.paint, .frame],
        .caretChanged:        [.paint, .frame],
        .contentWidthChanged: [.projection, .scrollDimension, .frame],
        .viewportSizeChanged: [.scrollDimension, .frame],
        .scaleFactorChanged:  [.surface, .geometry, .scrollDimension, .frame],
        .displayModeChanged:  [.surface, .frame],
        .scrollOffsetChanged: [.frame],
        .renderTargetChanged: [.surface, .frame],
    ]
}
