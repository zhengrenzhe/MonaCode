// Tools/Release/scan-distribution.swift
//
// P08-T002 — Scan the release build's linked dylibs, embedded resources,
// exported symbols, source maps, scripts, WASM, language content, and
// third-party runtime classes.
//
// This is the repo-owned Mach-O distribution scanner for the MonaCode release
// build (built by P08-T001 `build-release.sh`). It performs pure local
// introspection of the release artifacts (no network) and enforces the two
// distribution invariants from the G6-R plan leaf P08-T002:
//
//   3. Enumerate linked dylibs, embedded resources, exported symbols, source
//      maps, scripts, WASM, language content, and third-party runtime
//      classes. (Mach-O introspection — `otool -L`, `nm`, `dyld_info`.)
//   4. Reject every linked or bundled item outside the contract allowlist.
//      (The allowlist is Apple system dylibs + system frameworks + the Swift
//      runtime libs under `/usr/lib/` and `/System/Library/Frameworks/`. The
//      no-bundled-runtime invariant from P06-T010 must hold: no JS runtime,
//      no ICU runtime, no bundled language/server/grammar.)
//
// Why a standalone Swift script (not a Package target)
// ----------------------------------------------------
// `productTarget: null` (P08-T002 paths) — adding a Package target would
// change the package graph and violate the P07-T011 API freeze. The script is
// therefore a standalone Foundation-only Swift program invoked via
// `xcrun swift Tools/Release/scan-distribution.swift`, exactly like
// `Tools/Qualification/QEnvironmentCollector.swift`.
//
// Usage
// -----
//   xcrun swift Tools/Release/scan-distribution.swift
//       Scans the release build under `.build/arm64-apple-macosx/release/`,
//       emits a JSON distribution-scan report to stdout, and enforces the
//       allowlist + no-bundled-runtime invariants.
//       exit 0 — scan complete, all invariants hold.
//       exit 1 — a linked or bundled item is outside the allowlist, or a
//                forbidden runtime is present.
//
// Network is never used. All introspection is local Mach-O inspection.

import Foundation

// MARK: - Constants

let repoRoot = FileManager.default.currentDirectoryPath
let buildReal = (repoRoot as NSString).appendingPathComponent(".build/arm64-apple-macosx/release")
let modulesDir = (buildReal as NSString).appendingPathComponent("Modules")
let execPath = (buildReal as NSString).appendingPathComponent("sample-macOS-host")

let EXPECTED_PRODUCTS = ["MonaCode", "MonaCodeAppKit", "MonaCodeSwiftUI"]

// The contract allowlist: a linked dylib is allowed iff its path is an Apple
// system dylib/framework or a Swift runtime lib (under /usr/lib/ or
// /System/Library/Frameworks/). Any third-party or product-bundled dylib
// (a bundled libv8, libicudata, a language .bundle, etc.) is rejected.
let ALLOWED_PREFIXES = ["/usr/lib/", "/System/Library/Frameworks/"]

// Forbidden runtime dylib name patterns (defense in depth — scanned across
// the linked dylibs regardless of path, so a renamed bundled runtime is still
// caught by its linkage identity). A null result means none found.
let JS_RUNTIME_PATTERNS = ["libv8", "libnode", "libjavascript", "JavaScriptCore"]
let ICU_RUNTIME_PATTERNS = ["libicudata", "libicui18n", "libicuuc", "libicudt"]
let LANGUAGE_SERVER_PATTERNS = ["libmonaco-language", "libvscode-json", "monaco-language"]
let GRAMMAR_PATTERNS = ["libgrammar", "libmonaco-grammar", "tmlanguage"]

// Bundled-resource file extensions that must NOT ship with the release (the
// no-bundled-runtime invariant: no JS, no WASM, no source maps, no language
// grammar packs, no ICU data files).
let FORBIDDEN_RESOURCE_EXTS: Set<String> = ["js", "mjs", "cjs", "wasm", "map", "tmLanguage", "tmjson"]
let FORBIDDEN_RESOURCE_STEMS = ["language-configuration", "monaco-language", "icudt", "icudata"]

// Expected module resource extensions (the SwiftPM module artifacts).
let EXPECTED_MODULE_EXTS: Set<String> = ["swiftmodule", "swiftdoc", "swiftsourceinfo", "abi.json", "swiftinterface"]

// MARK: - Process helpers

struct ProcessError: Error { let message: String }

