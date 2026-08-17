// MonaRandomDoubleSource.swift
//
// P00-T006 — Implement deterministic random, cryptographic random, and
// Number-to-string sources.
//
// This file defines the injectable shared random sequence protocol used by
// every retained MonaCode consumer that needs a `Double` in [0, 1). The
// protocol is reference-shaped by convention (the default impl is a class) so
// that a single injected instance is shared across consumers and successive
// draws advance one common sequence — never copying the generator state on
// injection.
//
// The default implementation wraps `SystemRandomNumberGenerator`, the Swift
// standard library's cryptographic-quality generator (backed by the platform
// CSPRNG on Apple platforms). Conformers that need deterministic sequences for
// testing can supply their own conformer without touching production code.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.
// `SystemRandomNumberGenerator` is part of the Swift standard library and needs
// no separate import.

import Foundation

/// Injectable shared random sequence producing `Double` values in the
/// half-open unit interval `[0, 1)`.
///
/// The protocol is non-mutating so it can be used through an existential
/// `any MonaRandomDoubleSource` with `let`. Implementations that advance
/// internal state should use a reference type (class) or manage their own
/// mutable storage, so that a single injected instance is shared across all
/// consumers and successive draws advance one common sequence.
///
/// Values are binary64 (`Double`) to preserve the injected trace format
/// required by the frozen vectors.
public protocol MonaRandomDoubleSource {
    /// Returns the next `Double` in `[0, 1)`.
    func nextDouble() -> Double
}

/// Default implementation of `MonaRandomDoubleSource`.
///
/// Wraps `SystemRandomNumberGenerator` (the Swift standard library's
/// cryptographic-quality generator) and produces `Double` values in `[0, 1)`
/// via `Double.random(in:using:)`, which yields full binary64 precision across
/// the half-open unit interval.
///
/// This is a `final class` (not a struct) so that a single injected instance is
/// shared: every consumer that receives the same `MonaSystemRandomDoubleSource`
/// draws from one advancing sequence rather than independent copies of the
/// generator state.
public final class MonaSystemRandomDoubleSource: MonaRandomDoubleSource {

    private var generator: SystemRandomNumberGenerator

    /// Creates a shared random source.
    ///
    /// - Parameter generator: A `SystemRandomNumberGenerator` to seed the
    ///   sequence. Defaults to a fresh system generator.
    public init(generator: SystemRandomNumberGenerator = SystemRandomNumberGenerator()) {
        self.generator = generator
    }

    public func nextDouble() -> Double {
        // `Double.random(in: 0..<1, using:)` produces a uniformly distributed
        // binary64 `Double` in [0, 1) with full mantissa precision. The call is
        // mutating on `generator`, but `nextDouble` is non-mutating on `self`
        // because `self` is a class and `generator` is a `var` property.
        return Double.random(in: 0.0 ..< 1.0, using: &generator)
    }
}
