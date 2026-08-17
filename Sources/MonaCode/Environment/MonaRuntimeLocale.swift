// MonaRuntimeLocale.swift
//
// P00-T007 — Separate immutable UI localization profile from runtime locale.
//
// Captures the runtime locale, calendar, numbering system, and time zone once
// at init as an immutable snapshot. The snapshot reflects the process
// environment at the moment of capture (`Locale.current`, `Calendar.current`,
// `TimeZone.current`); it never auto-updates and is not influenced by any UI
// message profile selection.
//
// This is the RUNTIME locale: a mutable-environment snapshot frozen at a point
// in time. It is deliberately a separate type from the UI message profile
// (`MonaCodeEnvironmentProfile`), which is an immutable enumeration selected
// only from an explicit environment option.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// An immutable snapshot of the runtime locale, calendar, numbering system,
/// and time zone, captured once at initialization.
///
/// `MonaRuntimeLocale` freezes the live process environment
/// (`Locale.current`, `Calendar.current`, `TimeZone.current`, and the current
/// numbering system) at the moment of capture. All stored properties are
/// `let`-bound: the snapshot never mutates and never auto-updates after init.
///
/// This type is the RUNTIME locale. It is intentionally unrelated to the UI
/// message profile (`MonaCodeEnvironmentProfile`): the runtime locale is an
/// environment snapshot, while the UI profile is an explicit, immutable
/// selection. `MonaCodeEnvironment` never derives the UI profile from this
/// snapshot.
public struct MonaRuntimeLocale: Sendable {

    /// The runtime `Locale` captured at init (`Locale.current`).
    public let locale: Locale

    /// The runtime `Calendar` captured at init (`Calendar.current`).
    public let calendar: Calendar

    /// The runtime numbering-system identifier captured at init, as a
    /// non-empty string (e.g. `"latn"`, `"arab"`).
    public let numberingSystem: String

    /// The runtime `TimeZone` captured at init (`TimeZone.current`).
    public let timeZone: TimeZone

    /// Captures the live runtime environment once, as an immutable snapshot.
    ///
    /// The four fields are read from `Locale.current`, `Calendar.current`,
    /// `TimeZone.current`, and the current numbering system at the instant
    /// of construction, then frozen. Subsequent changes to the system locale
    /// or time zone are NOT reflected by this instance.
    public init() {
        let currentLocale = Locale.current
        self.locale = currentLocale
        self.calendar = Calendar.current
        self.timeZone = TimeZone.current
        // Capture the numbering-system identifier. The locale exposes a
        // non-optional `Locale.NumberingSystem` on the supported platform; fall
        // back to "latn" (the universal default) only when its identifier is
        // unexpectedly empty.
        let identifier = currentLocale.numberingSystem.identifier
        self.numberingSystem = identifier.isEmpty ? "latn" : identifier
    }

    /// Creates a runtime-locale snapshot from explicitly injected fields.
    ///
    /// Used by tests (and by callers that already hold a fixed environment) to
    /// construct a deterministic snapshot without reading the live process
    /// environment. The stored fields are frozen exactly as supplied.
    public init(
        locale: Locale,
        calendar: Calendar,
        numberingSystem: String,
        timeZone: TimeZone
    ) {
        self.locale = locale
        self.calendar = calendar
        self.numberingSystem = numberingSystem
        self.timeZone = timeZone
    }
}