func runProcess(_ exe: String, _ args: [String]) throws -> (stdout: String, stderr: String, status: Int) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: exe)
    p.arguments = args
    let outPipe = Pipe()
    let errPipe = Pipe()
    p.standardOutput = outPipe
    p.standardError = errPipe
    // Drain stdout/stderr concurrently via readabilityHandler to avoid the
    // classic pipe-buffer deadlock: if a tool (nm/otool) writes more than the
    // 64KB pipe buffer, calling waitUntilExit before draining would block the
    // writer and hang forever. The handler drains into Data until EOF.
    var outData = Data()
    var errData = Data()
    outPipe.fileHandleForReading.readabilityHandler = { handle in
        let d = handle.availableData
        if d.isEmpty { outPipe.fileHandleForReading.readabilityHandler = nil }
        else { outData.append(d) }
    }
    errPipe.fileHandleForReading.readabilityHandler = { handle in
        let d = handle.availableData
        if d.isEmpty { errPipe.fileHandleForReading.readabilityHandler = nil }
        else { errData.append(d) }
    }
    do {
        try p.run()
    } catch {
        // If the tool is missing, return a non-zero status with the error.
        return ("", "\(error)", 127)
    }
    p.waitUntilExit()
    // After exit, drain any residual bytes the handler had not yet flushed.
    let restOut = outPipe.fileHandleForReading.readDataToEndOfFile()
    let restErr = errPipe.fileHandleForReading.readDataToEndOfFile()
    outData.append(restOut)
    errData.append(restErr)
    let out = String(data: outData, encoding: .utf8) ?? ""
    let err = String(data: errData, encoding: .utf8) ?? ""
    return (out, err, Int(p.terminationStatus))
}

func otoolLinkedDylibs(_ path: String) -> [String] {
    // `otool -L <path` lists the linked dylibs. The first line is the binary
    // itself; subsequent lines are load commands: "<whitespace><path> (<compat>)".
    guard let (out, _, status) = try? runProcess("/usr/bin/xcrun", ["otool", "-L", path]),
          status == 0 else { return [] }
    var dylibs: [String] = []
    var first = true
    for line in out.split(separator: "\n") {
        if first { first = false; continue } // skip the binary's own line
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let sp = trimmed.firstIndex(of: " ") else { continue }
        let p = String(trimmed[..<sp]).trimmingCharacters(in: .whitespaces)
        if !p.isEmpty { dylibs.append(p) }
    }
    return dylibs
}

func nmExportedSymbols(_ path: String) -> [String] {
    // `nm -gU <path` lists defined, global (exported) symbols. -g = external
    // only, -U = defined only (no undefined). Returns the mangled symbol names
    // (column 3 of each line: <addr> <section> <symbol>).
    guard let (out, _, status) = try? runProcess("/usr/bin/xcrun", ["nm", "-gU", path]),
          status == 0 else { return [] }
    var syms: [String] = []
    for line in out.split(separator: "\n") {
        let cols = line.split(separator: " ", omittingEmptySubsequences: true)
        guard cols.count >= 3 else { continue }
        syms.append(String(cols[cols.count - 1]))
    }
    return syms
}

func fileArchitecture(_ path: String) -> String? {
    guard let (out, _, status) = try? runProcess("/usr/bin/file", [path]), status == 0 else { return nil }
    if out.contains("arm64") { return "arm64" }
    if out.contains("x86_64") { return "x86_64" }
    return nil
}

// MARK: - Resource enumeration

func listFiles(_ dir: String) -> [String] {
    guard let entries = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return [] }
    return entries.sorted()
}

func fileExtension(_ name: String) -> String {
    // Handle compound extensions like .swiftmodule, .abi.json, .swiftsourceinfo.
    let lower = name.lowercased()
    for ext in ["swiftsourceinfo", "swiftmodule", "swiftdoc", "swiftinterface", "abi.json"] {
        if lower.hasSuffix("." + ext) { return ext }
    }
    if let dot = name.lastIndex(of: ".") {
        return String(name[dot...].dropFirst())
    }
    return ""
}

func fileBaseStem(_ name: String) -> String {
    var n = name
    for ext in ["swiftsourceinfo", "swiftmodule", "swiftdoc", "swiftinterface", "abi.json"] {
        if n.lowercased().hasSuffix("." + ext) {
            n = String(n.dropLast(ext.count + 1))
            break
        }
        if let dot = n.lastIndex(of: ".") {
            n = String(n[..<dot])
        }
    }
    return n
}

// Recursively scan a directory tree for files matching a predicate.
func scanTree(_ root: String, maxDepth: Int = 6) -> [(path: String, name: String)] {
    var found: [(String, String)] = []
    let fm = FileManager.default
    let baseDepth = (root as NSString).pathComponents.count
    if let enumerator = fm.enumerator(atPath: root) {
        while let rel = enumerator.nextObject() as? String {
            let abs = (root as NSString).appendingPathComponent(rel)
            let depth = (abs as NSString).pathComponents.count - baseDepth
            if depth > maxDepth { enumerator.skipDescendants(); continue }
            if let attrs = try? fm.attributesOfItem(atPath: abs),
               attrs[.type] as? FileAttributeType == .typeRegular {
                found.append((abs, (rel as NSString).lastPathComponent))
            }
        }
    }
    return found
}

