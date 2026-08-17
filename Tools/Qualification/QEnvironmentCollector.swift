// Tools/Qualification/QEnvironmentCollector.swift
//
// P00-T011 — Collect a privacy-filtered QEnvironmentID and enforce formal preflight.
//
// Collects the exact OS, toolchain, architecture, display, input-source,
// runtime-locale, Chrome, and ICU fields fixed by G5-R. Rejects serial,
// account, user, UUID, and UDID values recursively. Requires
// externalDisplayCount equal to zero for every formal correctness or
// performance run.
//
// Usage:
//   xcrun swift Tools/Qualification/QEnvironmentCollector.swift
//       Collects the live qualification environment, produces a
//       privacy-filtered QEnvironmentID (SHA-256 of the collected fields),
//       and enforces the formal preflight.
//       exit 0  — qualified (externalDisplayCount == 0, privacy pass)
//       exit 1  — formal preflight rejected (externalDisplayCount != 0,
//                 privacy pass; the full record is still printed to stdout
//                 for auditability)
//       exit 2  — privacy violation (no QEnvironmentId emitted)
//
//   xcrun swift Tools/Qualification/QEnvironmentCollector.swift --audit <path>
//       Read a JSON record from <path>, run the recursive privacy audit only,
//       and print { "status": "ok"|"privacy-violation", "findings": [...] }.
//       exit 0  — no forbidden keys or UUID-shaped values
//       exit 2  — at least one forbidden identity found
//
// Network is never used. Chrome binary/ICU data hashes are computed locally;
// chromium/v8/ICU source provenance is pinned from the G5-R contract.

import Foundation
import CryptoKit

// MARK: - Pinned comparator provenance (G5-R, network-free)

let pinnedProvenance: [String: Any] = [
    "chromiumTagCommit": "41fa82442390a4d4456c78f2d69a832d5720cb27",
    "v8": [
        "version": "15.1.206.17",
        "sourceCommit": "00c2754b59cf5f79b323950c63b07cfb1a8377d4"
    ],
    "icu": [
        "version": "78.2",
        "sourceCommit": "d578f2e8b7bd5938e21cfb6bf15c079e0aa5b738"
    ],
    "timeSource": [
        "file": "base/time/time_apple.mm",
        "sha256": "0015cb2fa5ee082bb61f07e24c150d161b08a7148143914d43c58f4850c68134"
    ]
]

let chromeRoot = "/Applications/Google Chrome.app/Contents"
let chromeBinary = "\(chromeRoot)/MacOS/Google Chrome"
let chromeInfo = "\(chromeRoot)/Info.plist"
let chromeIcu = "\(chromeRoot)/Frameworks/Google Chrome Framework.framework/Versions/Current/Resources/icudtl.dat"

// MARK: - Shell helpers

struct ShellError: Error {
    let command: String
    let message: String
}

func runText(_ executable: String, _ arguments: [String] = []) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()
    do {
        try process.run()
    } catch {
        throw ShellError(command: executable, message: "failed to launch: \(error.localizedDescription)")
    }
    process.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard process.terminationStatus == 0 else {
        throw ShellError(command: executable, message: "exit \(process.terminationStatus)")
    }
    return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}

func runJSON(_ executable: String, _ arguments: [String] = []) throws -> Any {
    let text = try runText(executable, arguments)
    guard let data = text.data(using: .utf8) else {
        throw ShellError(command: executable, message: "non-utf8 output")
    }
    return try JSONSerialization.jsonObject(with: data, options: [])
}

func capture(_ pattern: String, in value: String, label: String) throws -> String {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
        throw ShellError(command: label, message: "invalid regex")
    }
    let range = NSRange(value.startIndex..., in: value)
    if let match = regex.firstMatch(in: value, options: [], range: range),
       match.numberOfRanges >= 2,
       let r = Range(match.range(at: 1), in: value) {
        return String(value[r])
    }
    throw ShellError(command: label, message: "no match for \(pattern)")
}

