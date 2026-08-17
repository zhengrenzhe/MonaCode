// MonaRegExpProgram.swift
//
// P02-T004 — Implement the finite ECMAScript RegExp parser and compiler.
//
// `MonaRegExpProgram` is the compiled bytecode representation of a RegExp.
// `MonaRegExpCompiler` lowers the AST into a flat, deterministic array of
// `MonaRegExpInstruction`s that `MonaRegExpExecutor` runs over raw `[UInt16]`
// input via a backtracking virtual machine.
//
// The instruction set is the standard backtracking-NFA set (after Russ Cox,
// "Regular Expression Matching: the Virtual Machine Approach"):
//
//   - `.char(c)`        match a single code unit `c`.
//   - `.anyChar`        match any code unit (subject to dotAll/line-terminators).
//   - `.classMatch(cls)` match a character class.
//   - `.split(a, b)`    push the second-branch continuation `(b, pos)` onto the
//                       backtrack stack and continue at `a` (greedy: `a` is the
//                       body; lazy: `a` is the skip).
//   - `.jump(t)`        unconditional jump to `t`.
//   - `.save(slot)`     record the current input position in capture slot `slot`.
//   - `.assertStart`    `^` assertion.
//   - `.assertEnd`      `$` assertion.
//   - `.assertWordBoundary(b)` `\b` (b=true) / `\B` (b=false).
//   - `.backreference(n)` match the text captured by group `n`.
//   - `.lookahead(prog, negated)` run a sub-program at the current position
//                       without consuming input; succeed iff it matches (or,
//                       if negated, fails).
//   - `.lookbehind(prog, negated)` run a sub-program ending at the current
//                       position without consuming input.
//   - `.match`          accept — the current thread is a successful match.
//
// Slot numbering: group 0 (the full match) uses slots 0 (start) and 1 (end);
// capture group k (1-based) uses slots 2k (start) and 2k+1 (end). A program with
// `captureCount` capturing groups has `2 * (captureCount + 1)` slots.
//
// Determinism: compilation is a pure function of (AST, flags, captureCount,
// namedCaptures) — the same inputs always produce the same instruction array.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// One instruction in a compiled `MonaRegExpProgram`.
public indirect enum MonaRegExpInstruction: Equatable, Hashable, Sendable {

    /// Match a single literal code unit.
    case char(UInt16)

    /// Match any code unit (subject to `dotAll` and line-terminator rules).
    case anyChar

    /// Match a character class.
    case classMatch(MonaRegExpCharClass)

    /// Split: push continuation `(second, pos)` and continue at `first`.
    case split(first: Int, second: Int)

    /// Unconditional jump to `target`.
    case jump(Int)

    /// Save the current input position in capture `slot`.
    case save(Int)

    /// `^` assertion (start of input or line under `m`).
    case assertStart

    /// `$` assertion (end of input or line under `m`).
    case assertEnd

    /// `\b` (boundary=true) / `\B` (boundary=false).
    case assertWordBoundary(Bool)

    /// Match the text captured by group `n` (1-based).
    case backreference(Int)

    /// Run `program` at the current position without consuming input.
    /// `negated=true` for `(?!X)`.
    case lookahead(MonaRegExpProgram, Bool)

    /// Run `program` ending at the current position without consuming input.
    /// `negated=true` for `(?<!X)`.
    case lookbehind(MonaRegExpProgram, Bool)

    /// Accept — the current thread is a successful match.
    case match
}

/// A compiled RegExp program: a flat instruction array plus metadata.
public struct MonaRegExpProgram: Equatable, Hashable, Sendable {

    /// The bytecode instructions.
    public let instructions: [MonaRegExpInstruction]

    /// The number of capturing groups (excluding group 0).
    public let captureCount: Int

    /// Named captures: name → 1-based capture index.
    public let namedCaptures: [String: Int]

    /// The flags in effect.
    public let flags: MonaRegExpFlags

    /// Creates a program.
    public init(
        instructions: [MonaRegExpInstruction],
        captureCount: Int,
        namedCaptures: [String: Int],
        flags: MonaRegExpFlags
    ) {
        self.instructions = instructions
        self.captureCount = captureCount
        self.namedCaptures = namedCaptures
        self.flags = flags
    }
}
