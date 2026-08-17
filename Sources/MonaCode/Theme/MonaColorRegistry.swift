// MonaColorRegistry.swift
//
// P05-T006 — Implement theme, token, color, icon, and Codicon registries.
//
// GENERATED FILE — do not edit by hand. Transcribed verbatim from the F1-R3
// scope manifest (monaco-editor@0.56.0 builtin colors/icons/themes/Codicon
// glyphs). Regenerate by re-running the P05-T006 transcription against the
// manifest at:
//   docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/parent/g5-r/artifacts/monaco-0.56.0-f1r3-scope-manifest.json
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.
import Foundation

// MARK: - Color value model

/// A concrete color (already resolved to a CSS/hex string for the renderer).
public struct MonaColorValue: Sendable, Equatable {
    public let css: String
    public init(_ css: String) { self.css = css }
}

/// A color transform descriptor kept for the native rendering layer
/// (V1-R4/T1-R). The Core resolves references and picks the correct variant;
/// the final pixel math (lighten/darken/transparent/blend/mix/conditional) is
/// evaluated where fonts and Core Graphics live.
public struct MonaColorTransform: Sendable, Equatable {
    /// Numeric op id transcribed verbatim from the manifest color defaults.
    public let kind: Int
    public let factor: Double?
    public let ratio: Double?
    /// Base/target color node (darken/lighten/transparent/mix base, or the
    /// `then`/`else` arm of an if-then-else, or a blend member).
    public let value: MonaColorNode?
    public let values: [MonaColorNode]?
    public let condition: MonaColorNode?
    public let thenValue: MonaColorNode?
    public let elseValue: MonaColorNode?
    public let mixWith: MonaColorNode?

    public init(kind: Int, factor: Double? = nil, ratio: Double? = nil,
                value: MonaColorNode? = nil, values: [MonaColorNode]? = nil,
                condition: MonaColorNode? = nil, thenValue: MonaColorNode? = nil,
                elseValue: MonaColorNode? = nil, mixWith: MonaColorNode? = nil) {
        self.kind = kind; self.factor = factor; self.ratio = ratio
        self.value = value; self.values = values; self.condition = condition
        self.thenValue = thenValue; self.elseValue = elseValue; self.mixWith = mixWith
    }
}

/// One node of a color default value. `indirect` because transforms embed
/// further color nodes (their target/base).
public indirect enum MonaColorNode: Sendable, Equatable {
    /// No value (manifest `null`).
    case none
    /// A CSS color string literal (manifest hex string or `_toString`).
    case css(String)
    /// An RGBA literal transcribed from the manifest `rgba` object.
    case rgba(r: Int, g: Int, b: Int, a: Double)
    /// A reference to another color id (e.g. `foreground`).
    case reference(String)
    /// A transform descriptor for the renderer.
    case transform(MonaColorTransform)
}

/// A color's default value: either a single value applied to every theme
/// variant, or per-variant values (`dark`/`hcDark`/`hcLight`/`light`).
public enum MonaColorDefault: Sendable, Equatable {
    case all(MonaColorNode)
    case variants(dark: MonaColorNode, hcDark: MonaColorNode,
                  hcLight: MonaColorNode, light: MonaColorNode)
}

/// A builtin color contribution transcribed verbatim from the F1-R3 manifest.
public struct MonaColorEntry: Sendable, Equatable {
    public let id: String
    public let defaults: MonaColorDefault
    public let needsTransparency: Bool
    public init(id: String, defaults: MonaColorDefault, needsTransparency: Bool) {
        self.id = id; self.defaults = defaults; self.needsTransparency = needsTransparency
    }
}

/// A theme color variant. Identifies which slot of a per-variant default to
/// resolve, and drives high-contrast fallback (`hcDark` falls back to `dark`,
/// `hcLight` falls back to `light`).
public enum MonaColorVariant: String, Sendable, CaseIterable {
    case light, dark, hcLight, hcDark
}

/// The result of resolving a color id for a variant.
public enum MonaResolvedColor: Sendable, Equatable {
    /// A concrete CSS color string (hex or `rgba(...)`), ready for the renderer.
    case value(MonaColorValue)
    /// A transform the renderer must evaluate (references already resolved
    /// where possible; the arithmetic is deferred to the native layer).
    case transform(MonaColorTransform)
    /// No value could be resolved (the color has no default for this variant).
    case none
}

// MARK: - Color registry

/// The 431 builtin color contributions ported verbatim from
/// monaco-editor@0.56.0 (F1-R3 scope manifest `registries.colors`), plus the
/// deterministic default resolver.
public enum MonaColorRegistry {