// MARK: - Crypto helpers

func sha256File(_ path: String) throws -> String {
    guard let handle = FileHandle(forReadingAtPath: path) else {
        throw ShellError(command: path, message: "cannot open file")
    }
    defer { try? handle.close() }
    var hasher = SHA256()
    while true {
        let chunk = handle.readData(ofLength: 1 << 20) // 1 MiB
        if chunk.isEmpty { break }
        hasher.update(data: chunk)
    }
    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
}

func sha256String(_ value: String) -> String {
    let data = value.data(using: .utf8) ?? Data()
    return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

// MARK: - Display / input parsing

struct Resolution {
    let width: Int
    let height: Int
    let refreshHz: Double?
}

func parseResolution(_ value: String?) -> Resolution? {
    guard let value, !value.isEmpty else { return nil }
    let pattern = #"(\d+)\s*x\s*(\d+)(?:\s*@\s*([0-9.]+)Hz)?"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
        return nil
    }
    let range = NSRange(value.startIndex..., in: value)
    guard let match = regex.firstMatch(in: value, options: [], range: range),
          let wR = Range(match.range(at: 1), in: value),
          let hR = Range(match.range(at: 2), in: value),
          let width = Int(value[wR]),
          let height = Int(value[hR]) else {
        return nil
    }
    var refresh: Double? = nil
    if match.numberOfRanges >= 4, let rR = Range(match.range(at: 3), in: value) {
        refresh = Double(value[rR])
    }
    return Resolution(width: width, height: height, refreshHz: refresh)
}

func safeDisplay(_ raw: [String: Any]) -> [String: Any] {
    let connectionType = raw["spdisplays_connection_type"] as? String
    let builtIn = connectionType == "spdisplays_internal"
    let pixels = parseResolution(raw["_spdisplays_pixels"] as? String)
    let logical = parseResolution(
        (raw["spdisplays_resolution"] as? String) ?? (raw["_spdisplays_resolution"] as? String)
    )
    let backingScale: Double?
    if let p = pixels, let l = logical, l.width != 0 {
        backingScale = Double(p.width) / Double(l.width)
    } else {
        backingScale = nil
    }
    // The raw system_profiler record carries display serial numbers
    // (_spdisplays_display-serial-number, spdisplays_display-serial-number).
    // They are deliberately NOT copied: only non-identifying slot geometry.
    var name = raw["_name"] as? String ?? "display"
    let lgRegex = try? NSRegularExpression(pattern: "^LG\\b", options: [])
    if let lgRegex,
       lgRegex.firstMatch(in: name, options: [], range: NSRange(name.startIndex..., in: name)) != nil {
        name = "LG display"
    }
    return [
        "label": builtIn ? "Built-in display" : name,
        "connection": builtIn ? "built-in" : "external",
        "pixels": pixels.map { ["width": $0.width, "height": $0.height] } ?? NSNull(),
        "logicalPoints": logical.map { ["width": $0.width, "height": $0.height] } ?? NSNull(),
        "backingScale": backingScale ?? NSNull(),
        "refreshHz": (logical?.refreshHz).map { $0 } ?? NSNull()
    ] as [String: Any]
}

func parseInputSourceIDs(_ text: String) -> [String] {
    var ids = Set<String>()
    let layoutRegex = try? NSRegularExpression(pattern: #"KeyboardLayout Name"?\s*=\s*"?(?:(?!;|\n|"))([^;\n"]+)"#, options: [])
    if let layoutRegex {
        let range = NSRange(text.startIndex..., in: text)
        layoutRegex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            if let match, let r = Range(match.range(at: 1), in: text) {
                ids.insert("keyboard-layout:" + text[r].trimmingCharacters(in: .whitespaces))
            }
        }
    }
    let modeRegex = try? NSRegularExpression(pattern: #""Input Mode"\s*=\s*"([^"]+)""#, options: [])
    if let modeRegex {
        let range = NSRange(text.startIndex..., in: text)
        modeRegex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            if let match, let r = Range(match.range(at: 1), in: text) {
                ids.insert("input-mode:" + text[r])
            }
        }
    }
    return ids.sorted()
}

