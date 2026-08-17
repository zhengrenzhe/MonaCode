// MonaLargeModelState.swift
//
// P01-T011 — Implement model construction and large-model state.
//
// `MonaLargeModelState` is the Swift counterpart of Monaco's large-file
// determination (monaco-editor 0.56.0, `TextModel` source, fixed by the H2-R
// runtime-resource closure). H2-R converts the previously fuzzy large-file
// clauses into an executable contract: four threshold comparisons, all
// strict `>`, all evaluated once from the initial text (UTF-16 code units and
// line count), all sticky across subsequent edits.
//
// H2-R fixes exactly three large-file flags, computed from the initial buffer:
//
//   Flag            | Initial condition               | Effect (sticky)
//   ----------------|---------------------------------|--------------------------------
//   Tokenization    | length > 20×1024² units         | forced false
//                   |   OR lines > 300,000            |
//   Syncing         | length > 50×1024² units         | threshold still applies
//   Heap operation  | length > 256×1024² units        | forced false
//
// "Create limit": H2-R fixes NO hard reject threshold. A 100 Mi-unit model is
// a performance fixture, not a maximum — `largeModelPerformanceFixtureLength`
// records that fixture size.
//
// `MonaLargeModelState` is the high-level, one-way state derived from those
// flags: `.normal` when no flag fires, `.large` once any flag would fire. The
// state is one-way (sticky): once `.large`, it never returns to `.normal`,
// matching Monaco where the flags are assigned only in the constructor and
// later edits across the threshold do not change them.
//
// All thresholds are expressed in initial UTF-16 code units (not serialized
// bytes), matching H2-R hit 93 ("20/50/256 'MB' 是字节 … 单位固定为初始 UTF-16
// code units").
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The one-way large-model state, derived from the H2-R large-file flags.
///
/// A model is `.normal` at construction when none of the H2-R large-file
/// thresholds are exceeded; it transitions irreversibly to `.large` when any
/// threshold fires. The transition is one-way: `.large` never returns to
/// `.normal`, even if a later (hypothetical) re-evaluation would land below a
/// threshold — the flags are sticky, assigned only from the initial text.
public enum MonaLargeModelState: Equatable, Sendable {

    /// The model is below every H2-R large-file threshold.
    case normal

    /// The model exceeds at least one H2-R large-file threshold. Sticky: once
    /// `.large`, the state never returns to `.normal`.
    case large

    // MARK: - H2-R threshold constants (exact)

    /// Tokenization flag: fires when the initial UTF-16 length strictly
    /// exceeds 20 Mi-units (20 × 1024 × 1024). Forces tokenization off.
    public static let tooLargeForTokenizationByLength: Int = 20 * 1024 * 1024

    /// Tokenization flag: fires when the initial line count strictly exceeds
    /// 300,000. Forces tokenization off.
    public static let tooLargeForTokenizationByLines: Int = 300_000

    /// Syncing flag: fires when the initial UTF-16 length strictly exceeds
    /// 50 Mi-units (50 × 1024 × 1024). The threshold continues to apply even
    /// when `largeFileOptimizations` is explicitly disabled.
    public static let tooLargeForSyncing: Int = 50 * 1024 * 1024

    /// Heap-operation flag: fires when the initial UTF-16 length strictly
    /// exceeds 256 Mi-units (256 × 1024 × 1024). Forces heap operations off.
    public static let tooLargeForHeapOperation: Int = 256 * 1024 * 1024

    /// The 100 Mi-unit performance-fixture size. H2-R fixes NO hard create
    /// limit; this value is the performance-fixture corpus size, not a
    /// maximum. Recorded here so later complexity gates can reference the
    /// exact fixture bound.
    public static let largeModelPerformanceFixtureLength: Int = 100 * 1024 * 1024

    /// The `.normal` → `.large` state-transition threshold. A model whose
    /// initial UTF-16 length strictly exceeds 50 Mi-units is `.large`. This
    /// mirrors Monaco's `_isLargeModel` determination (the syncing threshold's
    /// role as the large-model marker).
    public static let largeModelStateTransition: Int = 50 * 1024 * 1024

    /// The complete, named H2-R threshold set. Six thresholds, in declaration
    /// order. Exposed so callers (and the P01-T011 contract leaf) can count
    /// the fixed threshold surface without enumerating case names.
    public static var allThresholds: [(name: String, value: Int)] {
        return [
            ("tooLargeForTokenizationByLength", tooLargeForTokenizationByLength),
            ("tooLargeForTokenizationByLines", tooLargeForTokenizationByLines),
            ("tooLargeForSyncing", tooLargeForSyncing),
            ("tooLargeForHeapOperation", tooLargeForHeapOperation),
            ("largeModelPerformanceFixtureLength", largeModelPerformanceFixtureLength),
            ("largeModelStateTransition", largeModelStateTransition),
        ]
    }

    // MARK: - State determination (sticky, one-way)

    /// Computes the large-model state from the INITIAL UTF-16 length and line
    /// count. The state is sticky: it is evaluated once, at construction, from
    /// the initial text; later edits never change it.
    ///
    /// A model is `.large` when any H2-R large-file flag would fire — i.e. the
    /// initial length strictly exceeds the tokenization length threshold
    /// (20 Mi-units, the binding length constraint) OR the initial line count
    /// strictly exceeds 300,000. All comparisons are strict `>`.
    public static func state(
        initialLength: Int,
        initialLineCount: Int
    ) -> MonaLargeModelState {
        // Length thresholds: the binding (lowest) constraint is the
        // tokenization length threshold (20 Mi). Syncing (50 Mi) and heap
        // operation (256 Mi) are strict supersets of it, so the length check
        // reduces to the tokenization boundary.
        if initialLength > tooLargeForTokenizationByLength {
            return .large
        }
        if initialLength > tooLargeForSyncing {
            return .large
        }
        if initialLength > tooLargeForHeapOperation {
            return .large
        }
        if initialLineCount > tooLargeForTokenizationByLines {
            return .large
        }
        return .normal
    }

    /// The one-way state transition. Returns the next state, enforcing that
    /// `.large` never returns to `.normal`.
    ///
    /// - `.normal → .normal` stays `.normal`.
    /// - `.normal → .large` becomes `.large`.
    /// - `.large → .large` stays `.large`.
    /// - `.large → .normal` stays `.large` (the one-way invariant).
    public func transition(to next: MonaLargeModelState) -> MonaLargeModelState {
        switch (self, next) {
        case (.normal, .normal):
            return .normal
        case (.normal, .large):
            return .large
        case (.large, _):
            // One-way: `.large` never returns to `.normal`.
            return .large
        }
    }
}