    /// All 431 builtin color contributions in source-ordinal order.
    public static let colors: [MonaColorEntry] = [
        MonaColorEntry(id: "actionBar.toggledBackground", defaults: .all(.reference("inputOption.activeBackground")), needsTransparency: false),
        MonaColorEntry(id: "activityErrorBadge.background", defaults: .variants(dark: .css("#F14C4C"), hcDark: .none, hcLight: .css("#F14C4C"), light: .css("#E51400")), needsTransparency: false),
        MonaColorEntry(id: "activityErrorBadge.foreground", defaults: .variants(dark: .rgba(r: 0, g: 0, b: 0, a: 1.0), hcDark: .none, hcLight: .rgba(r: 0, g: 0, b: 0, a: 1.0), light: .css("#ffffff")), needsTransparency: false),
        MonaColorEntry(id: "activityWarningBadge.background", defaults: .variants(dark: .css("#B27C00"), hcDark: .none, hcLight: .css("#B27C00"), light: .css("#B27C00")), needsTransparency: false),
        MonaColorEntry(id: "activityWarningBadge.foreground", defaults: .variants(dark: .css("#ffffff"), hcDark: .css("#ffffff"), hcLight: .css("#ffffff"), light: .css("#ffffff")), needsTransparency: false),
        MonaColorEntry(id: "badge.background", defaults: .variants(dark: .css("#4D4D4D"), hcDark: .css("#000000"), hcLight: .css("#0F4A85"), light: .css("#C4C4C4")), needsTransparency: false),
        MonaColorEntry(id: "badge.foreground", defaults: .variants(dark: .css("#ffffff"), hcDark: .css("#ffffff"), hcLight: .css("#ffffff"), light: .css("#333")), needsTransparency: false),
        MonaColorEntry(id: "breadcrumb.activeSelectionForeground", defaults: .variants(dark: .transform(.init(kind: 1, factor: 0.1, value: .reference("foreground"))), hcDark: .transform(.init(kind: 1, factor: 0.1, value: .reference("foreground"))), hcLight: .transform(.init(kind: 1, factor: 0.1, value: .reference("foreground"))), light: .transform(.init(kind: 0, factor: 0.2, value: .reference("foreground")))), needsTransparency: false),
        MonaColorEntry(id: "breadcrumb.background", defaults: .all(.reference("editor.background")), needsTransparency: false),
        MonaColorEntry(id: "breadcrumb.focusForeground", defaults: .variants(dark: .transform(.init(kind: 1, factor: 0.1, value: .reference("foreground"))), hcDark: .transform(.init(kind: 1, factor: 0.1, value: .reference("foreground"))), hcLight: .transform(.init(kind: 1, factor: 0.1, value: .reference("foreground"))), light: .transform(.init(kind: 0, factor: 0.2, value: .reference("foreground")))), needsTransparency: false),
        MonaColorEntry(id: "breadcrumb.foreground", defaults: .all(.transform(.init(kind: 2, factor: 0.8, value: .reference("foreground")))), needsTransparency: false),
        MonaColorEntry(id: "breadcrumbPicker.background", defaults: .all(.reference("editorWidget.background")), needsTransparency: false),
        MonaColorEntry(id: "button.background", defaults: .variants(dark: .css("#0E639C"), hcDark: .css("#000000"), hcLight: .css("#0F4A85"), light: .css("#007ACC")), needsTransparency: false),
        MonaColorEntry(id: "button.border", defaults: .all(.reference("contrastBorder")), needsTransparency: false),
        MonaColorEntry(id: "button.foreground", defaults: .all(.css("#ffffff")), needsTransparency: false),
        MonaColorEntry(id: "button.hoverBackground", defaults: .variants(dark: .transform(.init(kind: 1, factor: 0.2, value: .reference("button.background"))), hcDark: .reference("button.background"), hcLight: .reference("button.background"), light: .transform(.init(kind: 0, factor: 0.2, value: .reference("button.background")))), needsTransparency: false),
        MonaColorEntry(id: "button.secondaryBackground", defaults: .variants(dark: .reference("list.hoverBackground"), hcDark: .none, hcLight: .css("#ffffff"), light: .reference("list.hoverBackground")), needsTransparency: false),
        MonaColorEntry(id: "button.secondaryBorder", defaults: .variants(dark: .transform(.init(kind: 2, factor: 0.15, value: .reference("foreground"))), hcDark: .reference("contrastBorder"), hcLight: .reference("contrastBorder"), light: .transform(.init(kind: 2, factor: 0.15, value: .reference("foreground")))), needsTransparency: false),
        MonaColorEntry(id: "button.secondaryForeground", defaults: .variants(dark: .reference("foreground"), hcDark: .css("#ffffff"), hcLight: .reference("foreground"), light: .reference("foreground")), needsTransparency: false),
        MonaColorEntry(id: "button.secondaryHoverBackground", defaults: .variants(dark: .transform(.init(kind: 1, factor: 0.2, value: .reference("list.hoverBackground"))), hcDark: .none, hcLight: .none, light: .transform(.init(kind: 1, factor: 0.2, value: .reference("list.hoverBackground")))), needsTransparency: false),
        MonaColorEntry(id: "button.separator", defaults: .all(.transform(.init(kind: 2, factor: 0.4, value: .reference("button.foreground")))), needsTransparency: false),
        MonaColorEntry(id: "chart.axis", defaults: .variants(dark: .rgba(r: 191, g: 191, b: 191, a: 0.4), hcDark: .reference("contrastBorder"), hcLight: .reference("contrastBorder"), light: .css("rgba(0, 0, 0, 0.6)")), needsTransparency: false),
        MonaColorEntry(id: "chart.guide", defaults: .variants(dark: .rgba(r: 191, g: 191, b: 191, a: 0.2), hcDark: .reference("contrastBorder"), hcLight: .reference("contrastBorder"), light: .css("rgba(0, 0, 0, 0.2)")), needsTransparency: false),
        MonaColorEntry(id: "chart.line", defaults: .variants(dark: .css("#236B8E"), hcDark: .css("#236B8E"), hcLight: .css("#236B8E"), light: .css("#236B8E")), needsTransparency: false),
        MonaColorEntry(id: "charts.blue", defaults: .all(.reference("editorInfo.foreground")), needsTransparency: false),
        MonaColorEntry(id: "charts.foreground", defaults: .all(.reference("foreground")), needsTransparency: false),
        MonaColorEntry(id: "charts.green", defaults: .variants(dark: .css("#89D185"), hcDark: .css("#89D185"), hcLight: .css("#374e06"), light: .css("#388A34")), needsTransparency: false),
        MonaColorEntry(id: "charts.lines", defaults: .all(.transform(.init(kind: 2, factor: 0.5, value: .reference("foreground")))), needsTransparency: false),
        MonaColorEntry(id: "charts.orange", defaults: .all(.reference("minimap.findMatchHighlight")), needsTransparency: false),
        MonaColorEntry(id: "charts.purple", defaults: .variants(dark: .css("#B180D7"), hcDark: .css("#B180D7"), hcLight: .css("#652D90"), light: .css("#652D90")), needsTransparency: false),
        MonaColorEntry(id: "charts.red", defaults: .all(.reference("editorError.foreground")), needsTransparency: false),
        MonaColorEntry(id: "charts.yellow", defaults: .all(.reference("editorWarning.foreground")), needsTransparency: false),
        MonaColorEntry(id: "checkbox.background", defaults: .all(.reference("dropdown.background")), needsTransparency: false),
        MonaColorEntry(id: "checkbox.border", defaults: .all(.reference("dropdown.border")), needsTransparency: false),
        MonaColorEntry(id: "checkbox.disabled.background", defaults: .all(.transform(.init(kind: 7, ratio: 0.33, value: .reference("checkbox.background"), mixWith: .reference("checkbox.foreground")))), needsTransparency: false),
        MonaColorEntry(id: "checkbox.disabled.foreground", defaults: .all(.transform(.init(kind: 7, ratio: 0.33, value: .reference("checkbox.foreground"), mixWith: .reference("checkbox.background")))), needsTransparency: false),
        MonaColorEntry(id: "checkbox.foreground", defaults: .all(.reference("dropdown.foreground")), needsTransparency: false),
        MonaColorEntry(id: "checkbox.selectBackground", defaults: .all(.reference("editorWidget.background")), needsTransparency: false),
        MonaColorEntry(id: "checkbox.selectBorder", defaults: .all(.reference("icon.foreground")), needsTransparency: false),
        MonaColorEntry(id: "contrastActiveBorder", defaults: .variants(dark: .none, hcDark: .reference("focusBorder"), hcLight: .reference("focusBorder"), light: .none), needsTransparency: false),
        MonaColorEntry(id: "contrastBorder", defaults: .variants(dark: .none, hcDark: .css("#6FC3DF"), hcLight: .css("#0F4A85"), light: .none), needsTransparency: false),
        MonaColorEntry(id: "descriptionForeground", defaults: .variants(dark: .transform(.init(kind: 2, factor: 0.7, value: .reference("foreground"))), hcDark: .transform(.init(kind: 2, factor: 0.7, value: .reference("foreground"))), hcLight: .transform(.init(kind: 2, factor: 0.7, value: .reference("foreground"))), light: .css("#717171")), needsTransparency: false),
        MonaColorEntry(id: "diffEditor.border", defaults: .variants(dark: .none, hcDark: .reference("contrastBorder"), hcLight: .reference("contrastBorder"), light: .none), needsTransparency: false),
        MonaColorEntry(id: "diffEditor.diagonalFill", defaults: .variants(dark: .css("#cccccc33"), hcDark: .none, hcLight: .none, light: .css("#22222233")), needsTransparency: false),
        MonaColorEntry(id: "diffEditor.insertedLineBackground", defaults: .variants(dark: .css("rgba(155, 185, 85, 0.2)"), hcDark: .none, hcLight: .none, light: .css("rgba(155, 185, 85, 0.2)")), needsTransparency: true),
        MonaColorEntry(id: "diffEditor.insertedTextBackground", defaults: .variants(dark: .css("#9ccc2c33"), hcDark: .none, hcLight: .none, light: .css("#9ccc2c40")), needsTransparency: true),
        MonaColorEntry(id: "diffEditor.insertedTextBorder", defaults: .variants(dark: .none, hcDark: .css("#33ff2eff"), hcLight: .css("#374E06"), light: .none), needsTransparency: false),
        MonaColorEntry(id: "diffEditor.move.border", defaults: .all(.css("#8b8b8b9c")), needsTransparency: false),
        MonaColorEntry(id: "diffEditor.moveActive.border", defaults: .all(.css("#FFA500")), needsTransparency: false),
        MonaColorEntry(id: "diffEditor.removedLineBackground", defaults: .variants(dark: .css("rgba(255, 0, 0, 0.2)"), hcDark: .none, hcLight: .none, light: .css("rgba(255, 0, 0, 0.2)")), needsTransparency: true),
        MonaColorEntry(id: "diffEditor.removedTextBackground", defaults: .variants(dark: .css("#ff000033"), hcDark: .none, hcLight: .none, light: .css("#ff000033")), needsTransparency: true),
        MonaColorEntry(id: "diffEditor.removedTextBorder", defaults: .variants(dark: .none, hcDark: .css("#FF008F"), hcLight: .css("#AD0707"), light: .none), needsTransparency: false),
        MonaColorEntry(id: "diffEditor.unchangedCodeBackground", defaults: .variants(dark: .css("#74747429"), hcDark: .none, hcLight: .none, light: .css("#b8b8b829")), needsTransparency: false),
        MonaColorEntry(id: "diffEditor.unchangedRegionBackground", defaults: .all(.reference("sideBar.background")), needsTransparency: false),
        MonaColorEntry(id: "diffEditor.unchangedRegionForeground", defaults: .all(.reference("foreground")), needsTransparency: false),
        MonaColorEntry(id: "diffEditor.unchangedRegionShadow", defaults: .variants(dark: .css("#000000"), hcDark: .css("#000000"), hcLight: .css("#737373BF"), light: .css("#737373BF")), needsTransparency: false),
        MonaColorEntry(id: "diffEditorGutter.insertedLineBackground", defaults: .all(.none), needsTransparency: false),
        MonaColorEntry(id: "diffEditorGutter.removedLineBackground", defaults: .all(.none), needsTransparency: false),
        MonaColorEntry(id: "diffEditorOverview.insertedForeground", defaults: .all(.none), needsTransparency: false),
        MonaColorEntry(id: "diffEditorOverview.removedForeground", defaults: .all(.none), needsTransparency: false),
        MonaColorEntry(id: "disabledForeground", defaults: .variants(dark: .css("#CCCCCC80"), hcDark: .css("#A5A5A5"), hcLight: .css("#7F7F7F"), light: .css("#61616180")), needsTransparency: false),
        MonaColorEntry(id: "dropdown.background", defaults: .variants(dark: .css("#3C3C3C"), hcDark: .css("#000000"), hcLight: .css("#ffffff"), light: .css("#ffffff")), needsTransparency: false),
        MonaColorEntry(id: "dropdown.border", defaults: .variants(dark: .reference("dropdown.background"), hcDark: .reference("contrastBorder"), hcLight: .reference("contrastBorder"), light: .css("#CECECE")), needsTransparency: false),
        MonaColorEntry(id: "dropdown.foreground", defaults: .variants(dark: .css("#F0F0F0"), hcDark: .css("#ffffff"), hcLight: .reference("foreground"), light: .reference("foreground")), needsTransparency: false),
        MonaColorEntry(id: "dropdown.listBackground", defaults: .variants(dark: .none, hcDark: .css("#000000"), hcLight: .css("#ffffff"), light: .none), needsTransparency: false),
        MonaColorEntry(id: "editor.background", defaults: .variants(dark: .css("#1E1E1E"), hcDark: .css("#000000"), hcLight: .css("#ffffff"), light: .css("#ffffff")), needsTransparency: false),
        MonaColorEntry(id: "editor.compositionBorder", defaults: .variants(dark: .css("#ffffff"), hcDark: .css("#ffffff"), hcLight: .css("#000000"), light: .css("#000000")), needsTransparency: false),
        MonaColorEntry(id: "editor.findMatchBackground", defaults: .variants(dark: .css("#515C6A"), hcDark: .none, hcLight: .none, light: .css("#A8AC94")), needsTransparency: false),
        MonaColorEntry(id: "editor.findMatchBorder", defaults: .variants(dark: .none, hcDark: .reference("contrastActiveBorder"), hcLight: .reference("contrastActiveBorder"), light: .none), needsTransparency: false),
        MonaColorEntry(id: "editor.findMatchForeground", defaults: .all(.none), needsTransparency: false),
        MonaColorEntry(id: "editor.findMatchHighlightBackground", defaults: .variants(dark: .css("#EA5C0055"), hcDark: .none, hcLight: .none, light: .css("#EA5C0055")), needsTransparency: true),
        MonaColorEntry(id: "editor.findMatchHighlightBorder", defaults: .variants(dark: .none, hcDark: .reference("contrastActiveBorder"), hcLight: .reference("contrastActiveBorder"), light: .none), needsTransparency: false),
        MonaColorEntry(id: "editor.findMatchHighlightForeground", defaults: .all(.none), needsTransparency: true),
        MonaColorEntry(id: "editor.findRangeHighlightBackground", defaults: .variants(dark: .css("#3a3d4166"), hcDark: .none, hcLight: .none, light: .css("#b4b4b44d")), needsTransparency: true),
        MonaColorEntry(id: "editor.findRangeHighlightBorder", defaults: .variants(dark: .none, hcDark: .transform(.init(kind: 2, factor: 0.4, value: .reference("contrastActiveBorder"))), hcLight: .transform(.init(kind: 2, factor: 0.4, value: .reference("contrastActiveBorder"))), light: .none), needsTransparency: true),
        MonaColorEntry(id: "editor.foldBackground", defaults: .variants(dark: .transform(.init(kind: 2, factor: 0.3, value: .reference("editor.selectionBackground"))), hcDark: .none, hcLight: .none, light: .transform(.init(kind: 2, factor: 0.3, value: .reference("editor.selectionBackground")))), needsTransparency: true),
        MonaColorEntry(id: "editor.foldPlaceholderForeground", defaults: .variants(dark: .css("#808080"), hcDark: .none, hcLight: .none, light: .css("#808080")), needsTransparency: false),
        MonaColorEntry(id: "editor.foreground", defaults: .variants(dark: .css("#BBBBBB"), hcDark: .css("#ffffff"), hcLight: .reference("foreground"), light: .css("#333333")), needsTransparency: false),
        MonaColorEntry(id: "editor.hoverHighlightBackground", defaults: .variants(dark: .css("#264f7840"), hcDark: .css("#ADD6FF26"), hcLight: .none, light: .css("#ADD6FF26")), needsTransparency: true),
        MonaColorEntry(id: "editor.inactiveLineHighlightBackground", defaults: .all(.reference("editor.lineHighlightBackground")), needsTransparency: false),
        MonaColorEntry(id: "editor.inactiveSelectionBackground", defaults: .variants(dark: .transform(.init(kind: 2, factor: 0.5, value: .reference("editor.selectionBackground"))), hcDark: .transform(.init(kind: 2, factor: 0.7, value: .reference("editor.selectionBackground"))), hcLight: .transform(.init(kind: 2, factor: 0.5, value: .reference("editor.selectionBackground"))), light: .transform(.init(kind: 2, factor: 0.5, value: .reference("editor.selectionBackground")))), needsTransparency: true),
        MonaColorEntry(id: "editor.lineHighlightBackground", defaults: .all(.none), needsTransparency: false),
        MonaColorEntry(id: "editor.lineHighlightBorder", defaults: .variants(dark: .css("#282828"), hcDark: .css("#f38518"), hcLight: .reference("contrastBorder"), light: .css("#eeeeee")), needsTransparency: false),
        MonaColorEntry(id: "editor.linkedEditingBackground", defaults: .variants(dark: .rgba(r: 255, g: 0, b: 0, a: 0.3), hcDark: .rgba(r: 255, g: 0, b: 0, a: 0.3), hcLight: .css("#ffffff"), light: .css("rgba(255, 0, 0, 0.3)")), needsTransparency: false),
        MonaColorEntry(id: "editor.placeholder.foreground", defaults: .all(.reference("editorGhostText.foreground")), needsTransparency: false),
        MonaColorEntry(id: "editor.rangeHighlightBackground", defaults: .variants(dark: .css("#ffffff0b"), hcDark: .none, hcLight: .none, light: .css("#fdff0033")), needsTransparency: true),
        MonaColorEntry(id: "editor.rangeHighlightBorder", defaults: .variants(dark: .none, hcDark: .reference("contrastActiveBorder"), hcLight: .reference("contrastActiveBorder"), light: .none), needsTransparency: false),
        MonaColorEntry(id: "editor.selectionBackground", defaults: .variants(dark: .css("#264F78"), hcDark: .css("#f3f518"), hcLight: .css("#0F4A85"), light: .css("#ADD6FF")), needsTransparency: false),
        MonaColorEntry(id: "editor.selectionForeground", defaults: .variants(dark: .none, hcDark: .css("#000000"), hcLight: .css("#ffffff"), light: .none), needsTransparency: false),
        MonaColorEntry(id: "editor.selectionHighlightBackground", defaults: .variants(dark: .transform(.init(kind: 5, factor: 0.3, value: .reference("editor.selectionBackground"))), hcDark: .none, hcLight: .none, light: .transform(.init(kind: 5, factor: 0.3, value: .reference("editor.selectionBackground")))), needsTransparency: true),
        MonaColorEntry(id: "editor.selectionHighlightBorder", defaults: .variants(dark: .none, hcDark: .reference("contrastActiveBorder"), hcLight: .reference("contrastActiveBorder"), light: .none), needsTransparency: false),
        MonaColorEntry(id: "editor.snippetFinalTabstopHighlightBackground", defaults: .all(.none), needsTransparency: false),
        MonaColorEntry(id: "editor.snippetFinalTabstopHighlightBorder", defaults: .variants(dark: .css("#525252"), hcDark: .css("#525252"), hcLight: .css("#292929"), light: .css("rgba(10, 50, 100, 0.5)")), needsTransparency: false),
        MonaColorEntry(id: "editor.snippetTabstopHighlightBackground", defaults: .variants(dark: .rgba(r: 124, g: 124, b: 124, a: 0.3), hcDark: .rgba(r: 124, g: 124, b: 124, a: 0.3), hcLight: .rgba(r: 10, g: 50, b: 100, a: 0.2), light: .css("rgba(10, 50, 100, 0.2)")), needsTransparency: false),
        MonaColorEntry(id: "editor.snippetTabstopHighlightBorder", defaults: .all(.none), needsTransparency: false),
        MonaColorEntry(id: "editor.symbolHighlightBackground", defaults: .variants(dark: .reference("editor.findMatchHighlightBackground"), hcDark: .none, hcLight: .none, light: .reference("editor.findMatchHighlightBackground")), needsTransparency: true),
        MonaColorEntry(id: "editor.symbolHighlightBorder", defaults: .variants(dark: .none, hcDark: .reference("contrastActiveBorder"), hcLight: .reference("contrastActiveBorder"), light: .none), needsTransparency: false),
        MonaColorEntry(id: "editor.wordHighlightBackground", defaults: .variants(dark: .css("#575757B8"), hcDark: .none, hcLight: .none, light: .css("#57575740")), needsTransparency: true),
        MonaColorEntry(id: "editor.wordHighlightBorder", defaults: .variants(dark: .none, hcDark: .reference("contrastActiveBorder"), hcLight: .reference("contrastActiveBorder"), light: .none), needsTransparency: false),
        MonaColorEntry(id: "editor.wordHighlightStrongBackground", defaults: .variants(dark: .css("#004972B8"), hcDark: .none, hcLight: .none, light: .css("#0e639c40")), needsTransparency: true),
        MonaColorEntry(id: "editor.wordHighlightStrongBorder", defaults: .variants(dark: .none, hcDark: .reference("contrastActiveBorder"), hcLight: .reference("contrastActiveBorder"), light: .none), needsTransparency: false),
        MonaColorEntry(id: "editor.wordHighlightTextBackground", defaults: .all(.reference("editor.wordHighlightBackground")), needsTransparency: true),
        MonaColorEntry(id: "editor.wordHighlightTextBorder", defaults: .all(.reference("editor.wordHighlightBorder")), needsTransparency: false),
        MonaColorEntry(id: "editorActionList.background", defaults: .all(.reference("editorWidget.background")), needsTransparency: false),
        MonaColorEntry(id: "editorActionList.focusBackground", defaults: .all(.reference("list.activeSelectionBackground")), needsTransparency: false),
        MonaColorEntry(id: "editorActionList.focusForeground", defaults: .all(.reference("list.activeSelectionForeground")), needsTransparency: false),
        MonaColorEntry(id: "editorActionList.foreground", defaults: .all(.reference("editorWidget.foreground")), needsTransparency: false),
        MonaColorEntry(id: "editorActiveLineNumber.foreground", defaults: .variants(dark: .css("#c6c6c6"), hcDark: .reference("contrastActiveBorder"), hcLight: .reference("contrastActiveBorder"), light: .css("#0B216F")), needsTransparency: false),
        MonaColorEntry(id: "editorBracketHighlight.foreground1", defaults: .variants(dark: .css("#FFD700"), hcDark: .css("#FFD700"), hcLight: .css("#0431FAFF"), light: .css("#0431FAFF")), needsTransparency: false),
        MonaColorEntry(id: "editorBracketHighlight.foreground2", defaults: .variants(dark: .css("#DA70D6"), hcDark: .css("#DA70D6"), hcLight: .css("#319331FF"), light: .css("#319331FF")), needsTransparency: false),
        MonaColorEntry(id: "editorBracketHighlight.foreground3", defaults: .variants(dark: .css("#179FFF"), hcDark: .css("#87CEFA"), hcLight: .css("#7B3814FF"), light: .css("#7B3814FF")), needsTransparency: false),
        MonaColorEntry(id: "editorBracketHighlight.foreground4", defaults: .all(.css("#00000000")), needsTransparency: false),
        MonaColorEntry(id: "editorBracketHighlight.foreground5", defaults: .all(.css("#00000000")), needsTransparency: false),
        MonaColorEntry(id: "editorBracketHighlight.foreground6", defaults: .all(.css("#00000000")), needsTransparency: false),
        MonaColorEntry(id: "editorBracketHighlight.unexpectedBracket.foreground", defaults: .variants(dark: .rgba(r: 255, g: 18, b: 18, a: 0.8), hcDark: .rgba(r: 255, g: 50, b: 50, a: 1.0), hcLight: .css("#B5200D"), light: .css("rgba(255, 18, 18, 0.8)")), needsTransparency: false),
        MonaColorEntry(id: "editorBracketMatch.background", defaults: .variants(dark: .css("#0064001a"), hcDark: .css("#0064001a"), hcLight: .css("#0000"), light: .css("#0064001a")), needsTransparency: false),
        MonaColorEntry(id: "editorBracketMatch.border", defaults: .variants(dark: .css("#888"), hcDark: .reference("contrastBorder"), hcLight: .reference("contrastBorder"), light: .css("#B9B9B9")), needsTransparency: false),
        MonaColorEntry(id: "editorBracketMatch.foreground", defaults: .all(.none), needsTransparency: false),
        MonaColorEntry(id: "editorBracketPairGuide.activeBackground1", defaults: .all(.css("#00000000")), needsTransparency: false),
        MonaColorEntry(id: "editorBracketPairGuide.activeBackground2", defaults: .all(.css("#00000000")), needsTransparency: false),
        MonaColorEntry(id: "editorBracketPairGuide.activeBackground3", defaults: .all(.css("#00000000")), needsTransparency: false),
        MonaColorEntry(id: "editorBracketPairGuide.activeBackground4", defaults: .all(.css("#00000000")), needsTransparency: false),
        MonaColorEntry(id: "editorBracketPairGuide.activeBackground5", defaults: .all(.css("#00000000")), needsTransparency: false),
        MonaColorEntry(id: "editorBracketPairGuide.activeBackground6", defaults: .all(.css("#00000000")), needsTransparency: false),
        MonaColorEntry(id: "editorBracketPairGuide.background1", defaults: .all(.css("#00000000")), needsTransparency: false),
        MonaColorEntry(id: "editorBracketPairGuide.background2", defaults: .all(.css("#00000000")), needsTransparency: false),
        MonaColorEntry(id: "editorBracketPairGuide.background3", defaults: .all(.css("#00000000")), needsTransparency: false),
        MonaColorEntry(id: "editorBracketPairGuide.background4", defaults: .all(.css("#00000000")), needsTransparency: false),
        MonaColorEntry(id: "editorBracketPairGuide.background5", defaults: .all(.css("#00000000")), needsTransparency: false),
        MonaColorEntry(id: "editorBracketPairGuide.background6", defaults: .all(.css("#00000000")), needsTransparency: false),
        MonaColorEntry(id: "editorCodeLens.foreground", defaults: .variants(dark: .css("#999999"), hcDark: .css("#999999"), hcLight: .css("#292929"), light: .css("#919191")), needsTransparency: false),
        MonaColorEntry(id: "editorCursor.background", defaults: .all(.none), needsTransparency: false),
        MonaColorEntry(id: "editorCursor.foreground", defaults: .variants(dark: .css("#AEAFAD"), hcDark: .css("#ffffff"), hcLight: .css("#0F4A85"), light: .css("#000000")), needsTransparency: false),
        MonaColorEntry(id: "editorError.background", defaults: .all(.none), needsTransparency: true),
        MonaColorEntry(id: "editorError.border", defaults: .variants(dark: .none, hcDark: .rgba(r: 228, g: 119, b: 119, a: 0.8), hcLight: .css("#B5200D"), light: .none), needsTransparency: false),
        MonaColorEntry(id: "editorError.foreground", defaults: .variants(dark: .css("#F14C4C"), hcDark: .css("#F48771"), hcLight: .css("#B5200D"), light: .css("#E51400")), needsTransparency: false),
        MonaColorEntry(id: "editorGhostText.background", defaults: .all(.none), needsTransparency: false),
        MonaColorEntry(id: "editorGhostText.border", defaults: .variants(dark: .none, hcDark: .rgba(r: 255, g: 255, b: 255, a: 0.8), hcLight: .rgba(r: 41, g: 41, b: 41, a: 0.8), light: .none), needsTransparency: false),
        MonaColorEntry(id: "editorGhostText.foreground", defaults: .variants(dark: .rgba(r: 255, g: 255, b: 255, a: 0.337), hcDark: .none, hcLight: .none, light: .css("rgba(0, 0, 0, 0.47)")), needsTransparency: false),
        MonaColorEntry(id: "editorGutter.background", defaults: .all(.reference("editor.background")), needsTransparency: false),
        MonaColorEntry(id: "editorGutter.foldingControlForeground", defaults: .all(.reference("icon.foreground")), needsTransparency: false),
        MonaColorEntry(id: "editorHint.border", defaults: .variants(dark: .none, hcDark: .rgba(r: 238, g: 238, b: 238, a: 0.8), hcLight: .css("#292929"), light: .none), needsTransparency: false),
        MonaColorEntry(id: "editorHint.foreground", defaults: .variants(dark: .rgba(r: 238, g: 238, b: 238, a: 0.7), hcDark: .none, hcLight: .none, light: .css("#6c6c6c")), needsTransparency: false),
        MonaColorEntry(id: "editorHoverWidget.background", defaults: .all(.reference("editorWidget.background")), needsTransparency: false),
        MonaColorEntry(id: "editorHoverWidget.border", defaults: .all(.reference("editorWidget.border")), needsTransparency: false),
        MonaColorEntry(id: "editorHoverWidget.foreground", defaults: .all(.reference("editorWidget.foreground")), needsTransparency: false),
        MonaColorEntry(id: "editorHoverWidget.highlightForeground", defaults: .all(.reference("list.highlightForeground")), needsTransparency: false),
        MonaColorEntry(id: "editorHoverWidget.statusBarBackground", defaults: .variants(dark: .transform(.init(kind: 1, factor: 0.2, value: .reference("editorHoverWidget.background"))), hcDark: .reference("editorWidget.background"), hcLight: .reference("editorWidget.background"), light: .transform(.init(kind: 0, factor: 0.05, value: .reference("editorHoverWidget.background")))), needsTransparency: false),
        MonaColorEntry(id: "editorIndentGuide.activeBackground", defaults: .all(.reference("editorWhitespace.foreground")), needsTransparency: false),
        MonaColorEntry(id: "editorIndentGuide.activeBackground1", defaults: .all(.reference("editorIndentGuide.activeBackground")), needsTransparency: false),
        MonaColorEntry(id: "editorIndentGuide.activeBackground2", defaults: .all(.css("#00000000")), needsTransparency: false),
        MonaColorEntry(id: "editorIndentGuide.activeBackground3", defaults: .all(.css("#00000000")), needsTransparency: false),
        MonaColorEntry(id: "editorIndentGuide.activeBackground4", defaults: .all(.css("#00000000")), needsTransparency: false),
        MonaColorEntry(id: "editorIndentGuide.activeBackground5", defaults: .all(.css("#00000000")), needsTransparency: false),
        MonaColorEntry(id: "editorIndentGuide.activeBackground6", defaults: .all(.css("#00000000")), needsTransparency: false),
        MonaColorEntry(id: "editorIndentGuide.background", defaults: .all(.reference("editorWhitespace.foreground")), needsTransparency: false),
        MonaColorEntry(id: "editorIndentGuide.background1", defaults: .all(.reference("editorIndentGuide.background")), needsTransparency: false),
        MonaColorEntry(id: "editorIndentGuide.background2", defaults: .all(.css("#00000000")), needsTransparency: false),
        MonaColorEntry(id: "editorIndentGuide.background3", defaults: .all(.css("#00000000")), needsTransparency: false),
        MonaColorEntry(id: "editorIndentGuide.background4", defaults: .all(.css("#00000000")), needsTransparency: false),
        MonaColorEntry(id: "editorIndentGuide.background5", defaults: .all(.css("#00000000")), needsTransparency: false),
        MonaColorEntry(id: "editorIndentGuide.background6", defaults: .all(.css("#00000000")), needsTransparency: false),
        MonaColorEntry(id: "editorInfo.background", defaults: .all(.none), needsTransparency: true),
        MonaColorEntry(id: "editorInfo.border", defaults: .variants(dark: .none, hcDark: .rgba(r: 89, g: 164, b: 249, a: 0.8), hcLight: .css("#292929"), light: .none), needsTransparency: false),
        MonaColorEntry(id: "editorInfo.foreground", defaults: .variants(dark: .css("#59a4f9"), hcDark: .css("#59a4f9"), hcLight: .css("#0063d3"), light: .css("#0063d3")), needsTransparency: false),
        MonaColorEntry(id: "editorInlayHint.background", defaults: .variants(dark: .transform(.init(kind: 2, factor: 0.1, value: .reference("badge.background"))), hcDark: .transform(.init(kind: 2, factor: 0.1, value: .css("#ffffff"))), hcLight: .transform(.init(kind: 2, factor: 0.1, value: .reference("badge.background"))), light: .transform(.init(kind: 2, factor: 0.1, value: .reference("badge.background")))), needsTransparency: false),
        MonaColorEntry(id: "editorInlayHint.foreground", defaults: .variants(dark: .css("#969696"), hcDark: .css("#ffffff"), hcLight: .css("#000000"), light: .css("#969696")), needsTransparency: false),
        MonaColorEntry(id: "editorInlayHint.parameterBackground", defaults: .all(.reference("editorInlayHint.background")), needsTransparency: false),
        MonaColorEntry(id: "editorInlayHint.parameterForeground", defaults: .all(.reference("editorInlayHint.foreground")), needsTransparency: false),
        MonaColorEntry(id: "editorInlayHint.typeBackground", defaults: .all(.reference("editorInlayHint.background")), needsTransparency: false),
        MonaColorEntry(id: "editorInlayHint.typeForeground", defaults: .all(.reference("editorInlayHint.foreground")), needsTransparency: false),
        MonaColorEntry(id: "editorLightBulb.foreground", defaults: .variants(dark: .css("#FFCC00"), hcDark: .css("#FFCC00"), hcLight: .css("#007ACC"), light: .css("#DDB100")), needsTransparency: false),
        MonaColorEntry(id: "editorLightBulbAi.foreground", defaults: .all(.reference("editorLightBulb.foreground")), needsTransparency: false),
        MonaColorEntry(id: "editorLightBulbAutoFix.foreground", defaults: .variants(dark: .css("#75BEFF"), hcDark: .css("#75BEFF"), hcLight: .css("#007ACC"), light: .css("#007ACC")), needsTransparency: false),
        MonaColorEntry(id: "editorLineNumber.activeForeground", defaults: .all(.reference("editorActiveLineNumber.foreground")), needsTransparency: false),
        MonaColorEntry(id: "editorLineNumber.dimmedForeground", defaults: .all(.none), needsTransparency: false),
        MonaColorEntry(id: "editorLineNumber.foreground", defaults: .variants(dark: .css("#858585"), hcDark: .css("#ffffff"), hcLight: .css("#292929"), light: .css("#237893")), needsTransparency: false),
        MonaColorEntry(id: "editorLink.activeForeground", defaults: .variants(dark: .css("#4E94CE"), hcDark: .rgba(r: 0, g: 255, b: 255, a: 1.0), hcLight: .css("#292929"), light: .css("#0000ff")), needsTransparency: false),
        MonaColorEntry(id: "editorMarkerNavigation.background", defaults: .all(.reference("editor.background")), needsTransparency: false),
        MonaColorEntry(id: "editorMarkerNavigationError.background", defaults: .variants(dark: .transform(.init(kind: 4, values: [.reference("editorError.foreground"), .reference("editorError.border")])), hcDark: .reference("contrastBorder"), hcLight: .reference("contrastBorder"), light: .transform(.init(kind: 4, values: [.reference("editorError.foreground"), .reference("editorError.border")]))), needsTransparency: false),
        MonaColorEntry(id: "editorMarkerNavigationError.headerBackground", defaults: .variants(dark: .transform(.init(kind: 2, factor: 0.1, value: .reference("editorMarkerNavigationError.background"))), hcDark: .none, hcLight: .none, light: .transform(.init(kind: 2, factor: 0.1, value: .reference("editorMarkerNavigationError.background")))), needsTransparency: false),
        MonaColorEntry(id: "editorMarkerNavigationInfo.background", defaults: .variants(dark: .transform(.init(kind: 4, values: [.reference("editorInfo.foreground"), .reference("editorInfo.border")])), hcDark: .reference("contrastBorder"), hcLight: .reference("contrastBorder"), light: .transform(.init(kind: 4, values: [.reference("editorInfo.foreground"), .reference("editorInfo.border")]))), needsTransparency: false),
        MonaColorEntry(id: "editorMarkerNavigationInfo.headerBackground", defaults: .variants(dark: .transform(.init(kind: 2, factor: 0.1, value: .reference("editorMarkerNavigationInfo.background"))), hcDark: .none, hcLight: .none, light: .transform(.init(kind: 2, factor: 0.1, value: .reference("editorMarkerNavigationInfo.background")))), needsTransparency: false),
        MonaColorEntry(id: "editorMarkerNavigationWarning.background", defaults: .variants(dark: .transform(.init(kind: 4, values: [.reference("editorWarning.foreground"), .reference("editorWarning.border")])), hcDark: .reference("contrastBorder"), hcLight: .reference("contrastBorder"), light: .transform(.init(kind: 4, values: [.reference("editorWarning.foreground"), .reference("editorWarning.border")]))), needsTransparency: false),
        MonaColorEntry(id: "editorMarkerNavigationWarning.headerBackground", defaults: .variants(dark: .transform(.init(kind: 2, factor: 0.1, value: .reference("editorMarkerNavigationWarning.background"))), hcDark: .css("#0C141F"), hcLight: .transform(.init(kind: 2, factor: 0.2, value: .reference("editorMarkerNavigationWarning.background"))), light: .transform(.init(kind: 2, factor: 0.1, value: .reference("editorMarkerNavigationWarning.background")))), needsTransparency: false),
        MonaColorEntry(id: "editorMultiCursor.primary.background", defaults: .all(.reference("editorCursor.background")), needsTransparency: false),
        MonaColorEntry(id: "editorMultiCursor.primary.foreground", defaults: .all(.reference("editorCursor.foreground")), needsTransparency: false),
        MonaColorEntry(id: "editorMultiCursor.secondary.background", defaults: .all(.reference("editorCursor.background")), needsTransparency: false),
        MonaColorEntry(id: "editorMultiCursor.secondary.foreground", defaults: .all(.reference("editorCursor.foreground")), needsTransparency: false),
        MonaColorEntry(id: "editorOverviewRuler.background", defaults: .all(.none), needsTransparency: false),
        MonaColorEntry(id: "editorOverviewRuler.border", defaults: .variants(dark: .css("#7f7f7f4d"), hcDark: .css("#7f7f7f4d"), hcLight: .css("#666666"), light: .css("#7f7f7f4d")), needsTransparency: false),
        MonaColorEntry(id: "editorOverviewRuler.bracketMatchForeground", defaults: .all(.css("#A0A0A0")), needsTransparency: false),
        MonaColorEntry(id: "editorOverviewRuler.commonContentForeground", defaults: .variants(dark: .transform(.init(kind: 2, factor: 1, value: .reference("merge.commonHeaderBackground"))), hcDark: .reference("merge.border"), hcLight: .reference("merge.border"), light: .transform(.init(kind: 2, factor: 1, value: .reference("merge.commonHeaderBackground")))), needsTransparency: false),
        MonaColorEntry(id: "editorOverviewRuler.currentContentForeground", defaults: .variants(dark: .transform(.init(kind: 2, factor: 1, value: .reference("merge.currentHeaderBackground"))), hcDark: .reference("merge.border"), hcLight: .reference("merge.border"), light: .transform(.init(kind: 2, factor: 1, value: .reference("merge.currentHeaderBackground")))), needsTransparency: false),
        MonaColorEntry(id: "editorOverviewRuler.errorForeground", defaults: .variants(dark: .rgba(r: 255, g: 18, b: 18, a: 0.7), hcDark: .rgba(r: 255, g: 50, b: 50, a: 1.0), hcLight: .css("#B5200D"), light: .css("rgba(255, 18, 18, 0.7)")), needsTransparency: false),
        MonaColorEntry(id: "editorOverviewRuler.findMatchForeground", defaults: .variants(dark: .css("#d186167e"), hcDark: .css("#AB5A00"), hcLight: .css("#AB5A00"), light: .css("#d186167e")), needsTransparency: true),
        MonaColorEntry(id: "editorOverviewRuler.incomingContentForeground", defaults: .variants(dark: .transform(.init(kind: 2, factor: 1, value: .reference("merge.incomingHeaderBackground"))), hcDark: .reference("merge.border"), hcLight: .reference("merge.border"), light: .transform(.init(kind: 2, factor: 1, value: .reference("merge.incomingHeaderBackground")))), needsTransparency: false),
        MonaColorEntry(id: "editorOverviewRuler.infoForeground", defaults: .variants(dark: .reference("editorInfo.foreground"), hcDark: .reference("editorInfo.border"), hcLight: .reference("editorInfo.border"), light: .reference("editorInfo.foreground")), needsTransparency: false),
        MonaColorEntry(id: "editorOverviewRuler.rangeHighlightForeground", defaults: .all(.css("rgba(0, 122, 204, 0.6)")), needsTransparency: true),
        MonaColorEntry(id: "editorOverviewRuler.selectionHighlightForeground", defaults: .all(.css("#A0A0A0CC")), needsTransparency: true),
        MonaColorEntry(id: "editorOverviewRuler.warningForeground", defaults: .variants(dark: .reference("editorWarning.foreground"), hcDark: .reference("editorWarning.border"), hcLight: .reference("editorWarning.border"), light: .reference("editorWarning.foreground")), needsTransparency: false),
        MonaColorEntry(id: "editorOverviewRuler.wordHighlightForeground", defaults: .all(.css("#A0A0A0CC")), needsTransparency: true),
        MonaColorEntry(id: "editorOverviewRuler.wordHighlightStrongForeground", defaults: .all(.css("#C0A0C0CC")), needsTransparency: true),
        MonaColorEntry(id: "editorOverviewRuler.wordHighlightTextForeground", defaults: .all(.reference("editorOverviewRuler.selectionHighlightForeground")), needsTransparency: true),
        MonaColorEntry(id: "editorRuler.foreground", defaults: .variants(dark: .css("#5A5A5A"), hcDark: .css("#ffffff"), hcLight: .css("#292929"), light: .css("#d3d3d3")), needsTransparency: false),
        MonaColorEntry(id: "editorStickyScroll.background", defaults: .all(.reference("editor.background")), needsTransparency: false),
        MonaColorEntry(id: "editorStickyScroll.border", defaults: .variants(dark: .none, hcDark: .reference("contrastBorder"), hcLight: .reference("contrastBorder"), light: .none), needsTransparency: false),
        MonaColorEntry(id: "editorStickyScroll.shadow", defaults: .all(.reference("scrollbar.shadow")), needsTransparency: false),
        MonaColorEntry(id: "editorStickyScrollGutter.background", defaults: .all(.reference("editor.background")), needsTransparency: false),
        MonaColorEntry(id: "editorStickyScrollHover.background", defaults: .variants(dark: .css("#2A2D2E"), hcDark: .none, hcLight: .rgba(r: 15, g: 74, b: 133, a: 0.1), light: .css("#F0F0F0")), needsTransparency: false),
        MonaColorEntry(id: "editorSuggestWidget.background", defaults: .all(.reference("editorWidget.background")), needsTransparency: false),
        MonaColorEntry(id: "editorSuggestWidget.border", defaults: .all(.reference("editorWidget.border")), needsTransparency: false),
        MonaColorEntry(id: "editorSuggestWidget.focusHighlightForeground", defaults: .all(.reference("list.focusHighlightForeground")), needsTransparency: false),
        MonaColorEntry(id: "editorSuggestWidget.foreground", defaults: .all(.reference("editor.foreground")), needsTransparency: false),
        MonaColorEntry(id: "editorSuggestWidget.highlightForeground", defaults: .all(.reference("list.highlightForeground")), needsTransparency: false),
        MonaColorEntry(id: "editorSuggestWidget.selectedBackground", defaults: .all(.reference("quickInputList.focusBackground")), needsTransparency: false),
        MonaColorEntry(id: "editorSuggestWidget.selectedForeground", defaults: .all(.reference("quickInputList.focusForeground")), needsTransparency: false),
        MonaColorEntry(id: "editorSuggestWidget.selectedIconForeground", defaults: .all(.reference("quickInputList.focusIconForeground")), needsTransparency: false),
        MonaColorEntry(id: "editorSuggestWidgetStatus.foreground", defaults: .all(.transform(.init(kind: 2, factor: 0.5, value: .reference("editorSuggestWidget.foreground")))), needsTransparency: false),
        MonaColorEntry(id: "editorUnicodeHighlight.background", defaults: .all(.reference("editorWarning.background")), needsTransparency: false),
        MonaColorEntry(id: "editorUnicodeHighlight.border", defaults: .all(.reference("editorWarning.foreground")), needsTransparency: false),
        MonaColorEntry(id: "editorUnnecessaryCode.border", defaults: .variants(dark: .none, hcDark: .rgba(r: 255, g: 255, b: 255, a: 0.8), hcLight: .reference("contrastBorder"), light: .none), needsTransparency: false),
        MonaColorEntry(id: "editorUnnecessaryCode.opacity", defaults: .variants(dark: .rgba(r: 0, g: 0, b: 0, a: 0.667), hcDark: .none, hcLight: .none, light: .css("rgba(0, 0, 0, 0.47)")), needsTransparency: false),
        MonaColorEntry(id: "editorWarning.background", defaults: .all(.none), needsTransparency: true),
        MonaColorEntry(id: "editorWarning.border", defaults: .variants(dark: .none, hcDark: .rgba(r: 255, g: 204, b: 0, a: 0.8), hcLight: .rgba(r: 255, g: 204, b: 0, a: 0.8), light: .none), needsTransparency: false),
        MonaColorEntry(id: "editorWarning.foreground", defaults: .variants(dark: .css("#CCA700"), hcDark: .css("#FFD370"), hcLight: .css("#895503"), light: .css("#BF8803")), needsTransparency: false),
        MonaColorEntry(id: "editorWhitespace.foreground", defaults: .variants(dark: .css("#e3e4e229"), hcDark: .css("#e3e4e229"), hcLight: .css("#CCCCCC"), light: .css("#33333333")), needsTransparency: false),
        MonaColorEntry(id: "editorWidget.background", defaults: .variants(dark: .css("#252526"), hcDark: .css("#0C141F"), hcLight: .css("#ffffff"), light: .css("#F3F3F3")), needsTransparency: false),
        MonaColorEntry(id: "editorWidget.border", defaults: .variants(dark: .transform(.init(kind: 2, factor: 0.2, value: .reference("editorWidget.foreground"))), hcDark: .reference("contrastBorder"), hcLight: .reference("contrastBorder"), light: .transform(.init(kind: 2, factor: 0.2, value: .reference("editorWidget.foreground")))), needsTransparency: false),
        MonaColorEntry(id: "editorWidget.foreground", defaults: .all(.reference("foreground")), needsTransparency: false),
        MonaColorEntry(id: "editorWidget.resizeBorder", defaults: .all(.none), needsTransparency: false),
        MonaColorEntry(id: "errorForeground", defaults: .variants(dark: .css("#F48771"), hcDark: .css("#F48771"), hcLight: .css("#B5200D"), light: .css("#A1260D")), needsTransparency: false),
        MonaColorEntry(id: "focusBorder", defaults: .variants(dark: .css("#007FD4"), hcDark: .css("#F38518"), hcLight: .css("#006BBD"), light: .css("#0090F1")), needsTransparency: false),
        MonaColorEntry(id: "foreground", defaults: .variants(dark: .css("#CCCCCC"), hcDark: .css("#FFFFFF"), hcLight: .css("#292929"), light: .css("#616161")), needsTransparency: false),
        MonaColorEntry(id: "icon.foreground", defaults: .variants(dark: .css("#C5C5C5"), hcDark: .css("#FFFFFF"), hcLight: .css("#292929"), light: .css("#424242")), needsTransparency: false),
        MonaColorEntry(id: "inlineEdit.gutterIndicator.background", defaults: .variants(dark: .transform(.init(kind: 2, factor: 0.5, value: .reference("tab.inactiveBackground"))), hcDark: .transform(.init(kind: 2, factor: 0.5, value: .reference("tab.inactiveBackground"))), hcLight: .transform(.init(kind: 2, factor: 0.5, value: .reference("tab.inactiveBackground"))), light: .css("#5f5f5f18")), needsTransparency: false),
        MonaColorEntry(id: "inlineEdit.gutterIndicator.primaryBackground", defaults: .variants(dark: .transform(.init(kind: 2, factor: 0.4, value: .reference("inlineEdit.gutterIndicator.primaryBorder"))), hcDark: .transform(.init(kind: 2, factor: 0.4, value: .reference("inlineEdit.gutterIndicator.primaryBorder"))), hcLight: .transform(.init(kind: 2, factor: 0.5, value: .reference("inlineEdit.gutterIndicator.primaryBorder"))), light: .transform(.init(kind: 2, factor: 0.5, value: .reference("inlineEdit.gutterIndicator.primaryBorder")))), needsTransparency: false),
        MonaColorEntry(id: "inlineEdit.gutterIndicator.primaryBorder", defaults: .all(.reference("button.background")), needsTransparency: false),
        MonaColorEntry(id: "inlineEdit.gutterIndicator.primaryForeground", defaults: .all(.reference("button.foreground")), needsTransparency: false),
        MonaColorEntry(id: "inlineEdit.gutterIndicator.secondaryBackground", defaults: .all(.reference("editorHoverWidget.background")), needsTransparency: false),
        MonaColorEntry(id: "inlineEdit.gutterIndicator.secondaryBorder", defaults: .all(.reference("editorHoverWidget.border")), needsTransparency: false),
        MonaColorEntry(id: "inlineEdit.gutterIndicator.secondaryForeground", defaults: .all(.reference("editorHoverWidget.foreground")), needsTransparency: false),
        MonaColorEntry(id: "inlineEdit.gutterIndicator.successfulBackground", defaults: .all(.reference("inlineEdit.gutterIndicator.successfulBorder")), needsTransparency: false),
        MonaColorEntry(id: "inlineEdit.gutterIndicator.successfulBorder", defaults: .all(.reference("button.background")), needsTransparency: false),
        MonaColorEntry(id: "inlineEdit.gutterIndicator.successfulForeground", defaults: .all(.reference("button.foreground")), needsTransparency: false),
        MonaColorEntry(id: "inlineEdit.modifiedBackground", defaults: .all(.transform(.init(kind: 2, factor: 0.3, value: .reference("diffEditor.insertedTextBackground")))), needsTransparency: true),
        MonaColorEntry(id: "inlineEdit.modifiedBorder", defaults: .variants(dark: .reference("diffEditor.insertedTextBackground"), hcDark: .reference("diffEditor.insertedTextBackground"), hcLight: .reference("diffEditor.insertedTextBackground"), light: .transform(.init(kind: 0, factor: 0.6, value: .reference("diffEditor.insertedTextBackground")))), needsTransparency: false),
        MonaColorEntry(id: "inlineEdit.modifiedChangedLineBackground", defaults: .variants(dark: .transform(.init(kind: 2, factor: 0.7, value: .reference("diffEditor.insertedLineBackground"))), hcDark: .reference("diffEditor.insertedLineBackground"), hcLight: .reference("diffEditor.insertedLineBackground"), light: .transform(.init(kind: 2, factor: 0.7, value: .reference("diffEditor.insertedLineBackground")))), needsTransparency: true),
        MonaColorEntry(id: "inlineEdit.modifiedChangedTextBackground", defaults: .all(.transform(.init(kind: 2, factor: 0.7, value: .reference("diffEditor.insertedTextBackground")))), needsTransparency: true),
        MonaColorEntry(id: "inlineEdit.originalBackground", defaults: .all(.transform(.init(kind: 2, factor: 0.2, value: .reference("diffEditor.removedTextBackground")))), needsTransparency: true),
        MonaColorEntry(id: "inlineEdit.originalBorder", defaults: .variants(dark: .reference("diffEditor.removedTextBackground"), hcDark: .reference("diffEditor.removedTextBackground"), hcLight: .reference("diffEditor.removedTextBackground"), light: .reference("diffEditor.removedTextBackground")), needsTransparency: false),
        MonaColorEntry(id: "inlineEdit.originalChangedLineBackground", defaults: .all(.transform(.init(kind: 2, factor: 0.8, value: .reference("diffEditor.removedTextBackground")))), needsTransparency: true),
        MonaColorEntry(id: "inlineEdit.originalChangedTextBackground", defaults: .all(.transform(.init(kind: 2, factor: 0.8, value: .reference("diffEditor.removedTextBackground")))), needsTransparency: true),
        MonaColorEntry(id: "inlineEdit.tabWillAcceptModifiedBorder", defaults: .variants(dark: .transform(.init(kind: 0, factor: 0, value: .reference("inlineEdit.modifiedBorder"))), hcDark: .transform(.init(kind: 0, factor: 0, value: .reference("inlineEdit.modifiedBorder"))), hcLight: .transform(.init(kind: 0, factor: 0, value: .reference("inlineEdit.modifiedBorder"))), light: .transform(.init(kind: 0, factor: 0, value: .reference("inlineEdit.modifiedBorder")))), needsTransparency: false),
        MonaColorEntry(id: "inlineEdit.tabWillAcceptOriginalBorder", defaults: .variants(dark: .transform(.init(kind: 0, factor: 0, value: .reference("inlineEdit.originalBorder"))), hcDark: .transform(.init(kind: 0, factor: 0, value: .reference("inlineEdit.originalBorder"))), hcLight: .transform(.init(kind: 0, factor: 0, value: .reference("inlineEdit.originalBorder"))), light: .transform(.init(kind: 0, factor: 0, value: .reference("inlineEdit.originalBorder")))), needsTransparency: false),
        MonaColorEntry(id: "input.background", defaults: .variants(dark: .css("#3C3C3C"), hcDark: .css("#000000"), hcLight: .css("#ffffff"), light: .css("#ffffff")), needsTransparency: false),
        MonaColorEntry(id: "input.border", defaults: .variants(dark: .none, hcDark: .reference("contrastBorder"), hcLight: .reference("contrastBorder"), light: .none), needsTransparency: false),
        MonaColorEntry(id: "input.foreground", defaults: .all(.reference("foreground")), needsTransparency: false),
        MonaColorEntry(id: "input.placeholderForeground", defaults: .variants(dark: .transform(.init(kind: 2, factor: 0.5, value: .reference("foreground"))), hcDark: .transform(.init(kind: 2, factor: 0.7, value: .reference("foreground"))), hcLight: .transform(.init(kind: 2, factor: 0.7, value: .reference("foreground"))), light: .transform(.init(kind: 2, factor: 0.5, value: .reference("foreground")))), needsTransparency: false),
        MonaColorEntry(id: "inputOption.activeBackground", defaults: .variants(dark: .transform(.init(kind: 2, factor: 0.4, value: .reference("focusBorder"))), hcDark: .css("rgba(0, 0, 0, 0)"), hcLight: .css("rgba(0, 0, 0, 0)"), light: .transform(.init(kind: 2, factor: 0.2, value: .reference("focusBorder")))), needsTransparency: false),
        MonaColorEntry(id: "inputOption.activeBorder", defaults: .variants(dark: .css("#007ACC"), hcDark: .reference("contrastBorder"), hcLight: .reference("contrastBorder"), light: .css("#007ACC")), needsTransparency: false),
        MonaColorEntry(id: "inputOption.activeForeground", defaults: .variants(dark: .css("#ffffff"), hcDark: .reference("foreground"), hcLight: .reference("foreground"), light: .css("#000000")), needsTransparency: false),
        MonaColorEntry(id: "inputOption.hoverBackground", defaults: .variants(dark: .css("#5a5d5e80"), hcDark: .none, hcLight: .none, light: .css("#b8b8b850")), needsTransparency: false),
        MonaColorEntry(id: "inputValidation.errorBackground", defaults: .variants(dark: .css("#5A1D1D"), hcDark: .css("#000000"), hcLight: .css("#ffffff"), light: .css("#F2DEDE")), needsTransparency: false),
        MonaColorEntry(id: "inputValidation.errorBorder", defaults: .variants(dark: .css("#BE1100"), hcDark: .reference("contrastBorder"), hcLight: .reference("contrastBorder"), light: .css("#BE1100")), needsTransparency: false),
        MonaColorEntry(id: "inputValidation.errorForeground", defaults: .variants(dark: .none, hcDark: .none, hcLight: .reference("foreground"), light: .none), needsTransparency: false),
        MonaColorEntry(id: "inputValidation.infoBackground", defaults: .variants(dark: .css("#063B49"), hcDark: .css("#000000"), hcLight: .css("#ffffff"), light: .css("#D6ECF2")), needsTransparency: false),
        MonaColorEntry(id: "inputValidation.infoBorder", defaults: .variants(dark: .css("#007acc"), hcDark: .reference("contrastBorder"), hcLight: .reference("contrastBorder"), light: .css("#007acc")), needsTransparency: false),
        MonaColorEntry(id: "inputValidation.infoForeground", defaults: .variants(dark: .none, hcDark: .none, hcLight: .reference("foreground"), light: .none), needsTransparency: false),
        MonaColorEntry(id: "inputValidation.warningBackground", defaults: .variants(dark: .css("#352A05"), hcDark: .css("#000000"), hcLight: .css("#ffffff"), light: .css("#F6F5D2")), needsTransparency: false),
        MonaColorEntry(id: "inputValidation.warningBorder", defaults: .variants(dark: .css("#B89500"), hcDark: .reference("contrastBorder"), hcLight: .reference("contrastBorder"), light: .css("#B89500")), needsTransparency: false),
        MonaColorEntry(id: "inputValidation.warningForeground", defaults: .variants(dark: .none, hcDark: .none, hcLight: .reference("foreground"), light: .none), needsTransparency: false),
        MonaColorEntry(id: "keybindingLabel.background", defaults: .variants(dark: .rgba(r: 128, g: 128, b: 128, a: 0.17), hcDark: .css("rgba(0, 0, 0, 0)"), hcLight: .css("rgba(0, 0, 0, 0)"), light: .css("rgba(221, 221, 221, 0.4)")), needsTransparency: false),
        MonaColorEntry(id: "keybindingLabel.border", defaults: .variants(dark: .rgba(r: 51, g: 51, b: 51, a: 0.6), hcDark: .rgba(r: 111, g: 195, b: 223, a: 1.0), hcLight: .reference("contrastBorder"), light: .css("rgba(204, 204, 204, 0.4)")), needsTransparency: false),
        MonaColorEntry(id: "keybindingLabel.bottomBorder", defaults: .variants(dark: .rgba(r: 68, g: 68, b: 68, a: 0.6), hcDark: .rgba(r: 111, g: 195, b: 223, a: 1.0), hcLight: .reference("foreground"), light: .css("rgba(187, 187, 187, 0.4)")), needsTransparency: false),
        MonaColorEntry(id: "keybindingLabel.foreground", defaults: .variants(dark: .rgba(r: 204, g: 204, b: 204, a: 1.0), hcDark: .css("#ffffff"), hcLight: .reference("foreground"), light: .css("#555555")), needsTransparency: false),
        MonaColorEntry(id: "list.activeSelectionBackground", defaults: .variants(dark: .css("#04395E"), hcDark: .none, hcLight: .rgba(r: 15, g: 74, b: 133, a: 0.1), light: .css("#0060C0")), needsTransparency: false),
        MonaColorEntry(id: "list.activeSelectionForeground", defaults: .variants(dark: .css("#ffffff"), hcDark: .none, hcLight: .none, light: .css("#ffffff")), needsTransparency: false),
        MonaColorEntry(id: "list.activeSelectionIconForeground", defaults: .all(.none), needsTransparency: false),
        MonaColorEntry(id: "list.deemphasizedForeground", defaults: .variants(dark: .css("#8C8C8C"), hcDark: .css("#A7A8A9"), hcLight: .css("#666666"), light: .css("#8E8E90")), needsTransparency: false),
        MonaColorEntry(id: "list.dropBackground", defaults: .variants(dark: .css("#062F4A"), hcDark: .none, hcLight: .none, light: .css("#D6EBFF")), needsTransparency: false),
        MonaColorEntry(id: "list.dropBetweenBackground", defaults: .variants(dark: .reference("icon.foreground"), hcDark: .none, hcLight: .none, light: .reference("icon.foreground")), needsTransparency: false),
        MonaColorEntry(id: "list.errorForeground", defaults: .variants(dark: .css("#F88070"), hcDark: .none, hcLight: .none, light: .css("#B01011")), needsTransparency: false),
        MonaColorEntry(id: "list.filterMatchBackground", defaults: .variants(dark: .reference("editor.findMatchHighlightBackground"), hcDark: .none, hcLight: .none, light: .reference("editor.findMatchHighlightBackground")), needsTransparency: false),
        MonaColorEntry(id: "list.filterMatchBorder", defaults: .variants(dark: .reference("editor.findMatchHighlightBorder"), hcDark: .reference("contrastBorder"), hcLight: .reference("contrastActiveBorder"), light: .reference("editor.findMatchHighlightBorder")), needsTransparency: false),
        MonaColorEntry(id: "list.focusAndSelectionOutline", defaults: .all(.none), needsTransparency: false),
        MonaColorEntry(id: "list.focusBackground", defaults: .all(.none), needsTransparency: false),
        MonaColorEntry(id: "list.focusForeground", defaults: .all(.none), needsTransparency: false),
        MonaColorEntry(id: "list.focusHighlightForeground", defaults: .variants(dark: .reference("list.highlightForeground"), hcDark: .reference("list.highlightForeground"), hcLight: .reference("list.highlightForeground"), light: .transform(.init(kind: 6, condition: .reference("list.activeSelectionBackground"), thenValue: .reference("list.highlightForeground"), elseValue: .css("#BBE7FF")))), needsTransparency: false),
        MonaColorEntry(id: "list.focusOutline", defaults: .variants(dark: .reference("focusBorder"), hcDark: .reference("contrastActiveBorder"), hcLight: .reference("contrastActiveBorder"), light: .reference("focusBorder")), needsTransparency: false),
        MonaColorEntry(id: "list.highlightForeground", defaults: .variants(dark: .css("#2AAAFF"), hcDark: .reference("focusBorder"), hcLight: .reference("focusBorder"), light: .css("#0066BF")), needsTransparency: false),
        MonaColorEntry(id: "list.hoverBackground", defaults: .variants(dark: .css("#2A2D2E"), hcDark: .rgba(r: 255, g: 255, b: 255, a: 0.1), hcLight: .rgba(r: 15, g: 74, b: 133, a: 0.1), light: .css("#F0F0F0")), needsTransparency: false),
        MonaColorEntry(id: "list.hoverForeground", defaults: .all(.none), needsTransparency: false),
        MonaColorEntry(id: "list.inactiveFocusBackground", defaults: .all(.none), needsTransparency: false),
        MonaColorEntry(id: "list.inactiveFocusOutline", defaults: .all(.none), needsTransparency: false),
        MonaColorEntry(id: "list.inactiveSelectionBackground", defaults: .variants(dark: .css("#37373D"), hcDark: .none, hcLight: .rgba(r: 15, g: 74, b: 133, a: 0.1), light: .css("#E4E6F1")), needsTransparency: false),
        MonaColorEntry(id: "list.inactiveSelectionForeground", defaults: .all(.none), needsTransparency: false),
        MonaColorEntry(id: "list.inactiveSelectionIconForeground", defaults: .all(.none), needsTransparency: false),
        MonaColorEntry(id: "list.invalidItemForeground", defaults: .variants(dark: .css("#B89500"), hcDark: .css("#B89500"), hcLight: .css("#B5200D"), light: .css("#B89500")), needsTransparency: false),
        MonaColorEntry(id: "list.warningForeground", defaults: .variants(dark: .css("#CCA700"), hcDark: .none, hcLight: .none, light: .css("#855F00")), needsTransparency: false),
        MonaColorEntry(id: "listFilterWidget.background", defaults: .variants(dark: .transform(.init(kind: 1, factor: 0, value: .reference("editorWidget.background"))), hcDark: .reference("editorWidget.background"), hcLight: .reference("editorWidget.background"), light: .transform(.init(kind: 0, factor: 0, value: .reference("editorWidget.background")))), needsTransparency: false),
        MonaColorEntry(id: "listFilterWidget.noMatchesOutline", defaults: .variants(dark: .css("#BE1100"), hcDark: .reference("contrastBorder"), hcLight: .reference("contrastBorder"), light: .css("#BE1100")), needsTransparency: false),
        MonaColorEntry(id: "listFilterWidget.outline", defaults: .variants(dark: .css("rgba(0, 0, 0, 0)"), hcDark: .css("#f38518"), hcLight: .css("#007ACC"), light: .css("rgba(0, 0, 0, 0)")), needsTransparency: false),
        MonaColorEntry(id: "listFilterWidget.shadow", defaults: .all(.reference("widget.shadow")), needsTransparency: false),
        MonaColorEntry(id: "menu.background", defaults: .all(.reference("dropdown.background")), needsTransparency: false),
        MonaColorEntry(id: "menu.border", defaults: .variants(dark: .none, hcDark: .reference("contrastBorder"), hcLight: .reference("contrastBorder"), light: .none), needsTransparency: false),
        MonaColorEntry(id: "menu.foreground", defaults: .all(.reference("dropdown.foreground")), needsTransparency: false),
        MonaColorEntry(id: "menu.selectionBackground", defaults: .all(.reference("list.activeSelectionBackground")), needsTransparency: false),
        MonaColorEntry(id: "menu.selectionBorder", defaults: .variants(dark: .none, hcDark: .reference("contrastActiveBorder"), hcLight: .reference("contrastActiveBorder"), light: .none), needsTransparency: false),
        MonaColorEntry(id: "menu.selectionForeground", defaults: .all(.reference("list.activeSelectionForeground")), needsTransparency: false),
        MonaColorEntry(id: "menu.separatorBackground", defaults: .variants(dark: .transform(.init(kind: 2, factor: 0.2, value: .reference("foreground"))), hcDark: .reference("contrastBorder"), hcLight: .reference("contrastBorder"), light: .transform(.init(kind: 2, factor: 0.2, value: .reference("foreground")))), needsTransparency: false),
        MonaColorEntry(id: "merge.border", defaults: .variants(dark: .none, hcDark: .css("#C3DF6F"), hcLight: .css("#007ACC"), light: .none), needsTransparency: false),
        MonaColorEntry(id: "merge.commonContentBackground", defaults: .all(.transform(.init(kind: 2, factor: 0.4, value: .reference("merge.commonHeaderBackground")))), needsTransparency: true),
        MonaColorEntry(id: "merge.commonHeaderBackground", defaults: .variants(dark: .css("rgba(96, 96, 96, 0.4)"), hcDark: .none, hcLight: .none, light: .css("rgba(96, 96, 96, 0.4)")), needsTransparency: true),
        MonaColorEntry(id: "merge.currentContentBackground", defaults: .all(.transform(.init(kind: 2, factor: 0.4, value: .reference("merge.currentHeaderBackground")))), needsTransparency: true),
        MonaColorEntry(id: "merge.currentHeaderBackground", defaults: .variants(dark: .css("rgba(64, 200, 174, 0.5)"), hcDark: .none, hcLight: .none, light: .css("rgba(64, 200, 174, 0.5)")), needsTransparency: true),
        MonaColorEntry(id: "merge.incomingContentBackground", defaults: .all(.transform(.init(kind: 2, factor: 0.4, value: .reference("merge.incomingHeaderBackground")))), needsTransparency: true),
        MonaColorEntry(id: "merge.incomingHeaderBackground", defaults: .variants(dark: .css("rgba(64, 166, 255, 0.5)"), hcDark: .none, hcLight: .none, light: .css("rgba(64, 166, 255, 0.5)")), needsTransparency: true),
        MonaColorEntry(id: "minimap.background", defaults: .all(.none), needsTransparency: false),
        MonaColorEntry(id: "minimap.errorHighlight", defaults: .variants(dark: .rgba(r: 255, g: 18, b: 18, a: 0.7), hcDark: .rgba(r: 255, g: 50, b: 50, a: 1.0), hcLight: .css("#B5200D"), light: .css("rgba(255, 18, 18, 0.7)")), needsTransparency: false),
        MonaColorEntry(id: "minimap.findMatchHighlight", defaults: .all(.reference("editor.findMatchHighlightBackground")), needsTransparency: true),
        MonaColorEntry(id: "minimap.foregroundOpacity", defaults: .all(.css("#000000")), needsTransparency: false),
        MonaColorEntry(id: "minimap.infoHighlight", defaults: .variants(dark: .reference("editorInfo.foreground"), hcDark: .reference("editorInfo.border"), hcLight: .reference("editorInfo.border"), light: .reference("editorInfo.foreground")), needsTransparency: false),
        MonaColorEntry(id: "minimap.selectionHighlight", defaults: .all(.reference("editor.selectionBackground")), needsTransparency: true),
        MonaColorEntry(id: "minimap.selectionOccurrenceHighlight", defaults: .all(.reference("editor.selectionHighlightBackground")), needsTransparency: true),
        MonaColorEntry(id: "minimap.warningHighlight", defaults: .variants(dark: .reference("editorWarning.foreground"), hcDark: .reference("editorWarning.border"), hcLight: .reference("editorWarning.border"), light: .reference("editorWarning.foreground")), needsTransparency: false),
        MonaColorEntry(id: "minimapSlider.activeBackground", defaults: .all(.transform(.init(kind: 2, factor: 0.5, value: .reference("scrollbarSlider.activeBackground")))), needsTransparency: false),
        MonaColorEntry(id: "minimapSlider.background", defaults: .all(.transform(.init(kind: 2, factor: 0.5, value: .reference("scrollbarSlider.background")))), needsTransparency: false),
        MonaColorEntry(id: "minimapSlider.hoverBackground", defaults: .all(.transform(.init(kind: 2, factor: 0.5, value: .reference("scrollbarSlider.hoverBackground")))), needsTransparency: false),
        MonaColorEntry(id: "multiDiffEditor.background", defaults: .all(.reference("editor.background")), needsTransparency: false),
        MonaColorEntry(id: "multiDiffEditor.border", defaults: .variants(dark: .reference("sideBarSectionHeader.border"), hcDark: .reference("sideBarSectionHeader.border"), hcLight: .css("#cccccc"), light: .css("#cccccc")), needsTransparency: false),
        MonaColorEntry(id: "multiDiffEditor.headerBackground", defaults: .variants(dark: .css("#262626"), hcDark: .reference("tab.inactiveBackground"), hcLight: .reference("tab.inactiveBackground"), light: .reference("tab.inactiveBackground")), needsTransparency: false),
        MonaColorEntry(id: "peekView.border", defaults: .variants(dark: .reference("editorInfo.foreground"), hcDark: .reference("contrastBorder"), hcLight: .reference("contrastBorder"), light: .reference("editorInfo.foreground")), needsTransparency: false),
        MonaColorEntry(id: "peekViewEditor.background", defaults: .variants(dark: .css("#001F33"), hcDark: .css("#000000"), hcLight: .css("#ffffff"), light: .css("#F2F8FC")), needsTransparency: false),
        MonaColorEntry(id: "peekViewEditor.matchHighlightBackground", defaults: .variants(dark: .css("#ff8f0099"), hcDark: .none, hcLight: .none, light: .css("#f5d802de")), needsTransparency: false),
        MonaColorEntry(id: "peekViewEditor.matchHighlightBorder", defaults: .variants(dark: .none, hcDark: .reference("contrastActiveBorder"), hcLight: .reference("contrastActiveBorder"), light: .none), needsTransparency: false),
        MonaColorEntry(id: "peekViewEditorGutter.background", defaults: .all(.reference("peekViewEditor.background")), needsTransparency: false),
        MonaColorEntry(id: "peekViewEditorStickyScroll.background", defaults: .all(.reference("peekViewEditor.background")), needsTransparency: false),
        MonaColorEntry(id: "peekViewEditorStickyScrollGutter.background", defaults: .all(.reference("peekViewEditor.background")), needsTransparency: false),
        MonaColorEntry(id: "peekViewResult.background", defaults: .variants(dark: .css("#252526"), hcDark: .css("#000000"), hcLight: .css("#ffffff"), light: .css("#F3F3F3")), needsTransparency: false),
        MonaColorEntry(id: "peekViewResult.fileForeground", defaults: .variants(dark: .css("#ffffff"), hcDark: .css("#ffffff"), hcLight: .reference("editor.foreground"), light: .css("#1E1E1E")), needsTransparency: false),
        MonaColorEntry(id: "peekViewResult.lineForeground", defaults: .variants(dark: .css("#bbbbbb"), hcDark: .css("#ffffff"), hcLight: .reference("editor.foreground"), light: .css("#646465")), needsTransparency: false),
        MonaColorEntry(id: "peekViewResult.matchHighlightBackground", defaults: .variants(dark: .css("#ea5c004d"), hcDark: .none, hcLight: .none, light: .css("#ea5c004d")), needsTransparency: false),
        MonaColorEntry(id: "peekViewResult.selectionBackground", defaults: .variants(dark: .css("#3399ff33"), hcDark: .none, hcLight: .none, light: .css("#3399ff33")), needsTransparency: false),
        MonaColorEntry(id: "peekViewResult.selectionForeground", defaults: .variants(dark: .css("#ffffff"), hcDark: .css("#ffffff"), hcLight: .reference("editor.foreground"), light: .css("#6C6C6C")), needsTransparency: false),
        MonaColorEntry(id: "peekViewTitle.background", defaults: .variants(dark: .css("#252526"), hcDark: .css("#000000"), hcLight: .css("#ffffff"), light: .css("#F3F3F3")), needsTransparency: false),
        MonaColorEntry(id: "peekViewTitleDescription.foreground", defaults: .variants(dark: .css("#ccccccb3"), hcDark: .css("#FFFFFF99"), hcLight: .css("#292929"), light: .css("#616161")), needsTransparency: false),
        MonaColorEntry(id: "peekViewTitleLabel.foreground", defaults: .variants(dark: .css("#ffffff"), hcDark: .css("#ffffff"), hcLight: .reference("editor.foreground"), light: .css("#000000")), needsTransparency: false),
        MonaColorEntry(id: "pickerGroup.border", defaults: .variants(dark: .css("#3F3F46"), hcDark: .css("#ffffff"), hcLight: .css("#0F4A85"), light: .css("#CCCEDB")), needsTransparency: false),
        MonaColorEntry(id: "pickerGroup.foreground", defaults: .variants(dark: .css("#3794FF"), hcDark: .css("#ffffff"), hcLight: .css("#0F4A85"), light: .css("#0066BF")), needsTransparency: false),
        MonaColorEntry(id: "problemsErrorIcon.foreground", defaults: .all(.reference("editorError.foreground")), needsTransparency: false),
        MonaColorEntry(id: "problemsInfoIcon.foreground", defaults: .all(.reference("editorInfo.foreground")), needsTransparency: false),
        MonaColorEntry(id: "problemsWarningIcon.foreground", defaults: .all(.reference("editorWarning.foreground")), needsTransparency: false),
        MonaColorEntry(id: "progressBar.background", defaults: .variants(dark: .rgba(r: 14, g: 112, b: 192, a: 1.0), hcDark: .reference("contrastBorder"), hcLight: .reference("contrastBorder"), light: .css("#0e70c0")), needsTransparency: false),
        MonaColorEntry(id: "quickInput.background", defaults: .all(.reference("editorWidget.background")), needsTransparency: false),
        MonaColorEntry(id: "quickInput.foreground", defaults: .all(.reference("editorWidget.foreground")), needsTransparency: false),
        MonaColorEntry(id: "quickInput.list.focusBackground", defaults: .all(.none), needsTransparency: false),
        MonaColorEntry(id: "quickInputList.focusBackground", defaults: .variants(dark: .transform(.init(kind: 4, values: [.reference("quickInput.list.focusBackground"), .reference("list.activeSelectionBackground")])), hcDark: .none, hcLight: .none, light: .transform(.init(kind: 4, values: [.reference("quickInput.list.focusBackground"), .reference("list.activeSelectionBackground")]))), needsTransparency: false),
        MonaColorEntry(id: "quickInputList.focusForeground", defaults: .all(.reference("list.activeSelectionForeground")), needsTransparency: false),
        MonaColorEntry(id: "quickInputList.focusHighlightForeground", defaults: .all(.reference("list.focusHighlightForeground")), needsTransparency: false),
        MonaColorEntry(id: "quickInputList.focusIconForeground", defaults: .all(.reference("list.activeSelectionIconForeground")), needsTransparency: false),
        MonaColorEntry(id: "quickInputTitle.background", defaults: .variants(dark: .rgba(r: 255, g: 255, b: 255, a: 0.105), hcDark: .css("#000000"), hcLight: .css("#ffffff"), light: .css("rgba(0, 0, 0, 0.06)")), needsTransparency: false),
        MonaColorEntry(id: "radio.activeBackground", defaults: .all(.reference("inputOption.activeBackground")), needsTransparency: false),
        MonaColorEntry(id: "radio.activeBorder", defaults: .all(.reference("inputOption.activeBorder")), needsTransparency: false),
        MonaColorEntry(id: "radio.activeForeground", defaults: .all(.reference("inputOption.activeForeground")), needsTransparency: false),
        MonaColorEntry(id: "radio.inactiveBackground", defaults: .all(.none), needsTransparency: false),
        MonaColorEntry(id: "radio.inactiveBorder", defaults: .variants(dark: .transform(.init(kind: 2, factor: 0.2, value: .reference("radio.activeForeground"))), hcDark: .transform(.init(kind: 2, factor: 0.4, value: .reference("radio.activeForeground"))), hcLight: .transform(.init(kind: 2, factor: 0.2, value: .reference("radio.activeForeground"))), light: .transform(.init(kind: 2, factor: 0.2, value: .reference("radio.activeForeground")))), needsTransparency: false),
        MonaColorEntry(id: "radio.inactiveForeground", defaults: .all(.none), needsTransparency: false),
        MonaColorEntry(id: "radio.inactiveHoverBackground", defaults: .all(.reference("inputOption.hoverBackground")), needsTransparency: false),
        MonaColorEntry(id: "sash.hoverBorder", defaults: .all(.reference("focusBorder")), needsTransparency: false),
        MonaColorEntry(id: "scrollbar.background", defaults: .all(.none), needsTransparency: false),
        MonaColorEntry(id: "scrollbar.shadow", defaults: .variants(dark: .css("#000000"), hcDark: .none, hcLight: .none, light: .css("#DDDDDD")), needsTransparency: false),
        MonaColorEntry(id: "scrollbarSlider.activeBackground", defaults: .variants(dark: .rgba(r: 191, g: 191, b: 191, a: 0.4), hcDark: .reference("contrastBorder"), hcLight: .reference("contrastBorder"), light: .css("rgba(0, 0, 0, 0.6)")), needsTransparency: false),
        MonaColorEntry(id: "scrollbarSlider.background", defaults: .variants(dark: .rgba(r: 121, g: 121, b: 121, a: 0.4), hcDark: .transform(.init(kind: 2, factor: 0.6, value: .reference("contrastBorder"))), hcLight: .transform(.init(kind: 2, factor: 0.4, value: .reference("contrastBorder"))), light: .css("rgba(100, 100, 100, 0.4)")), needsTransparency: false),
        MonaColorEntry(id: "scrollbarSlider.hoverBackground", defaults: .variants(dark: .rgba(r: 100, g: 100, b: 100, a: 0.7), hcDark: .transform(.init(kind: 2, factor: 0.8, value: .reference("contrastBorder"))), hcLight: .transform(.init(kind: 2, factor: 0.8, value: .reference("contrastBorder"))), light: .css("rgba(100, 100, 100, 0.7)")), needsTransparency: false),
        MonaColorEntry(id: "search.resultsInfoForeground", defaults: .variants(dark: .transform(.init(kind: 2, factor: 0.65, value: .reference("foreground"))), hcDark: .reference("foreground"), hcLight: .reference("foreground"), light: .reference("foreground")), needsTransparency: false),
        MonaColorEntry(id: "searchEditor.findMatchBackground", defaults: .variants(dark: .transform(.init(kind: 2, factor: 0.66, value: .reference("editor.findMatchHighlightBackground"))), hcDark: .reference("editor.findMatchHighlightBackground"), hcLight: .reference("editor.findMatchHighlightBackground"), light: .transform(.init(kind: 2, factor: 0.66, value: .reference("editor.findMatchHighlightBackground")))), needsTransparency: false),
        MonaColorEntry(id: "searchEditor.findMatchBorder", defaults: .variants(dark: .transform(.init(kind: 2, factor: 0.66, value: .reference("editor.findMatchHighlightBorder"))), hcDark: .reference("editor.findMatchHighlightBorder"), hcLight: .reference("editor.findMatchHighlightBorder"), light: .transform(.init(kind: 2, factor: 0.66, value: .reference("editor.findMatchHighlightBorder")))), needsTransparency: false),
        MonaColorEntry(id: "selection.background", defaults: .all(.none), needsTransparency: false),
        MonaColorEntry(id: "strongForeground", defaults: .variants(dark: .css("#FFFFFF"), hcDark: .css("#FFFFFF"), hcLight: .css("#000000"), light: .css("#000000")), needsTransparency: false),
        MonaColorEntry(id: "symbolIcon.arrayForeground", defaults: .all(.reference("foreground")), needsTransparency: false),
        MonaColorEntry(id: "symbolIcon.booleanForeground", defaults: .all(.reference("foreground")), needsTransparency: false),
        MonaColorEntry(id: "symbolIcon.classForeground", defaults: .variants(dark: .css("#EE9D28"), hcDark: .css("#EE9D28"), hcLight: .css("#D67E00"), light: .css("#D67E00")), needsTransparency: false),
        MonaColorEntry(id: "symbolIcon.colorForeground", defaults: .all(.reference("foreground")), needsTransparency: false),
        MonaColorEntry(id: "symbolIcon.constantForeground", defaults: .all(.reference("foreground")), needsTransparency: false),
        MonaColorEntry(id: "symbolIcon.constructorForeground", defaults: .variants(dark: .css("#B180D7"), hcDark: .css("#B180D7"), hcLight: .css("#652D90"), light: .css("#652D90")), needsTransparency: false),
        MonaColorEntry(id: "symbolIcon.enumeratorForeground", defaults: .variants(dark: .css("#EE9D28"), hcDark: .css("#EE9D28"), hcLight: .css("#D67E00"), light: .css("#D67E00")), needsTransparency: false),
        MonaColorEntry(id: "symbolIcon.enumeratorMemberForeground", defaults: .variants(dark: .css("#75BEFF"), hcDark: .css("#75BEFF"), hcLight: .css("#007ACC"), light: .css("#007ACC")), needsTransparency: false),
        MonaColorEntry(id: "symbolIcon.eventForeground", defaults: .variants(dark: .css("#EE9D28"), hcDark: .css("#EE9D28"), hcLight: .css("#D67E00"), light: .css("#D67E00")), needsTransparency: false),
        MonaColorEntry(id: "symbolIcon.fieldForeground", defaults: .variants(dark: .css("#75BEFF"), hcDark: .css("#75BEFF"), hcLight: .css("#007ACC"), light: .css("#007ACC")), needsTransparency: false),
        MonaColorEntry(id: "symbolIcon.fileForeground", defaults: .all(.reference("foreground")), needsTransparency: false),
        MonaColorEntry(id: "symbolIcon.folderForeground", defaults: .all(.reference("foreground")), needsTransparency: false),
        MonaColorEntry(id: "symbolIcon.functionForeground", defaults: .variants(dark: .css("#B180D7"), hcDark: .css("#B180D7"), hcLight: .css("#652D90"), light: .css("#652D90")), needsTransparency: false),
        MonaColorEntry(id: "symbolIcon.interfaceForeground", defaults: .variants(dark: .css("#75BEFF"), hcDark: .css("#75BEFF"), hcLight: .css("#007ACC"), light: .css("#007ACC")), needsTransparency: false),
        MonaColorEntry(id: "symbolIcon.keyForeground", defaults: .all(.reference("foreground")), needsTransparency: false),
        MonaColorEntry(id: "symbolIcon.keywordForeground", defaults: .all(.reference("foreground")), needsTransparency: false),
        MonaColorEntry(id: "symbolIcon.methodForeground", defaults: .variants(dark: .css("#B180D7"), hcDark: .css("#B180D7"), hcLight: .css("#652D90"), light: .css("#652D90")), needsTransparency: false),
        MonaColorEntry(id: "symbolIcon.moduleForeground", defaults: .all(.reference("foreground")), needsTransparency: false),
        MonaColorEntry(id: "symbolIcon.namespaceForeground", defaults: .all(.reference("foreground")), needsTransparency: false),
        MonaColorEntry(id: "symbolIcon.nullForeground", defaults: .all(.reference("foreground")), needsTransparency: false),
        MonaColorEntry(id: "symbolIcon.numberForeground", defaults: .all(.reference("foreground")), needsTransparency: false),
        MonaColorEntry(id: "symbolIcon.objectForeground", defaults: .all(.reference("foreground")), needsTransparency: false),
        MonaColorEntry(id: "symbolIcon.operatorForeground", defaults: .all(.reference("foreground")), needsTransparency: false),
        MonaColorEntry(id: "symbolIcon.packageForeground", defaults: .all(.reference("foreground")), needsTransparency: false),
        MonaColorEntry(id: "symbolIcon.propertyForeground", defaults: .all(.reference("foreground")), needsTransparency: false),
        MonaColorEntry(id: "symbolIcon.referenceForeground", defaults: .all(.reference("foreground")), needsTransparency: false),
        MonaColorEntry(id: "symbolIcon.snippetForeground", defaults: .all(.reference("foreground")), needsTransparency: false),
        MonaColorEntry(id: "symbolIcon.stringForeground", defaults: .all(.reference("foreground")), needsTransparency: false),
        MonaColorEntry(id: "symbolIcon.structForeground", defaults: .all(.reference("foreground")), needsTransparency: false),
        MonaColorEntry(id: "symbolIcon.textForeground", defaults: .all(.reference("foreground")), needsTransparency: false),
        MonaColorEntry(id: "symbolIcon.typeParameterForeground", defaults: .all(.reference("foreground")), needsTransparency: false),
        MonaColorEntry(id: "symbolIcon.unitForeground", defaults: .all(.reference("foreground")), needsTransparency: false),
        MonaColorEntry(id: "symbolIcon.variableForeground", defaults: .variants(dark: .css("#75BEFF"), hcDark: .css("#75BEFF"), hcLight: .css("#007ACC"), light: .css("#007ACC")), needsTransparency: false),
        MonaColorEntry(id: "textBlockQuote.background", defaults: .variants(dark: .css("#222222"), hcDark: .none, hcLight: .css("#F2F2F2"), light: .css("#f2f2f2")), needsTransparency: false),
        MonaColorEntry(id: "textBlockQuote.border", defaults: .variants(dark: .css("#007acc80"), hcDark: .css("#ffffff"), hcLight: .css("#292929"), light: .css("#007acc80")), needsTransparency: false),
        MonaColorEntry(id: "textCodeBlock.background", defaults: .variants(dark: .css("#0a0a0a66"), hcDark: .css("#000000"), hcLight: .css("#F2F2F2"), light: .css("#dcdcdc66")), needsTransparency: false),
        MonaColorEntry(id: "textLink.activeForeground", defaults: .variants(dark: .css("#3794FF"), hcDark: .css("#21A6FF"), hcLight: .css("#0F4A85"), light: .css("#006AB1")), needsTransparency: false),
        MonaColorEntry(id: "textLink.foreground", defaults: .variants(dark: .css("#3794FF"), hcDark: .css("#21A6FF"), hcLight: .css("#0F4A85"), light: .css("#006AB1")), needsTransparency: false),
        MonaColorEntry(id: "textPreformat.background", defaults: .variants(dark: .css("#FFFFFF1A"), hcDark: .none, hcLight: .css("#09345f"), light: .css("#0000001A")), needsTransparency: false),
        MonaColorEntry(id: "textPreformat.border", defaults: .variants(dark: .none, hcDark: .reference("contrastBorder"), hcLight: .none, light: .none), needsTransparency: false),
        MonaColorEntry(id: "textPreformat.foreground", defaults: .variants(dark: .css("#D7BA7D"), hcDark: .css("#FFFFFF"), hcLight: .css("#FFFFFF"), light: .css("#A31515")), needsTransparency: false),
        MonaColorEntry(id: "textSeparator.foreground", defaults: .variants(dark: .css("#ffffff2e"), hcDark: .css("#000000"), hcLight: .css("#292929"), light: .css("#0000002e")), needsTransparency: false),
        MonaColorEntry(id: "toolbar.activeBackground", defaults: .variants(dark: .transform(.init(kind: 1, factor: 0.1, value: .reference("toolbar.hoverBackground"))), hcDark: .none, hcLight: .none, light: .transform(.init(kind: 0, factor: 0.1, value: .reference("toolbar.hoverBackground")))), needsTransparency: false),
        MonaColorEntry(id: "toolbar.hoverBackground", defaults: .variants(dark: .css("#5a5d5e50"), hcDark: .none, hcLight: .none, light: .css("#b8b8b850")), needsTransparency: false),
        MonaColorEntry(id: "toolbar.hoverOutline", defaults: .variants(dark: .none, hcDark: .reference("contrastActiveBorder"), hcLight: .reference("contrastActiveBorder"), light: .none), needsTransparency: false),
        MonaColorEntry(id: "tree.inactiveIndentGuidesStroke", defaults: .all(.transform(.init(kind: 2, factor: 0.4, value: .reference("tree.indentGuidesStroke")))), needsTransparency: false),
        MonaColorEntry(id: "tree.indentGuidesStroke", defaults: .variants(dark: .css("#585858"), hcDark: .css("#a9a9a9"), hcLight: .css("#a5a5a5"), light: .css("#a9a9a9")), needsTransparency: false),
        MonaColorEntry(id: "tree.tableColumnsBorder", defaults: .variants(dark: .css("#CCCCCC20"), hcDark: .none, hcLight: .none, light: .css("#61616120")), needsTransparency: false),
        MonaColorEntry(id: "tree.tableOddRowsBackground", defaults: .variants(dark: .transform(.init(kind: 2, factor: 0.04, value: .reference("foreground"))), hcDark: .none, hcLight: .none, light: .transform(.init(kind: 2, factor: 0.04, value: .reference("foreground")))), needsTransparency: false),
        MonaColorEntry(id: "widget.border", defaults: .variants(dark: .none, hcDark: .reference("contrastBorder"), hcLight: .reference("contrastBorder"), light: .none), needsTransparency: false),
        MonaColorEntry(id: "widget.shadow", defaults: .variants(dark: .transform(.init(kind: 2, factor: 0.36, value: .css("#000000"))), hcDark: .none, hcLight: .none, light: .transform(.init(kind: 2, factor: 0.16, value: .css("#000000")))), needsTransparency: false),
    ]

