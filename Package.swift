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
        .target(name: "MonaCodeAppKit", path: "Sources/MonaCodeAppKit"),
        .target(name: "MonaCodeSwiftUI", path: "Sources/MonaCodeSwiftUI"),

        // --- Non-product targets (not referenced by any product) ---
        // These three must be non-test targets so the package-graph checker
        // counts them as nonProductTargets (test targets are a separate
        // SwiftPM category and excluded from that count).
        .executableTarget(name: "sample-macOS-host", path: "Sources/MonaCodeSample"),
        .target(name: "conformance-and-failure-injection", path: "Tests/ConformanceAndFailureInjection"),
        .target(name: "benchmark-harness", path: "Tests/BenchmarkHarness"),

        // --- Product test targets (SwiftPM test targets; excluded from
        // nonProductTargets because isTestTarget is true) ---
        .testTarget(
            name: "MonaCodeTests",
            dependencies: ["MonaCode"],
            path: "Tests/MonaCodeTests",
            resources: [
                .copy("Fixtures/DifferentialFixtures"),
            ]
        ),
        .testTarget(
            name: "MonaCodeAppKitTests",
            dependencies: ["MonaCodeAppKit"],
            path: "Tests/MonaCodeAppKitTests"
        ),
    ]
)
