// ColdLaunchManager.swift
//
// P00-T010 — Enforce font provenance, cold launch, display isolation, and refresh cells.
//
// `ColdLaunchManager` runs each cold sample with a fresh profile and a fresh
// process tree, records the launch→ready latency, and requires the process tree
// to fully exit before the next launch. A Q1-R4 active block is exactly 50
// consecutive cold launches.
//
// Q1-R4 environment/font/cold closure (verification-q1r4-environment-font-cold-closure):
//   - Active batch: each valid block completes 50 cold launches consecutively.
//   - Each launch uses a fresh profile + a new process tree.
//   - launch→ready latency is recorded separately; after ready the host
//     terminates normally.
//   - The process tree must fully exit before the next launch.
//   - powermetrics integrates only complete 1-second intervals.
//
// The manager is a pure validator of the recorded samples; it does not spawn
// processes itself (the launcher closure supplies each sample). This keeps the
// harness deterministic and testable while still enforcing every Q1-R4 cold
// invariant on the recorded data.
//
// MonaCode is a Foundation-only boundary: `import Foundation` is the sole
// import. This file lives in the `benchmark-harness` non-product target.

import Foundation

// MARK: - ColdLaunchSample

/// One recorded cold-launch sample. Each field is a Q1-R4 invariant that
/// `ColdLaunchManager` validates.
public struct ColdLaunchSample: Equatable, Sendable {
    /// The 0-based position of this launch within its 50-launch block.
    public let index: Int
    /// `true` iff a fresh profile was used for this launch (no reuse).
    public let freshProfile: Bool
    /// `true` iff a fresh process tree was spawned for this launch.
    public let freshProcessTree: Bool
    /// `true` iff the process tree fully exited before the next launch began
    /// (or before the block completed, for the last sample).
    public let processTreeExited: Bool
    /// The launch→ready latency in milliseconds. Must be finite and strictly
    /// positive.
    public let launchToReadyMs: Double

    public init(
        index: Int,
        freshProfile: Bool,
        freshProcessTree: Bool,
        processTreeExited: Bool,
        launchToReadyMs: Double
    ) {
        self.index = index
        self.freshProfile = freshProfile
        self.freshProcessTree = freshProcessTree
        self.processTreeExited = processTreeExited
        self.launchToReadyMs = launchToReadyMs
    }
}

// MARK: - ColdLaunchError

/// Errors raised while validating a cold-launch block. Each carries the index
/// of the offending sample so the caller can attribute the failure.
public enum ColdLaunchError: Error, Equatable, Sendable {
    /// A sample did not use a fresh profile.
    case staleProfile(index: Int)
    /// A sample did not spawn a fresh process tree.
    case staleProcessTree(index: Int)
    /// A sample's process tree did not fully exit before the next launch.
    case processTreeNotExited(index: Int)
    /// A sample's launch→ready latency was non-positive or non-finite.
    case nonPositiveLatency(index: Int)
    /// The block did not complete the required number of cold launches.
    case insufficientSamples(expected: Int, actual: Int)
}

// MARK: - ColdLaunchManager

/// Runs each cold sample with a fresh profile and a fresh process tree, records
/// the launch→ready latency, and enforces the Q1-R4 cold-launch invariants.
public final class ColdLaunchManager {

    /// A Q1-R4 active block is exactly 50 consecutive cold launches.
    public static let samplesPerBlock: Int = 50

    public init() {}

    /// Runs a 50-launch cold block. The `launcher` closure is invoked exactly
    /// `samplesPerBlock` times, once per index 0..<50, and must return the
    /// recorded sample for that index. Each sample is validated as it is
    /// produced; the first violation aborts the block.
    ///
    /// - Parameter launcher: A closure that produces the recorded sample for a
    ///   given launch index. It is called exactly `samplesPerBlock` times.
    /// - Returns: The validated cold-launch samples, in index order.
    /// - Throws: `ColdLaunchError` on the first violating sample.
    public func runBatch(
        launcher: (Int) -> ColdLaunchSample
    ) throws -> [ColdLaunchSample] {
        var samples: [ColdLaunchSample] = []
        samples.reserveCapacity(Self.samplesPerBlock)
        for index in 0..<Self.samplesPerBlock {
            let sample = launcher(index)
            try validate(sample)
            samples.append(sample)
        }
        return samples
    }

    // MARK: - Validation

    /// Validates one cold-launch sample against the Q1-R4 invariants.
    private func validate(_ sample: ColdLaunchSample) throws {
        guard sample.freshProfile else {
            throw ColdLaunchError.staleProfile(index: sample.index)
        }
        guard sample.freshProcessTree else {
            throw ColdLaunchError.staleProcessTree(index: sample.index)
        }
        guard sample.processTreeExited else {
            throw ColdLaunchError.processTreeNotExited(index: sample.index)
        }
        guard sample.launchToReadyMs.isFinite, sample.launchToReadyMs > 0.0 else {
            throw ColdLaunchError.nonPositiveLatency(index: sample.index)
        }
    }
}
