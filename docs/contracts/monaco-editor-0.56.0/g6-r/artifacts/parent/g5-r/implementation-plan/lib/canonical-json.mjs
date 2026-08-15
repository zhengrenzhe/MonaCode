import { createHash } from 'node:crypto';

function encode(value, seen) {
  if (value === null || typeof value === 'boolean' || typeof value === 'string') {
    return JSON.stringify(value);
  }
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) throw new TypeError('non-finite number');
    return JSON.stringify(value);
  }
  if (typeof value !== 'object') {
    throw new TypeError(`unsupported canonical JSON value: ${typeof value}`);
  }
  if (seen.has(value)) throw new TypeError('cyclic canonical JSON value');
  seen.add(value);
  try {
    if (Array.isArray(value)) {
      return `[${value.map((item) => encode(item, seen)).join(',')}]`;
    }
    const prototype = Object.getPrototypeOf(value);
    if (prototype !== Object.prototype && prototype !== null) {
      throw new TypeError('canonical JSON object must be plain');
    }
    const keys = Object.keys(value).sort();
    return `{${keys.map((key) => `${JSON.stringify(key)}:${encode(value[key], seen)}`).join(',')}}`;
  } finally {
    seen.delete(value);
  }
}

export function canonicalJSONString(value) {
  return encode(value, new Set());
}

export function recordSha256(value) {
  return createHash('sha256').update(canonicalJSONString(value)).digest('hex');
}