    private static let idIndex: [String: Int] = {
        var idx: [String: Int] = [:]
        for (i, c) in colors.enumerated() { idx[c.id] = i }
        return idx
    }()

    /// Looks up a color entry by id.
    public static func entry(for id: String) -> MonaColorEntry? {
        guard let i = idIndex[id] else { return nil }
        return colors[i]
    }

    /// All 431 builtin color ids in source-ordinal order.
    public static var ids: [String] { colors.map { $0.id } }

    /// Resolves `id` for `variant`, following color-id references and applying
    /// high-contrast fallback (`hcDark` -> `dark`, `hcLight` -> `light`).
    ///
    /// Concrete literals (`#hex`, `_toString`, `rgba`) resolve to `.value`.
    /// Transforms (darken/lighten/transparent/blend/mix/conditional) resolve to
    /// `.transform` with their target references resolved as far as possible;
    /// the final arithmetic is deferred to the native rendering layer.
    public static func resolve(_ id: String, variant: MonaColorVariant) -> MonaResolvedColor {
        return resolveIdentifier(id, variant: variant, visited: [])
    }

    private static func resolveIdentifier(_ id: String, variant: MonaColorVariant,
                                          visited: Set<String>) -> MonaResolvedColor {
        if visited.contains(id) { return .none }
        guard let entry = entry(for: id) else { return .none }
        let node = nodeForVariant(entry.defaults, variant: variant)
        return resolveNode(node, variant: variant, visited: visited.union([id]))
    }

