#!/usr/bin/env bash
# Tools/PlanChecks/forbidden-core-imports.sh
#
# P00-T002 — Enforce the Foundation-only MonaCode boundary.
#
# MonaCode is a Foundation-only library target. The only permitted module
# import inside `Sources/MonaCode/**/*.swift` is `Foundation`. Any other
# `import <Module>` is forbidden because MonaCode must not depend on platform
# UI (AppKit/UIKit/SwiftUI), graphics (CoreGraphics), rendering (Metal), the
# web runtime (WebKit), or the JavaScript runtime (JavaScriptCore). This gate
# also rejects `@testable import` of any non-Foundation module — testable
# imports do not belong in production library sources.
#
# Usage:
#   forbidden-core-imports.sh [SCAN_DIR]
#
#   SCAN_DIR defaults to <repo-root>/Sources/MonaCode.
#
# Output:
#   One line per violation to stderr, of the form
#     <file>:<line>: import <Module>
#   (or `@testable import <Module>`).
#
# Exit status:
#   0 — no forbidden imports found.
#   1 — at least one forbidden import found, or the scan directory is missing.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"

scan_dir="${1:-${repo_root}/Sources/MonaCode}"

if [ ! -d "${scan_dir}" ]; then
  printf 'forbidden-core-imports: scan directory not found: %s\n' "${scan_dir}" >&2
  exit 1
fi

status=0

# Walk every Swift source beneath SCAN_DIR. For each import statement, extract
# the module token and reject it unless it is exactly `Foundation`.
#
# A line is an import statement when, after stripping leading whitespace and an
# optional `@testable ` prefix, it begins with `import <Module>`. Lines such
# as `// import AppKit` or `let s = "import Metal"` start with something other
# than `import` after the whitespace strip, so they are naturally ignored —
# this is a structural check on real import declarations, not comments or
# string literals.
while IFS= read -r -d '' file; do
  while IFS=$'\t' read -r lineno module; do
    [ -z "${lineno:-}" ] && continue
    if [ "${module}" != "Foundation" ]; then
      printf '%s:%s: import %s\n' "${file}" "${lineno}" "${module}" >&2
      status=1
    fi
  done < <(awk '
    {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      sub(/^@testable[[:space:]]+/, "", line)
      if (match(line, /^import[[:space:]]+[A-Za-z_][A-Za-z0-9_]*/)) {
        tok = substr(line, RSTART, RLENGTH)
        sub(/^import[[:space:]]+/, "", tok)
        printf "%d\t%s\n", NR, tok
      }
    }
  ' "${file}")
done < <(find "${scan_dir}" -type f -name '*.swift' -print0)

exit "${status}"
