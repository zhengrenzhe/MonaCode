// G6-R canonical JSON serialization.
// Recursively sorts object keys ascending; preserves array order exactly.
// Used to produce a stable byte representation of any record so that
// evidence/blob hashes are reproducible across processes and platforms.
//
// Task 26 adds recordSha256 (canonical JSON of a value -> sha256 hex) for the
// ported Markdown marker check, which compares a task's recordSha256 marker
// against the canonical-JSON hash of the task record.

import { createHash } from 'node:crypto';

/**
 * @param {unknown} value
 * @returns {string} Stable JSON with lexicographically-sorted object keys.
 */
export function canonicalJSONStringify(value) {
  return stringify(value, new Set());
}

function stringify(value, seen) {
  if (value === null || typeof value !== 'object') {
    return JSON.stringify(value);
  }
  if (seen.has(value)) {
    // Non-finite/cyclic guard: surface as a typed error rather than emit
    // corrupt bytes. The audit never feeds cyclic structures here; this is a
    // fail-closed guard for downstream recordSha256 callers.
    throw new TypeError('cyclic canonical JSON value');
  }
  seen.add(value);
  try {
    if (Array.isArray(value)) {
      let out = '[';
      for (let i = 0; i < value.length; i++) {
        if (i > 0) out += ',';
        out += stringify(value[i], seen);
      }
      return out + ']';
    }
    const keys = Object.keys(value).sort();
    let out = '{';
    for (let i = 0; i < keys.length; i++) {
      if (i > 0) out += ',';
      out += JSON.stringify(keys[i]) + ':' + stringify(value[keys[i]], seen);
    }
    return out + '}';
  } finally {
    seen.delete(value);
  }
}

/**
 * SHA-256 hex digest of the canonical JSON encoding of `value`.
 * @param {unknown} value
 * @returns {string}
 */
export function recordSha256(value) {
  return createHash('sha256').update(canonicalJSONStringify(value), 'utf8').digest('hex');
}
