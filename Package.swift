// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MonaCode",
    platforms: [
        .macOS("26.0"),
    ],
    products: [
        .library(name: "MonaCode", targets: ["MonaCode"]),
        .library(name: "MonaCodeAppKit", targets: ["MonaCodeAppKit"]),
        .library(name: "MonaCodeSwiftUI", targets: ["MonaCodeSwiftUI"]),
    ],
    targets: [
        // --- Product library targets (referenced by products above) ---
        .target(name: "MonaCode", path: "Sources/MonaCode"),
        // P05-T100 fix-forward: `MonaCodeAppKit` sources `import MonaCode`
        // (e.g. `MonaAXAnnouncementBridge`), so the target must declare the
        // dependency. Without it a fresh `swift build` after `swift package
        // clean` races past the MonaCode module and fails with
        // "no such module 'MonaCode'" in AppKit. This is a latent shared-
        // mechanism (build-graph) defect, fixed minimally + tested (clean
        // build) + recorded here. It does not change products/nonProductTargets
        // counts (products=3, nonProductTargets=3, fixtureTargets=0).
        .target(
            name: "MonaCodeAppKit",
            dependencies: ["MonaCode"],
            path: "Sources/MonaCodeAppKit"
        ),
        // P04-T015: MonaCodeSwiftUI wraps MonaCodeEditorView (P04-T014) and
        // owns the model reference, so it depends on MonaCodeAppKit + MonaCode.
        .target(
            name: "MonaCodeSwiftUI",
            dependencies: ["MonaCodeAppKit", "MonaCode"],
            path: "Sources/MonaCodeSwiftUI"
        ),

        // --- Non-product targets (not referenced by any product) ---
        // These three must be non-test targets so the package-graph checker
        // counts them as nonProductTargets (test targets are a separate
        // SwiftPM category and excluded from that count).
        //
        // P00-T012 structural integration: `benchmark-harness` is intentionally
        // a non-test `.target` (not `.testTarget`) so the package-graph
        // invariant holds (products=3, nonProductTargets=3, fixtureTargets=0).
        // Its XCTest sources compile as part of the module but are not
        // discovered by `swift test --filter`; Phase 00 verifies their STRUCTURE
        // (file existence + clean build) via the Node integration gate, not
        // empirical execution. The output state is `structurally verified`.
        // P07-T009: the sample host activates all three products (MonaCode +
        // MonaCodeAppKit + MonaCodeSwiftUI) — it constructs representatives from
        // each. The sample is a NON-PRODUCT executable target, so adding these
        // deps adds NO production dependencies (products=3 / nonProductTargets=3
        // preserved — same modify:none-override rationale as P04-T015's
        // `conformance-and-failure-injection` target; no cycle: the sample is a
        // non-product leaf).
        .executableTarget(
            name: "sample-macOS-host",
            dependencies: ["MonaCode", "MonaCodeAppKit", "MonaCodeSwiftUI"],
            path: "Sources/MonaCodeSample"
        ),
        .target(
            name: "conformance-and-failure-injection",
            // P04-T016: the Phase 04 closure suite exercises the SwiftUI
            // lifecycle wrappers (P04-T015 `MonaCodeEditor` /
            // `MonaSwiftUIEditorController`), so this target depends on
            // MonaCodeSwiftUI alongside MonaCode + MonaCodeAppKit. Same
            // controller ruling as P04-T015 (modify:none overridden by
            // functional necessity; preserves products=3 / nonProductTargets=3;
            // no cycle: MonaCodeSwiftUI already depends on MonaCodeAppKit +
            // MonaCode, and this target is a non-product leaf).
            dependencies: ["MonaCode", "MonaCodeAppKit", "MonaCodeSwiftUI"],
            path: "Tests/ConformanceAndFailureInjection"
        ),
        .target(name: "benchmark-harness", path: "Tests/BenchmarkHarness"),

        // --- Product test targets (SwiftPM test targets; excluded from
        // nonProductTargets because isTestTarget is true) ---
        .testTarget(
            name: "MonaCodeTests",
            dependencies: ["MonaCode", "conformance-and-failure-injection"],
            path: "Tests/MonaCodeTests",
            resources: [
                .copy("Fixtures/DifferentialFixtures"),
            ]
        ),
        .testTarget(
            name: "MonaCodeAppKitTests",
            // P04-T015: the SwiftUI lifecycle test `@testable import`s
            // MonaCodeSwiftUI alongside MonaCodeAppKit.
            dependencies: ["MonaCodeAppKit", "MonaCodeSwiftUI"],
            path: "Tests/MonaCodeAppKitTests"
        ),
    ]
)
