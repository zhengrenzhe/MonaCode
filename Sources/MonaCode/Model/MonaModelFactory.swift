// MonaModelFactory.swift
//
// P01-T011 — Implement model construction and large-model state.
//
// `MonaModelFactory` is the Swift counterpart of Monaco's model-construction
// seam (monaco-editor 0.56.0), fixed by the H2-R `modelConstruction` closure.
// It constructs a `MonaCodeModel` atomically: model identity, URI, options,
// Piece Tree, and lifetime registration are established as ONE ordered unit.
//
// Atomicity contract (H2-R failure claim):
//   1. Validate every fallible input BEFORE any model is allocated.
//      - Options: `tabSize >= 1`, `indentSize >= 1`.
//      - URI: scheme is non-empty AND `toString()` succeeds (no lone
//        surrogate in any component).
//   2. Construct the Piece Tree + `MonaCodeModel` (identity, URI, options,
//      Piece Tree, version, events) in one step.
//   3. Determine the sticky `MonaLargeModelState` from the initial text.
//   4. Run lifetime registration. If registration fails, DISPOSE the model
//      and rethrow — no partial model is ever published to the caller.
//
// The large-model state is computed from the initial text's UTF-16 length and
// line count via `MonaLargeModelState.state(initialLength:initialLineCount:)`
// and handed to the registration closure so lifetime owners can branch on the
// one-way state without recomputing it.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// Errors raised by `MonaModelFactory` when construction is rejected or rolls
/// back. Every case corresponds to a checkpoint where NO partial model is
/// published: the factory either returns a fully-constructed model or throws.
public enum MonaModelFactoryError: Error, Equatable {

    /// The provided `MonaModelOptions` were invalid (`tabSize < 1` or
    /// `indentSize < 1`). Raised before any model is allocated.
    case invalidOptions(String)

    /// The provided `MonaURI` was invalid — the scheme was empty (the
    /// "empty/null" URI case) or `toString()` failed (a lone surrogate in a
    /// component). Raised before any model is allocated.
    case invalidURI(String)

    /// Lifetime registration failed after the model was constructed. The model
    /// has been disposed; no partial model is published to the caller.
    case registrationFailed(String)
}

/// Constructs `MonaCodeModel` instances atomically.
///
/// `MonaModelFactory` is the single entry point for model construction. It
/// validates fallible inputs, constructs the model identity / URI / options /
/// Piece Tree / lifetime registration as one ordered unit, and rolls back
/// (disposes the model) if any step after allocation fails — so a caller never
/// observes a partially-constructed model.
///
/// The factory is a `Sendable` value with no mutable state: every
/// `createModel` call is independent and safe to invoke from any isolation
/// domain. Lifetime registration is supplied by the caller as a throwing
/// closure, so P01-T012 (the lifetime registries) plugs in without changing
/// the factory's contract.
public final class MonaModelFactory: Sendable {

    /// Creates a factory. Stateless; all construction state lives per-call.
    public init() {}

    // MARK: - Construction from text

    /// Atomically creates a `MonaCodeModel` from `text`.
    ///
    /// Steps, in order:
    ///   1. Validate `options` and `uri` (no allocation yet).
    ///   2. Construct the Piece Tree + `MonaCodeModel` (identity, URI, options,
    ///      version, events).
    ///   3. Determine the sticky `MonaLargeModelState` from the initial text.
    ///   4. Run `register`. If it throws, dispose the model and rethrow as
    ///      `MonaModelFactoryError.registrationFailed`.
    ///
    /// - Parameters:
    ///   - text: The initial text, stored as raw UTF-16 in the Piece Tree.
    ///   - options: The model options. Defaults to `MonaModelOptions.defaults`.
    ///   - uri: The model URI. Must have a non-empty scheme and format cleanly.
    ///   - register: Optional lifetime-registration closure, invoked with the
    ///     fully-constructed model and its pre-computed large-model state. A
    ///     throw triggers rollback: the model is disposed and the error is
    ///     rethrown as `MonaModelFactoryError.registrationFailed`.
    /// - Returns: A fully-constructed, registered `MonaCodeModel`.
    /// - Throws: `MonaModelFactoryError` for any rejection or rollback.
    public func createModel(
        text: String,
        options: MonaModelOptions = .defaults,
        uri: MonaURI,
        register: ((MonaCodeModel, MonaLargeModelState) throws -> Void)? = nil
    ) throws -> MonaCodeModel {
        // 1. Validate fallible inputs BEFORE any allocation.
        try Self.validate(options: options)
        try Self.validate(uri: uri)

        // 2. Construct the model (Piece Tree + identity + options + version).
        let model = MonaCodeModel(text: text, options: options, uri: uri)

        // 3. Determine the sticky large-model state from the initial text.
        let largeState = MonaLargeModelState.state(
            initialLength: model.getValueLength(),
            initialLineCount: model.getLineCount()
        )

        // 4. Lifetime registration. Roll back on failure: dispose the model
        //    and rethrow so no partial model is published.
        if let register {
            do {
                try register(model, largeState)
            } catch {
                model.dispose()
                throw MonaModelFactoryError.registrationFailed("\(error)")
            }
        }
        return model
    }

    /// Atomically creates a `MonaCodeModel` from raw UTF-16 `units`.
    ///
    /// Preserves isolated surrogates verbatim (the Piece Tree never repairs
    /// them). Validation, large-model-state determination, and rollback
    /// semantics are identical to the `text:` overload.
    public func createModel(
        units: [UInt16],
        options: MonaModelOptions = .defaults,
        uri: MonaURI,
        register: ((MonaCodeModel, MonaLargeModelState) throws -> Void)? = nil
    ) throws -> MonaCodeModel {
        try Self.validate(options: options)
        try Self.validate(uri: uri)

        let model = MonaCodeModel(units: units, options: options, uri: uri)
        let largeState = MonaLargeModelState.state(
            initialLength: model.getValueLength(),
            initialLineCount: model.getLineCount()
        )

        if let register {
            do {
                try register(model, largeState)
            } catch {
                model.dispose()
                throw MonaModelFactoryError.registrationFailed("\(error)")
            }
        }
        return model
    }

    // MARK: - Validation (no allocation; pre-construction checkpoints)

    /// Validates `options`: `tabSize >= 1` and `indentSize >= 1`. Throws
    /// `invalidOptions` otherwise. Called before any model is allocated.
    private static func validate(options: MonaModelOptions) throws {
        if options.tabSize < 1 {
            throw MonaModelFactoryError.invalidOptions(
                "tabSize must be >= 1 (got \(options.tabSize))"
            )
        }
        if options.indentSize < 1 {
            throw MonaModelFactoryError.invalidOptions(
                "indentSize must be >= 1 (got \(options.indentSize))"
            )
        }
    }

    /// Validates `uri`: the scheme must be non-empty (the "empty/null" URI
    /// rejection) and `toString()` must succeed (no lone surrogate). Throws
    /// `invalidURI` otherwise. Called before any model is allocated.
    private static func validate(uri: MonaURI) throws {
        if uri.scheme.isEmpty {
            throw MonaModelFactoryError.invalidURI("URI scheme must be non-empty")
        }
        do {
            _ = try uri.toString()
        } catch {
            throw MonaModelFactoryError.invalidURI(
                "URI toString failed (\(error))"
            )
        }
    }
}