    private static func nodeForVariant(_ def: MonaColorDefault, variant: MonaColorVariant) -> MonaColorNode {
        switch def {
        case .all(let node):
            return node
        case .variants(let dark, let hcDark, let hcLight, let light):
            switch variant {
            case .dark: return dark
            case .light: return light
            case .hcDark:
                if case .none = hcDark { return dark }
                return hcDark
            case .hcLight:
                if case .none = hcLight { return light }
                return hcLight
            }
        }
    }

    private static func resolveNode(_ node: MonaColorNode, variant: MonaColorVariant,
                                    visited: Set<String>) -> MonaResolvedColor {
        switch node {
        case .none:
            return .none
        case .css(let s):
            return .value(MonaColorValue(s))
        case .rgba(let r, let g, let b, let a):
            return .value(MonaColorValue(formatRGBA(r: r, g: g, b: b, a: a)))
        case .reference(let ref):
            return resolveIdentifier(ref, variant: variant, visited: visited)
        case .transform(let t):
            return .transform(resolvedTransform(t, variant: variant, visited: visited))
        }
    }

    private static func resolvedTransform(_ t: MonaColorTransform, variant: MonaColorVariant,
                                          visited: Set<String>) -> MonaColorTransform {
        func rn(_ n: MonaColorNode?) -> MonaColorNode {
            guard let n = n else { return .none }
            switch n {
            case .reference(let ref):
                // Resolve the reference's node (without collapsing to a value)
                // so the transform keeps pointing at concrete data when possible.
                if visited.contains(ref) { return .none }
                guard let e = entry(for: ref) else { return .none }
                return nodeForVariant(e.defaults, variant: variant)
            default:
                return n
            }
        }
        return MonaColorTransform(
            kind: t.kind,
            factor: t.factor,
            ratio: t.ratio,
            value: rn(t.value),
            values: t.values?.map(rn),
            condition: t.condition,
            thenValue: rn(t.thenValue),
            elseValue: rn(t.elseValue),
            mixWith: rn(t.mixWith)
        )
    }

    private static func formatRGBA(r: Int, g: Int, b: Int, a: Double) -> String {
        if a >= 1.0 {
            return String(format: "#%02X%02X%02X", r, g, b)
        }
        return String(format: "rgba(%d, %d, %d, %g)", r, g, b, a)
    }
}

