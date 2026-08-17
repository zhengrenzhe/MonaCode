// MonaEditorOption.swift
//
// P05-T005 — Implement all 174 editor options and computed option truth.
//
// `MonaEditorOption` is the option model: a frozen identity for one of the 174
// editor options ported from monaco-editor@0.56.0 (F1-R3 scope manifest,
// `registries.options`). Each option carries its source id, name, runtime name,
// disposition (retained-input / computed-only / cut), input kind, canonical
// default value, numeric bounds, extensible-enum members, and — for
// computed-only options — the names of the options its derivation reads (the
// dependency graph the store resolves in topological order).
//
// `MonaOptionValue` is the typed value box for an option: a recursive value
// covering booleans, integers, doubles, strings, arrays, objects, and null
// (for `$undefined` placeholders). It is the single value type across the
// option store, snapshot, and change events.
//
// Extensible enums: enum (`.enumString`) options store their value as a string
// raw value and declare their *known* members via `enumMembers`. The known
// members are NOT exhaustive — a future raw value (not in `enumMembers`) is
// accepted on `set`, mirroring Monaco's open-enum treatment. The canonical
// default is always a known member. This is the Swift counterpart of Monaco's
// `EditorOption` + `ConfigurationHeaderValue` without freezing the enum set.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

// MARK: - MonaOptionDisposition

/// The disposition of an editor option: whether it is mutable input, derived
/// (computed-only), or excluded (cut).
public enum MonaOptionDisposition: String, Sendable, Equatable, CaseIterable {

    /// A retained, mutable input option (settable via the option store).
    case retainedInput

    /// A computed-only option: derived from other options/state, exposed as
    /// read-only. NEVER settable as input.
    case computedOnly

    /// A cut option: explicitly excluded from production input APIs. Recorded
    /// as an UNAVAILABLE disposition — no production symbol, no settable input.
    case cut

    /// `true` when this disposition is part of the readable option surface
    /// (retained-input or computed-only). Cut options are never readable.
    public var isReadable: Bool {
        switch self {
        case .retainedInput, .computedOnly: return true
        case .cut: return false
        }
    }
}

// MARK: - MonaOptionKind

/// The input kind of a retained-input option: the value type the store accepts
/// and validates against.
public enum MonaOptionKind: String, Sendable, Equatable, CaseIterable {

    /// A boolean option (`true` / `false`).
    case boolean

    /// An integer option (optionally bounded by `MonaOptionBounds`).
    case integer

    /// A floating-point option (optionally bounded by `MonaOptionBounds`).
    case number

    /// A free-form string option (no enum membership).
    case string

    /// An extensible-enum option: the value is a string raw value drawn from a
    /// known set of `enumMembers`. The set is open — future raw values are
    /// accepted on set; the canonical default is always a known member.
    case enumString

    /// A structured object option (e.g. `minimap`, `find`, `scrollbar`). Stored
    /// as an opaque `MonaOptionValue.object` payload.
    case object

    /// An array option (e.g. `rulers`). Stored as `MonaOptionValue.array`.
    case array
}

// MARK: - MonaOptionValue

/// A typed value for an editor option. Recursive over arrays and objects.
///
/// `.null` represents a `$undefined` placeholder (an option whose default is
/// absent, e.g. `placeholder` / `readOnlyMessage`).
public indirect enum MonaOptionValue: Sendable, Equatable, Hashable {

    /// A boolean value.
    case bool(Bool)

    /// An integer value.
    case int(Int)

    /// A floating-point value.
    case double(Double)

    /// A string value (free-form or enum raw value).
    case string(String)

    /// An array of values.
    case array([MonaOptionValue])

    /// An object payload: a dictionary of string keys to typed values.
    case object([String: MonaOptionValue])

    /// A null / absent / `$undefined` placeholder.
    case null

    /// Returns the boolean value, or `nil` if this is not a boolean.
    public var boolValue: Bool? {
        if case .bool(let v) = self { return v }
        return nil
    }

    /// Returns the integer value, or `nil` if this is not an integer.
    public var intValue: Int? {
        if case .int(let v) = self { return v }
        return nil
    }

    /// Returns the double value, or `nil` if this is not a number.
    public var doubleValue: Double? {
        if case .double(let v) = self { return v }
        return nil
    }

    /// Returns the string value, or `nil` if this is not a string.
    public var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }

    /// Returns the array value, or `nil` if this is not an array.
    public var arrayValue: [MonaOptionValue]? {
        if case .array(let v) = self { return v }
        return nil
    }

    /// Returns the object value, or `nil` if this is not an object.
    public var objectValue: [String: MonaOptionValue]? {
        if case .object(let v) = self { return v }
        return nil
    }
}

// MARK: - MonaOptionBounds

/// Inclusive numeric bounds for an integer or number option.
public struct MonaOptionBounds: Sendable, Equatable, Hashable {

    /// The inclusive minimum, or `nil` when unbounded below.
    public let min: Double

