// MonaLocaleBoundaryTests.swift
//
// P00-T007 — Separate immutable UI localization profile from runtime locale.
//
// Verifies:
//   - `MonaRuntimeLocale` captures runtime locale, calendar, numbering system,
//     and time zone once at init as an immutable snapshot.
//   - `MonaCodeEnvironment` selects the UI message profile ONLY from the
//     explicit environment option — never auto-derived from the runtime locale.
//   - Unsupported profile identifiers are rejected with a typed
//     `MonaEnvironmentError.unsupportedProfile` error.
//   - The UI profile (immutable enumeration) is separate from the runtime
//     locale (immutable snapshot struct).

import XCTest
import MonaCode

final class MonaLocaleBoundaryTests: XCTestCase {

    // MARK: - MonaRuntimeLocale (immutable runtime snapshot)

    func testMonaRuntimeLocaleCapturesCurrentLocaleAtInit() {
        // `MonaRuntimeLocale` captures `Locale.current` once at init. The
        // snapshot is immutable: the captured identifier matches the system
        // locale at the time of capture.
        let before = Locale.current.identifier
        let snapshot = MonaRuntimeLocale()
        let after = Locale.current.identifier

        XCTAssertEqual(snapshot.locale.identifier, before)
        // Within a single test process the system locale is stable, so the
        // captured value also matches the post-init sample.
        XCTAssertEqual(snapshot.locale.identifier, after)
    }

    func testMonaRuntimeLocaleCapturesCurrentCalendarAtInit() {
        let snapshot = MonaRuntimeLocale()
        XCTAssertEqual(snapshot.calendar.identifier, Calendar.current.identifier)
    }

    func testMonaRuntimeLocaleCapturesCurrentTimeZoneAtInit() {
        let snapshot = MonaRuntimeLocale()
        XCTAssertEqual(snapshot.timeZone.identifier, TimeZone.current.identifier)
    }

    func testMonaRuntimeLocaleCapturesNumberingSystemAsString() {
        let snapshot = MonaRuntimeLocale()
        // The numbering system is captured as a non-empty string (e.g. "latn").
        let ns: String = snapshot.numberingSystem
        XCTAssertFalse(ns.isEmpty)
    }

    func testMonaRuntimeLocaleIsImmutableValueSnapshot() {
        // The snapshot is a value type with fixed stored properties; re-reading
        // the same instance yields identical values (value semantics, no
        // mutation possible after init).
        let snapshot = MonaRuntimeLocale()
        let locale = snapshot.locale
        let calendar = snapshot.calendar
        let numberingSystem = snapshot.numberingSystem
        let timeZone = snapshot.timeZone

        XCTAssertEqual(snapshot.locale.identifier, locale.identifier)
        XCTAssertEqual(snapshot.calendar.identifier, calendar.identifier)
        XCTAssertEqual(snapshot.numberingSystem, numberingSystem)
        XCTAssertEqual(snapshot.timeZone.identifier, timeZone.identifier)
    }

    func testMonaRuntimeLocaleAcceptsExplicitlyInjectedFields() {
        // A memberwise init is available so callers (and tests) can inject
        // deterministic fields instead of capturing the live environment.
        let locale = Locale(identifier: "fr_FR")
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let timeZone = TimeZone(identifier: "Europe/Paris")!

        let snapshot = MonaRuntimeLocale(
            locale: locale,
            calendar: calendar,
            numberingSystem: "latn",
            timeZone: timeZone
        )

        XCTAssertEqual(snapshot.locale.identifier, "fr_FR")
        XCTAssertEqual(snapshot.calendar.identifier, .gregorian)
        XCTAssertEqual(snapshot.numberingSystem, "latn")
        XCTAssertEqual(snapshot.timeZone.identifier, "Europe/Paris")
    }

    // MARK: - MonaCodeEnvironment (explicit profile selection only)

    func testMonaCodeEnvironmentHoldsRuntimeLocaleAndProfile() {
        let runtimeLocale = MonaRuntimeLocale()
        let env = MonaCodeEnvironment(runtimeLocale: runtimeLocale, profile: .default)

        // The environment exposes both a runtime locale and a UI profile.
        XCTAssertEqual(env.profile, .default)
        XCTAssertEqual(env.runtimeLocale.locale.identifier, runtimeLocale.locale.identifier)
    }

