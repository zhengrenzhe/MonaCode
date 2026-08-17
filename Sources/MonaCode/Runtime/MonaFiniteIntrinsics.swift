// MonaFiniteIntrinsics.swift
//
// P02-T008 — Implement finite ECMAScript intrinsics, codecs, and String SHA-1.
//
// The closed registry of ECMAScript intrinsic operation profiles retained by
// the editor (monaco-editor 0.56.0, fixed by the X1-R
// `intrinsicOperationProfiles` closure).
//
// X1-R `finitePortRule`: "MonaCode does not implement or expose a general
// JavaScript runtime. It implements the finite operation profiles exercised by
// retained source rows, with Chrome 151 as the observable oracle; cut,
// native-adapted and emitted-build rows do not create generic intrinsic APIs."
//
// The profile is a closed set of 12 intrinsic categories, each carrying its
// X1-R reference count and a finite set of supported operation names. A request
// for any operation outside the finite profile is rejected with
// `MonaFiniteIntrinsicError.unsupportedOperation`. This is the sole gate: the
// individual computations (binary64 arithmetic, text codec, SHA-1) live in
// their own Phase-02 leaves and are routed through this gate by callers.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// A typed error raised when an intrinsic operation is outside the finite
/// X1-R profile.
public enum MonaFiniteIntrinsicError: Error, Equatable, Sendable {

    /// The requested `category.operation` is not in the finite intrinsic
    /// profile. The rejected qualified name is preserved verbatim for
    /// diagnostics.
    case unsupportedOperation(String)
}

/// One of the 12 finite intrinsic categories retained by X1-R.
///
/// Each case carries its exact X1-R `selectedReferenceCounts` value via
/// `referenceCount`. The 12 categories form a closed set: no other intrinsic
/// category is exposed by MonaCode.
public enum MonaFiniteIntrinsicCategory: String, Sendable, Equatable, CaseIterable {

    /// Array operations (250 X1-R references).
    case array

    /// Object operations (638 X1-R references).
    case object

    /// Reflect operations (618 X1-R references).
    case reflect

    /// Map operations (230 X1-R references).
    case map

    /// Set operations (176 X1-R references).
    case set

    /// Promise operations (192 X1-R references).
    case promise

    /// Math operations (1099 X1-R references).
    case math

    /// Number operations (107 X1-R references).
    case number

    /// String operations (131 X1-R references).
    case string

    /// JSON operations (73 X1-R references).
    case json

    /// RegExp operations (74 X1-R references).
    case regexp

    /// Symbol operations (39 X1-R references).
    case symbol

    /// The exact X1-R `selectedReferenceCounts` value for this category.
    public var referenceCount: Int {
        switch self {
        case .array:   return 250
        case .object:  return 638
        case .reflect: return 618
        case .map:     return 230
        case .set:     return 176
        case .promise: return 192
        case .math:    return 1099
        case .number:  return 107
        case .string:  return 131
        case .json:    return 73
        case .regexp:  return 74
        case .symbol:  return 39
        }
    }
}

/// The finite, closed ECMAScript intrinsic profile (X1-R).
///
/// `MonaFiniteIntrinsics` is a namespace (caseless enum) exposing:
///
///   - `categories` — the 12-category closed set.
///   - `contains(_:)` — membership test for a category.
///   - `supports(_:_:)` — membership test for a category+operation pair.
///   - `perform(_:_:)` — gate that rejects unsupported operations.
///   - `perform(_:_:_:)` — guarded execution: runs the body only when the
///     operation is in the finite profile, otherwise throws.
///
/// Each operation is a typed function: callers route the actual computation
/// (binary64 arithmetic, text codec, SHA-1, etc.) through the guard so that no
/// request outside the finite profile is ever executed.
public enum MonaFiniteIntrinsics {

    /// The finite, closed set of intrinsic categories (exactly 12, X1-R).
    public static var categories: [MonaFiniteIntrinsicCategory] {
        Array(MonaFiniteIntrinsicCategory.allCases)
    }