    /// The inclusive maximum, or `nil` when unbounded above.
    public let max: Double

    /// `true` when a finite minimum is declared.
    public var hasMin: Bool { !min.isNaN && !min.isInfinite }
    /// `true` when a finite maximum is declared.
    public var hasMax: Bool { !max.isNaN && !max.isInfinite }

    /// Creates bounds. Pass `.nan` (or `.infinity`) for `min`/`max` to denote
    /// "unbounded" on that side.
    public init(min: Double = .nan, max: Double = .nan) {
        self.min = min
        self.max = max
    }

    /// Creates bounds from optional values; `nil` means unbounded on that side.
    public init(minInt: Int?, maxInt: Int?) {
        self.min = minInt.map(Double.init) ?? .nan
        self.max = maxInt.map(Double.init) ?? .nan
    }

    /// Returns `true` when `value` is within the inclusive bounds.
    public func contains(_ value: Double) -> Bool {
        if hasMin && value < min { return false }
        if hasMax && value > max { return false }
        return true
    }
}

// MARK: - MonaEditorOption

/// A frozen editor option identity, ported verbatim from the F1-R3 scope
/// manifest in source order.
///
/// Each option carries its input kind, canonical default, bounds (for numeric
/// options), extensible-enum members (for `.enumString` options), and — for
/// computed-only options — the names of the options its derivation reads (the
/// dependency edges the store resolves in topological order).
public struct MonaEditorOption: Hashable, Sendable {

    /// The stable source id (`0…173`), preserved verbatim from the manifest.
    public let id: Int

    /// The option name (e.g. `"wordWrap"`, `"fontSize"`).
    public let name: String

    /// The runtime name (the symbol Monaco binds the option to). For
    /// computed-only options this is `"_never_"` — the option is never set as
    /// input, it is always derived.
    public let runtimeName: String

    /// The disposition: retained-input (mutable), computed-only (read-only
    /// derived), or cut (excluded).
    public let disposition: MonaOptionDisposition

    /// The input kind. `nil` for computed-only options that do not accept a
    /// typed input (they are derived).
    public let kind: MonaOptionKind?

    /// The canonical default value (from `schema.default`). For computed-only
    /// options this is the initial derived value.
    public let defaultValue: MonaOptionValue

    /// Inclusive numeric bounds, for `.integer` / `.number` options. `nil` for
    /// non-numeric or unbounded options.
    public let bounds: MonaOptionBounds?

    /// The known enum members, for `.enumString` options. `nil` for non-enum
    /// options. The set is open: future raw values are accepted on set.
    public let enumMembers: [String]?

    /// The names of the options this option's derivation reads, for
    /// computed-only options. Empty for retained-input and cut options. The
    /// store resolves computed options in topological order over these edges.
    public let reads: [String]

    /// `true` when this option is part of the readable surface.
    public var isReadable: Bool { disposition.isReadable }

    public init(
        id: Int,
        name: String,
        runtimeName: String,
        disposition: MonaOptionDisposition,
        kind: MonaOptionKind?,
        defaultValue: MonaOptionValue,
        bounds: MonaOptionBounds? = nil,
        enumMembers: [String]? = nil,
        reads: [String] = []
    ) {
        self.id = id
        self.name = name
        self.runtimeName = runtimeName
        self.disposition = disposition
        self.kind = kind
        self.defaultValue = defaultValue
        self.bounds = bounds
        self.enumMembers = enumMembers
        self.reads = reads
    }
}

// MARK: - MonaOptionChangeEvent

/// A changed-option event, fired by the option store when a retained-input
/// option is set or a computed-only option is recomputed.
public struct MonaOptionChangeEvent: Sendable, Equatable {

    /// The name of the option that changed.
    public let optionName: String

    /// The previous value, or `nil` if the option had no prior value.
    public let oldValue: MonaOptionValue?

    /// The new value.
    public let newValue: MonaOptionValue?

    /// `true` when the change is a computed-option recompute (derived), `false`
    /// when it is a direct retained-input set.
    public let isComputed: Bool

    public init(optionName: String, oldValue: MonaOptionValue?, newValue: MonaOptionValue?, isComputed: Bool) {
        self.optionName = optionName
        self.oldValue = oldValue
        self.newValue = newValue
        self.isComputed = isComputed
    }
}

// MARK: - MonaOptionSetResult

/// The result of attempting to set an option value on the store.
public enum MonaOptionSetResult: Sendable, Equatable {

    /// The value was accepted and applied.
    case success

    /// The option name is not a known editor option.
    case unknownOption

    /// The option is cut (excluded from production input APIs).
    case cutOption(String)

    /// The option is computed-only and cannot be set as input.
    case computedNotSettable(String)

    /// The value's type does not match the option's declared kind.
    case typeMismatch(expected: MonaOptionKind)

    /// The value is outside the option's declared bounds.
    case outOfBounds(min: Double?, max: Double?)
}
