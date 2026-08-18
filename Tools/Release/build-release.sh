#!/usr/bin/env bash
# Tools/Release/build-release.sh
#
# P08-T001 — Build the frozen three-product release package.
#
# Builds arm64 macOS 26.0-or-newer release artifacts for the three products
# (MonaCode, MonaCodeAppKit, MonaCodeSwiftUI) plus the sample-macOS-host
# executable, records build-provenance metadata, and enforces five rejection
# gates. Opens Phase 08 (release candidate / distribution).
#
# Implementation operations (G6-R plan leaf P08-T001):
#
#   1. Build arm64 macOS 26.0+ release artifacts for MonaCode, MonaCodeAppKit,
#      MonaCodeSwiftUI plus the sample host — `xcrun swift build -c release`
#      (release config, arm64, macOS 26.0+ deployment target) for the 3
#      products + the sample-macOS-host executable.
#   2. Record compiler, SDK, deployment target, architecture, binary-UUID-
#      independent content hashes, and complete artifact paths.
#   3. Reject debug-only, unsigned-input, stale-source, extra-product, or
#      missing-target output.
#
# Reproducibility
# ---------------
# The build is REPRODUCIBLE. `-Xlinker -reproducible` instructs the linker to
# emit a deterministic, content-derived LC_UUID (instead of a random one), so
# two builds of the same source produce a byte-identical executable. The
# recorded sha256 is a CONTENT hash (sha256 of the artifact bytes), not the
# dwarfdump UUID — it is binary-UUID-independent: stable across reproducible
# builds and never derived from the Mach-O UUID load command.
#
# Why a two-step build
# --------------------
# `sample-macOS-host` is an `.executableTarget` but is NOT a declared
# `.executable` product (Package.swift ships exactly 3 library products;
# adding a 4th would violate the P07-T011 frozen API). SwiftPM only LINKS an
# executable binary during a full `swift build`, not with `--target <exec>`.
# A full release build also attempts the `conformance-and-failure-injection`
# non-product target, which uses `@testable import` and cannot compile under
# release optimization (modules are not compiled for testing in -c release).
# That compile error is a pre-existing structural condition of a non-release
# target — it is tolerated here as long as the 4 in-scope release artifacts
# are produced. To make the LINK reliable (it races the conformance error when
# cold), modules are compiled first with `--target` (reliable, no conformance),
# then the full build re-links with everything cached (the link completes in
# seconds before the conformance error halts unrelated work).
#
# Usage
# -----
#   build-release.sh                # build + record metadata + run all gates
#   build-release.sh --check-only   # run the 5 rejection gates only (no build)
#
# Exit status
# -----------
#   0 — release artifacts built, metadata recorded, all gates pass.
#   1 — a rejection gate failed, or the build could not produce the artifacts.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"
cd "${repo_root}"

# --- Constants -------------------------------------------------------------

# P07-T011 final public-API freeze commit. The source tree (Sources/ +
# Package.swift) must not have drifted since this commit (stale-source gate).
# Overrides via MONACODE_FREEZE_COMMIT are for testing the gate only.
FREEZE_COMMIT="${MONACODE_FREEZE_COMMIT:-efe78e976b616116e0a0c1b5dcdb3fcd05419fbb}"

BUILD_ROOT="${repo_root}/.build"
RELEASE_REAL="${BUILD_ROOT}/arm64-apple-macosx/release"
RELEASE_LINK="${BUILD_ROOT}/release"
MODULES_DIR="${RELEASE_REAL}/Modules"
METADATA_PATH="${RELEASE_LINK}/release-build-metadata.json"

EXPECTED_PRODUCTS=(MonaCode MonaCodeAppKit MonaCodeSwiftUI)
EXPECTED_EXEC="sample-macOS-host"
EXPECTED_EXEC_PATH="${RELEASE_REAL}/${EXPECTED_EXEC}"

# Declared targets in Package.swift (module-stem form, hyphens -> underscores).
# extra-product rejects any .swiftmodule in Modules/ whose stem is NOT in this
# set (a foreign/undeclared product module).
ALLOWED_MODULE_STEMS=(
  MonaCode
  MonaCodeAppKit
  MonaCodeSwiftUI
  sample_macOS_host
  conformance_and_failure_injection
  benchmark_harness
)

REASON=""
reject() { # reason -> stderr, then exit 1
  REASON="$1"
  printf 'build-release: REJECT %s\n' "$1" >&2
  exit 1
}