    /// The finite, closed set of supported operation names per category.
    ///
    /// Only the operations the editor needs are listed. Any operation not
    /// present here is outside the finite profile and is rejected.
    public static let supportedOperations: [MonaFiniteIntrinsicCategory: Set<String>] = [
        .array: [
            "push", "pop", "shift", "unshift", "slice", "splice", "indexOf",
            "lastIndexOf", "includes", "map", "filter", "reduce", "reduceRight",
            "forEach", "some", "every", "find", "findIndex", "findLast",
            "findLastIndex", "join", "concat", "sort", "reverse", "fill",
            "flat", "flatMap", "keys", "values", "entries", "copyWithin",
            "at", "isArray", "from", "of",
        ],
        .object: [
            "keys", "values", "entries", "assign", "freeze", "isFrozen",
            "seal", "isSealed", "create", "defineProperty", "defineProperties",
            "getOwnPropertyDescriptor", "getOwnPropertyDescriptors",
            "getOwnPropertyNames", "getOwnPropertySymbols", "getPrototypeOf",
            "setPrototypeOf", "fromEntries", "is", "hasOwn",
        ],
        .reflect: [
            "get", "set", "has", "deleteProperty", "ownKeys", "getPrototypeOf",
            "apply", "construct", "defineProperty", "getOwnPropertyDescriptor",
            "isExtensible", "preventExtensions",
        ],
        .map: [
            "set", "get", "has", "delete", "clear", "forEach", "entries",
            "keys", "values", "size",
        ],
        .set: [
            "add", "has", "delete", "clear", "forEach", "entries", "keys",
            "values", "size",
        ],
        .promise: [
            "resolve", "reject", "all", "allSettled", "race", "any", "then",
            "catch", "finally",
        ],
        .math: [
            "floor", "ceil", "round", "trunc", "abs", "min", "max", "sign",
            "sqrt", "cbrt", "pow", "exp", "expm1", "log", "log1p", "log2",
            "log10", "sin", "cos", "tan", "asin", "acos", "atan", "atan2",
            "hypot", "clz32", "imul", "fround", "random",
        ],
        .number: [
            "parseInt", "parseFloat", "isFinite", "isNaN", "isInteger",
            "isSafeInteger",
        ],
        .string: [
            "charAt", "charCodeAt", "codePointAt", "slice", "substring",
            "substr", "indexOf", "lastIndexOf", "includes", "startsWith",
            "endsWith", "split", "replace", "replaceAll", "trim", "trimStart",
            "trimEnd", "padStart", "padEnd", "repeat", "toLowerCase",
            "toUpperCase", "toLocaleLowerCase", "toLocaleUpperCase",
            "fromCharCode", "fromCodePoint", "raw", "at", "localeCompare",
            "normalize", "match", "matchAll", "search",
        ],
        .json: [
            "parse", "stringify",
        ],
        .regexp: [
            "test", "exec",
        ],
        .symbol: [
            "iterator", "asyncIterator", "dispose", "toStringTag", "for",
            "keyFor",
        ],
    ]

    /// Returns `true` if `category` is in the finite intrinsic profile.
    public static func contains(_ category: MonaFiniteIntrinsicCategory) -> Bool {
        supportedOperations[category] != nil
    }

    /// Returns `true` if `operation` is a supported intrinsic within `category`.
    public static func supports(
        _ category: MonaFiniteIntrinsicCategory,
        _ operation: String
    ) -> Bool {
        guard let ops = supportedOperations[category] else { return false }
        return ops.contains(operation)
    }

    /// Gates an intrinsic operation. Throws
    /// `MonaFiniteIntrinsicError.unsupportedOperation` if the
    /// `category.operation` pair is outside the finite profile.
    ///
    /// This is the finite-port gate: the individual computation is routed by
    /// the caller; this method only admits or rejects the request.
    public static func perform(
        _ category: MonaFiniteIntrinsicCategory,
        _ operation: String
    ) throws {
        guard supports(category, operation) else {
            throw MonaFiniteIntrinsicError.unsupportedOperation(
                "\(category.rawValue).\(operation)"
            )
        }
    }

    /// Guarded execution: runs `body` only when `category.operation` is in the
    /// finite profile, returning its result. Otherwise throws
    /// `MonaFiniteIntrinsicError.unsupportedOperation` without running `body`.
    public static func perform<T>(
        _ category: MonaFiniteIntrinsicCategory,
        _ operation: String,
        _ body: () throws -> T
    ) throws -> T {
        guard supports(category, operation) else {
            throw MonaFiniteIntrinsicError.unsupportedOperation(
                "\(category.rawValue).\(operation)"
            )
        }
        return try body()
    }
}