    func testMonaCodeEnvironmentProfileDoesNotAutoDeriveFromRuntimeLocale() {
        // The UI profile is selected ONLY from the explicit option passed to
        // the environment. Two environments sharing the same runtime locale but
        // receiving different explicit profiles must report different profiles —
        // the profile is never derived from the runtime locale.
        let runtimeLocale = MonaRuntimeLocale()

        let defaultEnv = MonaCodeEnvironment(runtimeLocale: runtimeLocale, profile: .default)
        let customEnv = MonaCodeEnvironment(
            runtimeLocale: runtimeLocale,
            profile: .custom("fr-FR")
        )

        XCTAssertEqual(defaultEnv.profile, .default)
        XCTAssertEqual(customEnv.profile, .custom("fr-FR"))
        XCTAssertNotEqual(defaultEnv.profile, customEnv.profile)
        // Both share the identical runtime locale snapshot.
        XCTAssertEqual(
            defaultEnv.runtimeLocale.locale.identifier,
            customEnv.runtimeLocale.locale.identifier
        )
    }

    func testMonaCodeEnvironmentProfileIsSeparateTypeFromRuntimeLocale() {
        // The UI profile (`MonaCodeEnvironmentProfile`) and the runtime locale
        // (`MonaRuntimeLocale`) are separate, unrelated types. The profile is
        // an immutable enumeration; the runtime locale is an immutable snapshot
        // struct. Neither derives from the other.
        let runtimeLocale = MonaRuntimeLocale()
        let env = MonaCodeEnvironment(
            runtimeLocale: runtimeLocale,
            profile: .custom("de-DE")
        )

        let profile: MonaCodeEnvironmentProfile = env.profile
        XCTAssertEqual(profile, .custom("de-DE"))

        let locale: MonaRuntimeLocale = env.runtimeLocale
        XCTAssertFalse(locale.locale.identifier.isEmpty)
    }

    // MARK: - Typed error for unsupported profile identifiers

    func testProfileFromIdentifierRejectsEmptyWithTypedError() {
        // Constructing a profile from an unsupported (empty) identifier must
        // throw a typed `MonaEnvironmentError.unsupportedProfile`.
        do {
            _ = try MonaCodeEnvironmentProfile(identifier: "")
            XCTFail("Expected unsupportedProfile error to be thrown")
        } catch let error as MonaEnvironmentError {
            guard case .unsupportedProfile(let id) = error else {
                return XCTFail("Expected .unsupportedProfile, got \(error)")
            }
            XCTAssertEqual(id, "")
        } catch {
            XCTFail("Expected MonaEnvironmentError, got \(error)")
        }
    }

    func testProfileFromIdentifierRejectsWhitespaceOnlyWithTypedError() {
        do {
            _ = try MonaCodeEnvironmentProfile(identifier: "   ")
            XCTFail("Expected unsupportedProfile error to be thrown")
        } catch let error as MonaEnvironmentError {
            guard case .unsupportedProfile = error else {
                return XCTFail("Expected .unsupportedProfile, got \(error)")
            }
        } catch {
            XCTFail("Expected MonaEnvironmentError, got \(error)")
        }
    }

    func testProfileFromIdentifierAcceptsDefault() throws {
        let profile = try MonaCodeEnvironmentProfile(identifier: "default")
        XCTAssertEqual(profile, .default)
    }

    func testProfileFromIdentifierAcceptsCustom() throws {
        let profile = try MonaCodeEnvironmentProfile(identifier: "fr-FR")
        XCTAssertEqual(profile, .custom("fr-FR"))
    }

    func testEnvironmentThrowingInitRejectsUnsupportedProfileIdentifier() {
        // The environment's throwing initializer (profile from a raw
        // identifier) must propagate the typed error for unsupported ids.
        let runtimeLocale = MonaRuntimeLocale()
        do {
            _ = try MonaCodeEnvironment(
                runtimeLocale: runtimeLocale,
                profileIdentifier: ""
            )
            XCTFail("Expected unsupportedProfile error to be thrown")
        } catch let error as MonaEnvironmentError {
            guard case .unsupportedProfile(let id) = error else {
                return XCTFail("Expected .unsupportedProfile, got \(error)")
            }
            XCTAssertEqual(id, "")
        } catch {
            XCTFail("Expected MonaEnvironmentError, got \(error)")
        }
    }
}