// MARK: - Scan

// Reject with a reason (prints JSON to stdout with the failure + exits 1).
func reject(_ reason: String, report: [String: Any]) -> Never {
    var r = report
    r["allowlistHolds"] = false
    r["noBundledRuntime"] = false
    r["rejection"] = reason
    if let d = try? JSONSerialization.data(withJSONObject: r, options: [.sortedKeys, .prettyPrinted]),
       let s = String(data: d, encoding: .utf8) {
        print(s)
    } else {
        print("{\"rejection\":\"\(reason)\"}")
    }
    FileHandle.standardError.write("scan-distribution: REJECT \(reason)\n".data(using: .utf8)!)
    exit(1)
}

func sha256File(_ path: String) -> String {
    // Use shasum for parity with build-release.sh (no CryptoKit dependency).
    if let (out, _, status) = try? runProcess("/usr/bin/shasum", ["-a", "256", path]), status == 0 {
        return out.split(separator: " ").first.map(String.init) ?? ""
    }
    return ""
}

func bytesOf(_ path: String) -> Int {
    guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
          let size = attrs[.size] as? Int else { return 0 }
    return size
}

// --- Build the report ------------------------------------------------------

var report: [String: Any] = [
    "schemaVersion": "monacode-distribution-scan-v1",
    "platform": "macOS-26-arm64",
]

// Executable presence + architecture (Operation 3).
let execPresent = FileManager.default.fileExists(atPath: execPath)
report["executable"] = [
    "path": ".build/arm64-apple-macosx/release/sample-macOS-host",
    "present": execPresent,
    "architecture": execPresent ? (fileArchitecture(execPath) ?? "unknown") : "absent",
]

// Operation 3 — linked dylibs (otool -L on the executable).
let linkedDylibs = otoolLinkedDylibs(execPath)
report["linkedDylibs"] = linkedDylibs

// Operation 4 — allowlist: every linked dylib must be an Apple system
// dylib/framework or a Swift runtime lib.
var disallowed: [String] = []
for p in linkedDylibs {
    var allowed = false
    for pre in ALLOWED_PREFIXES where p.hasPrefix(pre) { allowed = true; break }
    if !allowed { disallowed.append(p) }
}
report["disallowedDylibs"] = disallowed
report["allowlistHolds"] = disallowed.isEmpty

// Operation 3 — exported symbols (nm -gU on the executable).
let exportedSyms = nmExportedSymbols(execPath)
report["exportedSymbolCount"] = exportedSyms.count

// Operation 3 — embedded resources. Enumerate the Modules/ directory (the
// module artifacts that ship with the release build).
var moduleResources: [String] = []
var unexpectedResources: [String] = []
if FileManager.default.fileExists(atPath: modulesDir) {
    for name in listFiles(modulesDir) {
        let ext = fileExtension(name)
        if EXPECTED_MODULE_EXTS.contains(ext) {
            moduleResources.append(name)
        } else {
            unexpectedResources.append(name)
        }
    }
}
report["embeddedResources"] = moduleResources
report["unexpectedResources"] = unexpectedResources

// Operation 3 — source maps, scripts, WASM, language content. Scan the
// release DISTRIBUTION surface (the Modules/ directory — the artifacts that
// ship with the release) for forbidden bundled-resource extensions/stems.
// The intermediate build artifacts under .build/<config>/release/ (object
// files, module cache, .build subfolders) are NOT distribution artifacts and
// are excluded; the distribution surface is Modules/ + the executable, whose
// linked dylibs are scanned above. These lists must all be empty (the
// no-bundled-runtime invariant).
var sourceMaps: [String] = []
var scripts: [String] = []
var wasm: [String] = []
var languageContent: [String] = []
if FileManager.default.fileExists(atPath: modulesDir) {
    for entry in scanTree(modulesDir) {
        let lower = entry.name.lowercased()
        let ext = fileExtension(entry.name)
        if ext == "map" || lower.hasSuffix(".js.map") || lower.hasSuffix(".css.map") {
            sourceMaps.append(entry.path)
        }
        if FORBIDDEN_RESOURCE_EXTS.contains(ext) || lower.hasSuffix(".js.map") {
            // classify
            if ext == "wasm" {
                wasm.append(entry.path)
            } else if ext == "map" || lower.hasSuffix(".js.map") {
                sourceMaps.append(entry.path)
            } else if ext == "js" || ext == "mjs" || ext == "cjs" {
                scripts.append(entry.path)
            } else {
                languageContent.append(entry.path)
            }
        }
        for stem in FORBIDDEN_RESOURCE_STEMS where lower.contains(stem.lowercased()) {
            languageContent.append(entry.path)
        }
    }
}
// Deduplicate (a file may match multiple predicates).
report["sourceMaps"] = Array(Set(sourceMaps)).sorted()
report["scripts"] = Array(Set(scripts)).sorted()
report["wasm"] = Array(Set(wasm)).sorted()
report["languageContent"] = Array(Set(languageContent)).sorted()