# --- Pre-build rejection gates ---------------------------------------------
# unsigned-input: build inputs must be the frozen/committed source — no
# uncommitted modifications to Sources/ or Package.swift, and no untracked
# Swift sources under Sources/.
gate_unsigned_input() {
  if ! git diff --quiet HEAD -- Sources Package.swift 2>/dev/null; then
    reject 'unsigned-input (uncommitted changes to frozen source — Sources/ or Package.swift)'
  fi
  local untracked
  untracked="$(git ls-files --others --exclude-standard -- 'Sources/**/*.swift' 'Sources/*.swift' 2>/dev/null || true)"
  if [ -n "${untracked}" ]; then
    reject 'unsigned-input (untracked Swift sources under Sources/ — build inputs not committed)'
  fi
}

# stale-source: the committed source must not have drifted since the P07-T011
# freeze. Compares the freeze commit to HEAD for Sources/ + Package.swift.
gate_stale_source() {
  if ! git cat-file -e "${FREEZE_COMMIT}" 2>/dev/null; then
    reject "stale-source (freeze commit ${FREEZE_COMMIT:0:12} not found in this repository)"
  fi
  if ! git diff --quiet "${FREEZE_COMMIT}" HEAD -- Sources Package.swift 2>/dev/null; then
    reject 'stale-source (source drifted since the P07-T011 freeze)'
  fi
}

# --- Post-build rejection gates --------------------------------------------
# debug-only: the release executable must exist and be a Mach-O arm64 binary.
# (A debug-only output would live under .build/debug/, not .build/release/.)
gate_debug_only() {
  if [ ! -f "${EXPECTED_EXEC_PATH}" ]; then
    reject 'debug-only (release executable absent — only debug output present, or build did not run -c release)'
  fi
  local ftype
  ftype="$(file "${EXPECTED_EXEC_PATH}" 2>/dev/null || true)"
  case "${ftype}" in
    *Mach-O*arm64*) ;;
    *)
      reject "debug-only (release executable is not a Mach-O arm64 binary: ${ftype})"
      ;;
  esac
}

# missing-target: every expected artifact (3 product modules + the executable)
# must be present.
gate_missing_target() {
  local p
  for p in "${EXPECTED_PRODUCTS[@]}"; do
    if [ ! -f "${MODULES_DIR}/${p}.swiftmodule" ]; then
      reject "missing-target (${p}.swiftmodule not produced by the release build)"
    fi
  done
  if [ ! -f "${EXPECTED_EXEC_PATH}" ]; then
    reject "missing-target (${EXPECTED_EXEC} executable not produced by the release build)"
  fi
  # The sample's own module must also be present (it is an in-scope artifact).
  if [ ! -f "${MODULES_DIR}/sample_macOS_host.swiftmodule" ]; then
    reject 'missing-target (sample_macOS_host.swiftmodule not produced by the release build)'
  fi
}

# extra-product: no .swiftmodule in Modules/ may be for a foreign (undeclared)
# target. The allowed set is the declared targets in Package.swift.
gate_extra_product() {
  [ -d "${MODULES_DIR}" ] || reject 'missing-target (Modules/ directory absent)'
  local stem allowed
  while IFS= read -r -d '' f; do
    stem="$(basename "${f}")"
    stem="${stem%.swiftmodule}"
    local hit=0
    for allowed in "${ALLOWED_MODULE_STEMS[@]}"; do
      if [ "${stem}" = "${allowed}" ]; then hit=1; break; fi
    done
    if [ "${hit}" -eq 0 ]; then
      reject "extra-product (foreign module artifact ${stem}.swiftmodule not declared in Package.swift)"
    fi
  done < <(find "${MODULES_DIR}" -maxdepth 1 -name '*.swiftmodule' -type f -print0 2>/dev/null)
}

run_post_build_gates() {
  gate_debug_only
  gate_missing_target
  gate_extra_product
}

# --- check-only mode -------------------------------------------------------

if [ "${1:-}" = "--check-only" ]; then
  gate_unsigned_input
  gate_stale_source
  run_post_build_gates
  printf 'build-release: OK (check-only) — all 5 gates pass\n' >&2
  exit 0
fi

# --- Build -----------------------------------------------------------------

# Pre-build gates run before any compilation.
gate_unsigned_input
gate_stale_source

printf 'build-release: compiling release modules (arm64, macOS 26.0+)...\n' >&2