func parseAppleLanguages(_ text: String) -> [String] {
    let regex = try? NSRegularExpression(pattern: #""([^"]+)""#, options: [])
    var out: [String] = []
    if let regex {
        let range = NSRange(text.startIndex..., in: text)
        regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            if let match, let r = Range(match.range(at: 1), in: text) {
                out.append(String(text[r]))
            }
        }
    }
    return out
}

func currentTimeZone() -> String {
    let resolved = (try? FileManager.default.destinationOfSymbolicLink(atPath: "/etc/localtime")) ?? "/etc/localtime"
    let marker = "/zoneinfo/"
    if let r = resolved.range(of: marker) {
        return String(resolved[r.upperBound...])
    }
    return resolved
}

// MARK: - Node discovery

func nodeVersion() -> String {
    let candidates = [
        "/opt/homebrew/Cellar/node/26.7.0/bin/node",
        "/opt/homebrew/bin/node",
        "/usr/local/bin/node"
    ]
    for candidate in candidates {
        if FileManager.default.isExecutableFile(atPath: candidate) {
            if let v = try? runText(candidate, ["--version"]) {
                return v
            }
        }
    }
    // Fallback to PATH lookup via /usr/bin/env.
    if let v = try? runText("/usr/bin/env", ["node", "--version"]) {
        return v
    }
    return ""
}

// MARK: - Collection

