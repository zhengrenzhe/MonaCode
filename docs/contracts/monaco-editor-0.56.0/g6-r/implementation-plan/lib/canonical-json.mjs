// G6-R canonical JSON serialization.
// Recursively sorts object keys ascending; preserves array order exactly.
// Used to produce a stable byte representation of any record so that
// evidence/blob hashes are reproducible across processes and platforms.

/**
 * @param {unknown} value
 * @returns {string} Stable JSON with lexicographically-sorted object keys.
 */
export function canonicalJSONStringify(value) {
  return stringify(value);
}

function stringify(value) {
  if (Array.isArray(value)) {
    let out = '[';
    for (let i = 0; i < value.length; i++) {
      if (i > 0) out += ',';
      out += stringify(value[i]);
    }
    out += ']';
    return out;
  }
  if (value !== null && typeof value === 'object') {
    const keys = Object.keys(value).sort();
    let out = '{';
    for (let i = 0; i < keys.length; i++) {
      if (i > 0) out += ',';
      out += JSON.stringify(keys[i]) + ':' + stringify(value[keys[i]]);
    }
    out += '}';
    return out;
  }
  return JSON.stringify(value);
}
