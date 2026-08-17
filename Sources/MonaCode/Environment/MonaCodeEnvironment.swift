// MonaCodeEnvironment.swift
//
// P00-T007 — Separate immutable UI localization profile from runtime locale.
//
// Defines the UI message profile (`MonaCodeEnvironmentProfile`), the typed
// rejection error (`MonaEnvironmentError`), and the aggregate environment
// (`MonaCodeEnvironment`) that holds both a runtime-locale snapshot and a UI
// message profile.
//
// The UI profile is selected ONLY from an explicit environment option. It is
// NEVER auto-derived from the runtime locale. The two are separate, unrelated
// types: `MonaRuntimeLocale` is a runtime-environment snapshot; the profile is
// an immutable enumeration. Unsupported profile identifiers are rejected with
// a typed `MonaEnvironmentError.unsupportedProfile` error.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// A typed error raised when a UI message-profile identifier is unsupported.
public enum MonaEnvironmentError: Error, Equatable, Sendable {
    /// The supplied profile identifier is not a supported profile.
    ///
    /// - Parameter identifier: The rejected identifier, preserved verbatim for
    ///   diagnostics (may be empty for blank/whitespace-only inputs).
    case unsupportedProfile(String)
}

/// The immutable UI message profile, selected only from an explicit
/// environment option.
///
/// `MonaCodeEnvironmentProfile` is an immutable enumeration. It is deliberately
/// unrelated to `MonaRuntimeLocale`: the profile is an explicit selection,
/// while the runtime locale is an environment snapshot. `MonaCodeEnvironment`
/// never derives the profile from the runtime locale.
public enum MonaCodeEnvironmentProfile: Equatable, Sendable {

    /// The default UI message profile.
    case `default`

    /// A custom UI message profile identified by an opaque string.
    case custom(String)

    /// Creates a profile from a raw identifier string, validating support.
    ///
    /// The identifier `"default"` maps to `.default`. Any other non-empty,
    /// non-whitespace-only identifier maps to `.custom(identifier)`.
    /// Empty or whitespace-only identifiers are unsupported and throw
    /// `MonaEnvironmentError.unsupportedProfile`.
    ///
    /// - Parameter identifier: The raw profile identifier to resolve.
    /// - Throws: `MonaEnvironmentError.unsupportedProfile` when the identifier
    ///   is empty or whitespace-only.
    public init(identifier: String) throws {
        let trimmed = identifier.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            throw MonaEnvironmentError.unsupportedProfile(identifier)
        }
        if trimmed == "default" {
            self = .default
        } else {
            self = .custom(trimmed)
        }
    }
}

/// The aggregate environment holding both the runtime-locale snapshot and the
/// UI message profile.
///
/// `MonaCodeEnvironment` carries exactly two fields:
///   - `runtimeLocale` — an immutable `MonaRuntimeLocale` snapshot captured at
///     startup.
///   - `profile` — an immutable `MonaCodeEnvironmentProfile` selected ONLY
///     from the explicit option passed to the initializer.
///
/// The profile is NEVER auto-derived from the runtime locale. Two environments
/// constructed with the same runtime locale but different explicit profiles
/// report different profiles.
public struct MonaCodeEnvironment: Sendable {

    /// The immutable runtime-locale snapshot.
    public let runtimeLocale: MonaRuntimeLocale

    /// The immutable UI message profile, selected only from the explicit
    /// environment option.
    public let profile: MonaCodeEnvironmentProfile

    /// Creates an environment from an explicit runtime-locale snapshot and an
    /// explicit UI message profile.
    ///
    /// The profile is taken verbatim; it is never derived from
    /// `runtimeLocale`.
    public init(
        runtimeLocale: MonaRuntimeLocale,
        profile: MonaCodeEnvironmentProfile
    ) {
        self.runtimeLocale = runtimeLocale
        self.profile = profile
    }

    /// Creates an environment from an explicit runtime-locale snapshot and a
    /// raw profile identifier string.
    ///
    /// The identifier is resolved via `MonaCodeEnvironmentProfile.init`
    /// (validating support). Unsupported identifiers throw
    /// `MonaEnvironmentError.unsupportedProfile`.
    ///
    /// - Parameters:
    ///   - runtimeLocale: The immutable runtime-locale snapshot.
    ///   - profileIdentifier: The raw UI message-profile identifier.
    /// - Throws: `MonaEnvironmentError.unsupportedProfile` when the identifier
    ///   is empty or whitespace-only.
    public init(
        runtimeLocale: MonaRuntimeLocale,
        profileIdentifier: String
    ) throws {
        self.runtimeLocale = runtimeLocale
        self.profile = try MonaCodeEnvironmentProfile(identifier: profileIdentifier)
    }
}