func collectEnvironment() throws -> [String: Any] {
    let xcodeText = try runText("/usr/bin/xcodebuild", ["-version"])
    let swiftText = try runText("/usr/bin/xcrun", ["swift", "--version"])
    let profiler = try runJSON("/usr/sbin/system_profiler", [
        "SPHardwareDataType", "SPDisplaysDataType", "-json"
    ]) as? [String: Any] ?? [:]
    let hardware = (profiler["SPHardwareDataType"] as? [[String: Any]])?.first ?? [:]
    let gpu = (profiler["SPDisplaysDataType"] as? [[String: Any]])?.first ?? [:]
    let displayNodes = (gpu["spdisplays_ndrvs"] as? [[String: Any]]) ?? []
    let displays = displayNodes.map(safeDisplay)
    let builtIn = displays.filter { ($0["connection"] as? String) == "built-in" }
    let external = displays.filter { ($0["connection"] as? String) == "external" }
    let enabledInputSources = try runText("/usr/bin/defaults", [
        "read", "com.apple.HIToolbox", "AppleEnabledInputSources"
    ])
    let appleLanguagesText = try runText("/usr/bin/defaults", ["read", "-g", "AppleLanguages"])
    let appleLocale = try runText("/usr/bin/defaults", ["read", "-g", "AppleLocale"])
    let macOSVersion = try runText("/usr/bin/sw_vers", ["-productVersion"])
    let macOSBuild = try runText("/usr/bin/sw_vers", ["-buildVersion"])
    let macOSSDK = try runText("/usr/bin/xcrun", ["--show-sdk-version"])
    let arch = try runText("/usr/bin/uname", ["-m"])
    let chromeVersion = try runText("/usr/libexec/PlistBuddy", [
        "-c", "Print :CFBundleShortVersionString", chromeInfo
    ])
    let chromeBinarySha = try sha256File(chromeBinary)
    let icuDataSha = try sha256File(chromeIcu)

    let xcodeVersion = try capture(#"^Xcode ([^\n]+)"#, in: xcodeText, label: "xcode version")
    let xcodeBuild = try capture(#"^Build version ([^\n]+)"#, in: xcodeText, label: "xcode build")
    let swiftVersion = try capture(#"Apple Swift version ([^\s]+)"#, in: swiftText, label: "swift version")

    let physicalMemory = hardware["physical_memory"] as? String ?? "0 GB"
    let memoryGiB = Int((try? capture(#"^(\d+) GB$"#, in: physicalMemory, label: "physical memory")) ?? "0") ?? 0
    let mtlFamily = gpu["spdisplays_mtlgpufamilysupport"] as? String
    let metalVersion = mtlFamily == "spdisplays_metal4" ? "Metal 4" : (mtlFamily ?? "")

    let runtimeLocale = appleLocale.replacingOccurrences(of: "_", with: "-")

    let record: [String: Any] = [
        "schemaVersion": 1,
        "collectedAt": ISO8601DateFormatter().string(from: Date()),
        "macOS": [
            "version": macOSVersion,
            "build": macOSBuild
        ],
        "toolchain": [
            "xcode": ["version": xcodeVersion, "build": xcodeBuild],
            "swift": ["version": swiftVersion],
            "node": ["version": nodeVersion()],
            "macOSSDK": macOSSDK
        ],
        "architecture": arch,
        "hardwareClass": [
            "formFactor": hardware["machine_name"] ?? "",
            "modelClass": hardware["machine_model"] ?? "",
            "chipClass": hardware["chip_type"] ?? "",
            "memoryGiB": memoryGiB,
            "gpuCoreCount": Int(gpu["sppci_cores"] as? String ?? "0") ?? 0,
            "metalVersion": metalVersion
        ],
        "displays": [
            "builtIn": builtIn,
            "externalDisplayCount": external.count,
            "external": external
        ],
        "inputSourceIDs": parseInputSourceIDs(enabledInputSources),
        "locale": [
            "appleLocale": appleLocale,
            "appleLanguages": parseAppleLanguages(appleLanguagesText),
            "timeZone": currentTimeZone()
        ],
        "runtimeLocale": runtimeLocale,
        "chrome": [
            "version": chromeVersion,
            "binarySha256": chromeBinarySha,
            "chromiumTagCommit": pinnedProvenance["chromiumTagCommit"] ?? "",
            "v8": pinnedProvenance["v8"] ?? [:],
            "icu": (pinnedProvenance["icu"] as? [String: Any] ?? [:]).merging(
                ["dataSha256": icuDataSha], uniquingKeysWith: { _, new in new }
            ),
            "timeSource": pinnedProvenance["timeSource"] ?? [:]
        ],
        "externalDisplayCountRequired": 0
    ]
    return record
}

// MARK: - Privacy audit (recursive)

let uuidPattern: NSRegularExpression = {
    let pattern = "(?i)\\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\\b"
    return try! NSRegularExpression(pattern: pattern, options: [])
}()

let forbiddenKeyPattern: NSRegularExpression = {
    let pattern = "(?i)serial|uuid|udid|account|user"
    return try! NSRegularExpression(pattern: pattern, options: [])
}()

struct PrivacyFinding {
    let subject: String
    let message: String
}

func privacyViolations(_ value: Any, path: String) -> [PrivacyFinding] {
    if let array = value as? [Any] {
        return array.enumerated().flatMap { index, item in
            privacyViolations(item, path: "\(path)[\(index)]")
        }
    }
    if let dict = value as? [String: Any] {
        return dict.flatMap { key, item in
            let keyRange = NSRange(key.startIndex..., in: key)
            var found: [PrivacyFinding] = []
            if forbiddenKeyPattern.firstMatch(in: key, options: [], range: keyRange) != nil {
                found.append(PrivacyFinding(
                    subject: "\(path).\(key)",
                    message: "forbidden persistent environment identity"
                ))
            }
            found.append(contentsOf: privacyViolations(item, path: "\(path).\(key)"))
            return found
        }
    }
    if let string = value as? String {
        let range = NSRange(string.startIndex..., in: string)
        if uuidPattern.firstMatch(in: string, options: [], range: range) != nil {
            return [PrivacyFinding(subject: path, message: "UUID-shaped persistent identifier")]
        }
    }
    return []
}

func auditEnvironment(_ record: Any) -> [[String: Any]] {
    return privacyViolations(record, path: "$").map {
        ["id": "PLAN_ENVIRONMENT_PRIVACY", "subject": $0.subject, "message": $0.message]
    }
}

// MARK: - QEnvironmentID

func canonicalJSON(_ value: Any) -> String {
    let data = (try? JSONSerialization.data(
        withJSONObject: value,
        options: [.sortedKeys, .fragmentsAllowed]
    )) ?? Data()
    return String(data: data, encoding: .utf8) ?? ""
}

func computeQEnvironmentId(_ record: [String: Any]) -> String {
    // Hash the stable environment fields only. The derived qEnvironmentId and
    // formalPreflight verdict are excluded (they are outputs, not inputs), and
    // the volatile collectedAt timestamp is excluded so the identity is a
    // pure function of the environment observation and is stable across
    // repeated collections of the same environment.
    var stable = record
    stable.removeValue(forKey: "collectedAt")
    return sha256String(canonicalJSON(stable))
}

// MARK: - Main

func emit(_ payload: [String: Any]) {
    let data = (try? JSONSerialization.data(
        withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]
    )) ?? Data()
    if let str = String(data: data, encoding: .utf8) {
        FileHandle.standardOutput.write(str.data(using: .utf8) ?? Data())
        FileHandle.standardOutput.write("\n".data(using: .utf8) ?? Data())
    }
}

func runAuditMode(path: String) -> Int32 {
    guard let data = FileManager.default.contents(atPath: path),
          let json = try? JSONSerialization.jsonObject(with: data, options: []) else {
        emit([
            "status": "error",
            "message": "cannot read or parse \(path)"
        ])
        return 2
    }
    let findings = auditEnvironment(json)
    emit([
        "status": findings.isEmpty ? "ok" : "privacy-violation",
        "findings": findings
    ])
    return findings.isEmpty ? 0 : 2
}

func runCollectMode() -> Int32 {
    let record: [String: Any]
    do {
        record = try collectEnvironment()
    } catch {
        emit([
            "status": "collection-error",
            "message": "\(error)"
        ])
        return 2
    }

    let findings = auditEnvironment(record)
    if !findings.isEmpty {
        emit([
            "status": "privacy-violation",
            "findings": findings
        ])
        return 2
    }

    let qid = computeQEnvironmentId(record)
    let externalCount = record["displays"] as? [String: Any]
    let observedExternal = externalCount?["externalDisplayCount"] as? Int ?? 0
    let required = record["externalDisplayCountRequired"] as? Int ?? 0
    let qualified = observedExternal == required

    let output: [String: Any] = [
        "status": qualified ? "qualified" : "formal-preflight-rejected",
        "qEnvironmentId": qid,
        "record": record,
        "formalPreflight": [
            "required": required,
            "externalDisplayCount": observedExternal,
            "qualified": qualified,
            "privacy": "pass"
        ]
    ]
    emit(output)

    if !qualified {
        FileHandle.standardError.write(
            "FORMAL_PREFLIGHT_FAIL externalDisplays=\(observedExternal) required=\(required)\n"
                .data(using: .utf8) ?? Data()
        )
        return 1
    }
    return 0
}

let arguments = CommandLine.arguments
if arguments.count >= 3 && arguments[1] == "--audit" {
    exit(runAuditMode(path: arguments[2]))
} else if arguments.count == 1 {
    exit(runCollectMode())
} else {
    FileHandle.standardError.write(
        "usage: QEnvironmentCollector.swift [--audit <path>]\n".data(using: .utf8) ?? Data()
    )
    exit(64)
}