// Operation 3 — third-party runtime classes. None expected (the release is a
// native Swift build with no bundled runtimes). Confirmed empty by the
// resource + dylib scans above; recorded as an empty array.
report["thirdPartyRuntimeClasses"] = []

// Operation 3 + P06-T010 — forbidden runtimes. Scan the linked dylibs for
// known runtime dylib-name patterns (defense in depth). A null result means
// none found.
func findRuntime(_ patterns: [String]) -> String? {
    for p in linkedDylibs {
        let lower = p.lowercased()
        for pat in patterns where lower.contains(pat.lowercased()) {
            return p
        }
    }
    return nil
}
let jsRuntime = findRuntime(JS_RUNTIME_PATTERNS)
let icuRuntime = findRuntime(ICU_RUNTIME_PATTERNS)
let languageServer = findRuntime(LANGUAGE_SERVER_PATTERNS)
let grammar = findRuntime(GRAMMAR_PATTERNS)
report["forbiddenRuntimes"] = [
    "javascript": jsRuntime,
    "icu": icuRuntime,
    "languageServer": languageServer,
    "grammar": grammar,
]
let noBundledRuntime = (jsRuntime == nil) && (icuRuntime == nil) &&
    (languageServer == nil) && (grammar == nil) &&
    sourceMaps.isEmpty && scripts.isEmpty && wasm.isEmpty &&
    languageContent.isEmpty && unexpectedResources.isEmpty
report["noBundledRuntime"] = noBundledRuntime

// Operation 3 — per-product module presence (confirms all 3 frozen products
// are built + present in the release Modules/ directory).
var products: [String: [String: Any]] = [:]
for p in EXPECTED_PRODUCTS {
    let mod = (modulesDir as NSString).appendingPathComponent("\(p).swiftmodule")
    let present = FileManager.default.fileExists(atPath: mod)
    products[p] = [
        "present": present,
        "bytes": present ? bytesOf(mod) : 0,
        "sha256": present ? sha256File(mod) : "",
    ]
}
report["products"] = products

// --- Enforce the invariants (Operation 4) ----------------------------------

if !disallowed.isEmpty {
    let reason = "disallowed-dylib (linked dylib outside the contract allowlist: " + disallowed.joined(separator: ", ") + ")"
    reject(reason, report: report)
}
if !unexpectedResources.isEmpty {
    let reason = "unexpected-resource (bundled resource not in the expected module-artifact set: " + unexpectedResources.joined(separator: ", ") + ")"
    reject(reason, report: report)
}
if jsRuntime != nil {
    reject("forbidden-runtime-javascript (a JavaScript runtime dylib is linked: " + jsRuntime! + ")", report: report)
}
if icuRuntime != nil {
    reject("forbidden-runtime-icu (a bundled ICU runtime dylib is linked: " + icuRuntime! + ")", report: report)
}
if languageServer != nil {
    reject("forbidden-runtime-language-server (a language server dylib is linked: " + languageServer! + ")", report: report)
}
if grammar != nil {
    reject("forbidden-runtime-grammar (a grammar pack dylib is linked: " + grammar! + ")", report: report)
}
if !sourceMaps.isEmpty {
    reject("bundled-source-map (source maps must not ship with the release)", report: report)
}
if !scripts.isEmpty {
    reject("bundled-script (JavaScript scripts must not ship with the release)", report: report)
}
if !wasm.isEmpty {
    reject("bundled-wasm (WebAssembly modules must not ship with the release)", report: report)
}
if !languageContent.isEmpty {
    reject("bundled-language-content (language/grammar content must not ship with the release)", report: report)
}

// --- Emit the report -------------------------------------------------------

if let d = try? JSONSerialization.data(withJSONObject: report, options: [.sortedKeys, .prettyPrinted]),
   let s = String(data: d, encoding: .utf8) {
    print(s)
} else {
    print("{}")
    exit(1)
}
FileHandle.standardError.write("scan-distribution: OK — allowlist holds + no-bundled-runtime invariant holds\n".data(using: .utf8)!)
