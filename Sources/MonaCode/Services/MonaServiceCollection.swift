// MonaServiceCollection.swift
//
// P07-T003 — Implement 40 standalone services and bounded session state.
//
// The service collection / instantiator: instantiates exactly the 40 S1-R
// standalone editor services with explicit global or per-editor lifetime
// ownership, and exposes their disposition partition for verification.
//
// This is the services layer Monaco's editor uses (bracket, configuration,
// clipboard (the Core service, not the AppKit one), etc.) — 40 retained
// services. Each service is classified into exactly one disposition
// (retained-native-core, fixed-standalone-semantic, native-adaptation,
// host-adaptation, session-memory, mixed-log-noop, baseline-noop,
// explicit-cut) and one lifetime (GLOBAL or PER-EDITOR).
//
// The collection holds no live objects: it is a typed registry of the 40
// service definitions and their ownership tags. Live native service instances
// are owned by their host layers (AppKit/MonaCodeAppKit); this Foundation-only
// target only declares the contract surface and the bounded session state.
//
// S1-R contract: monacode-s1r-standalone-service-contract-manifest.json
//   - `sourceClosure.standaloneDefaultServiceRegistrations: 40`
//   - `serviceDispositionCounts`: 14 + 2 + 10 + 2 + 1 + 1 + 8 + 2 = 40
//   - C04: "All 40 default services have exactly one classified native
//     disposition; no unclassified service or added host protocol exists."
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// The service collection / instantiator for the 40 S1-R standalone services.
///
/// `MonaServiceCollection.bootstrap()` returns the typed collection of exactly
/// 40 service definitions, each carrying its S1-R service identifier,
/// implementation identifier, disposition, and explicit lifetime ownership
/// tag. The collection is a pure value-typed registry; it does not construct
/// live host objects (those belong to AppKit/MonaCodeAppKit layers).
public struct MonaServiceCollection: Sendable, Equatable {

    /// The 40 instantiated service definitions, in S1-R manifest order.
    public let services: [MonaStandaloneService]

    /// Creates a collection wrapping the given 40 service definitions.
    ///
    /// - Precondition: `services.count == 40`.
    public init(services: [MonaStandaloneService]) {
        precondition(
            services.count == 40,
            "MonaServiceCollection requires exactly 40 S1-R services (got \(services.count))"
        )
        self.services = services
    }

    /// Bootstraps the collection with the 40 S1-R default service
    /// registrations.
    ///
    /// Every service's lifetime is `.global` because S1-R
    /// `standaloneDefaultServiceRegistrations: 40` are all `registerSingleton`
    /// calls (one instance for the whole process). Per-editor child state
    /// (e.g. a context-key child scope) is tracked in `MonaSessionStore`,
    /// not as a per-editor default registration.
    public static func bootstrap() -> MonaServiceCollection {
        MonaServiceCollection(services: MonaStandaloneServices.services)
    }

    /// The number of instantiated services (always 40 in S1-R).
    public var serviceCount: Int { services.count }

    /// The number of services with GLOBAL lifetime.
    public var globalLifetimeCount: Int {
        services.lazy.filter { $0.lifetime == .global }.count
    }

    /// The number of services with PER-EDITOR lifetime (0 in S1-R baseline).
    public var perEditorLifetimeCount: Int {
        services.lazy.filter { $0.lifetime == .perEditor }.count
    }

    /// A per-disposition count dictionary matching S1-R
    /// `serviceDispositionCounts` exactly.
    public var dispositionCounts: [MonaServiceDisposition: Int] {
        var counts: [MonaServiceDisposition: Int] = [:]
        for service in services {
            counts[service.disposition, default: 0] += 1
        }
        return counts
    }

    /// Looks up a service definition by its S1-R service identifier.
    public func service(forServiceId id: String) -> MonaStandaloneService? {
        services.first { $0.serviceId == id }
    }

    /// The list of explicit-cut (absent) service identifiers — capabilities
    /// that are NOT ported because they are absent in the S1-R baseline
    /// (WebWorker construction/execution, Tree-sitter library loading).
    public var explicitCutServiceIds: [String] {
        services
            .lazy
            .filter { $0.disposition == .explicitCut }
            .map(\.serviceId)
    }
}