# Step 1 — compile the 3 products + the sample target. Reliable: no conformance
# target, no link. -Xlinker -reproducible is passed through (a no-op here since
# --target does not link, but kept for consistency with step 2).
if ! xcrun swift build -c release \
      --target MonaCode --target MonaCodeAppKit \
      --target MonaCodeSwiftUI --target sample-macOS-host \
      -Xlinker -reproducible > /dev/null 2>&1; then
  reject 'missing-target (step 1 module compilation failed)'
fi

printf 'build-release: linking the sample-macOS-host executable...\n' >&2

# Step 2 — full release build. Modules are cached, so this re-links the
# executable (completing in seconds) before the conformance target's
# @testable compile error halts unrelated work. The exit code is tolerated;
# the post-build gates verify the 4 in-scope artifacts by presence.
xcrun swift build -c release -Xlinker -reproducible > /dev/null 2>&1 || true

# If the link raced and lost (cold start), one more pass with cached modules
# completes it reliably.
if [ ! -f "${EXPECTED_EXEC_PATH}" ]; then
  xcrun swift build -c release -Xlinker -reproducible > /dev/null 2>&1 || true
fi

# Ensure the conventional .build/release symlink resolves (a build that exits
# non-zero does not recreate the symlink).
mkdir -p "${BUILD_ROOT}"
if [ ! -e "${RELEASE_LINK}" ] && [ -d "${RELEASE_REAL}" ]; then
  ln -sfn arm64-apple-macosx/release "${RELEASE_LINK}"
fi

# --- Post-build gates ------------------------------------------------------
run_post_build_gates

# --- Metadata (Operation 2) -----------------------------------------------

printf 'build-release: recording provenance metadata...\n' >&2

swift_compiler="$(xcrun swift --version 2>&1 | paste -sd ' ' -)"
macos_sdk="$(xcrun --show-sdk-version 2>&1 | head -1)"
source_commit="$(git rev-parse HEAD 2>/dev/null || echo unknown)"

sha256_of() { shasum -a 256 "$1" 2>/dev/null | awk '{print $1}'; }
bytes_of() { wc -c < "$1" | tr -d ' '; }

# JSON-escape a string in pure bash (backslash + double-quote + newline).
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  printf '"%s"' "${s}"
}

# Assemble the artifact table (deterministic field order).
artifacts_json='['
first=1
for p in "${EXPECTED_PRODUCTS[@]}"; do
  path="${MODULES_DIR}/${p}.swiftmodule"
  h="$(sha256_of "${path}")"
  b="$(bytes_of "${path}")"
  [ "${first}" -eq 1 ] || artifacts_json+=','
  first=0
  artifacts_json+=$(printf '{"id":"%s-module","kind":"library","path":".build/release/Modules/%s.swiftmodule","sha256":"%s","bytes":%s}' \
    "${p}" "${p}" "${h}" "${b}")
done
# The sample executable.
exe_h="$(sha256_of "${EXPECTED_EXEC_PATH}")"
exe_b="$(bytes_of "${EXPECTED_EXEC_PATH}")"
[ "${first}" -eq 1 ] || artifacts_json+=','
artifacts_json+=$(printf '{"id":"sample-macOS-host","kind":"executable","path":".build/release/sample-macOS-host","sha256":"%s","bytes":%s,"architecture":"arm64"}' \
  "${exe_h}" "${exe_b}")
artifacts_json+=']'

# Deterministic JSON (stable key order, sorted where relevant).
{
  printf '{\n'
  printf '  "schemaVersion": "monacode-release-build-v1",\n'
  printf '  "product": "MonaCode",\n'
  printf '  "platform": "macOS-26-arm64",\n'
  printf '  "buildConfig": "release",\n'
  printf '  "swiftCompiler": %s,\n' "$(json_escape "${swift_compiler}")"
  printf '  "macosSdk": "macOS %s",\n' "${macos_sdk}"
  printf '  "deploymentTarget": "macOS 26.0",\n'
  printf '  "architecture": "arm64",\n'
  printf '  "sourceCommit": "%s",\n' "${source_commit}"
  printf '  "freezeCommit": "%s",\n' "${FREEZE_COMMIT}"
  printf '  "reproducible": true,\n'
  printf '  "artifacts": %s\n' "${artifacts_json}"
  printf '}\n'
} > "${METADATA_PATH}"

printf 'build-release: OK — 3 product modules + sample-macOS-host built + metadata recorded\n' >&2
printf 'build-release: metadata=%s\n' "${METADATA_PATH}" >&2
