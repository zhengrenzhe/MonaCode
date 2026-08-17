// MonaRegExpExecutor.swift
//
// P02-T004 — Implement the finite ECMAScript RegExp parser and compiler.
//
// `MonaRegExpExecutor` runs a compiled `MonaRegExpProgram` over raw `[UInt16]`
// input via an explicit-stack backtracking virtual machine. It is the Swift
// counterpart of Monaco's RegExp execution (monaco-editor 0.56.0, the
// TypeScript regex engine executor).
//
// Frozen profile (M1-R model, raw UTF-16):
//
//   - Input is raw `[UInt16]`. A lone surrogate in the input is matched
//     code-unit-wise and never repaired.
//   - Frozen `lastIndex` semantics: with the `y` (sticky) flag a match must
//     begin exactly at `lastIndex`; without `y`, `exec` searches forward from
//     `lastIndex`. After a match, `nextLastIndex` is the match end (or, for a
//     zero-length match, one past the start) so iteration progresses.
//   - Zero-length progression: a zero-length match advances `lastIndex` by one
//     code unit so iteration never loops forever (matching Monaco's
//     `_findMatchesInRange` zero-length advancement).
//   - Finite execution: a step counter bounds total instructions executed per
//     match attempt; the backtrack stack has an explicit depth bound. Exceeding
//     either throws a typed `MonaRegExpResourceError` rather than looping or
//     crashing.
//   - Case-insensitive matching uses the explicit Phase-02 `MonaCaseConverter`
//     provider (the `MonaCaseConverterStub` ASCII folder by default; full
//     Unicode case tables arrive in P02-T007).
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// A typed RegExp resource error (the VM exceeded a finite bound).
public enum MonaRegExpResourceError: Error, Equatable, Sendable {

    /// The step counter exceeded `limit` while executing at `position`.
    case stepLimitExceeded(limit: Int, position: Int)

    /// The backtrack stack exceeded `limit` frames while executing at `position`.
    case stackOverflow(limit: Int, position: Int)
}

/// A capture-group span: a half-open `[start, end)` range of UTF-16 code-unit
/// offsets. `start == -1` marks an unmatched group.
public struct MonaRegExpCapture: Equatable, Hashable, Sendable {

    /// The start offset, or `-1` if the group did not participate.
    public let start: Int

    /// The end offset, or `-1` if the group did not participate.
    public let end: Int

    /// Creates a capture span.
    public init(start: Int, end: Int) {
        self.start = start
        self.end = end
    }
}

/// A RegExp match result.
public struct MonaRegExpMatch: Equatable, Hashable, Sendable {

    /// The UTF-16 code-unit offset where the match begins.
    public let startOffset: Int

    /// The UTF-16 code-unit offset one past the end of the match.
    public let endOffset: Int

    /// The capture groups: index 0 is the full match, index k is group k.
    /// An unmatched group has `start == -1` and `end == -1`.
    public let captures: [MonaRegExpCapture]

    /// Named captures: name → capture span.
    public let namedCaptures: [String: MonaRegExpCapture]

    /// Creates a match result.
    public init(
        startOffset: Int,
        endOffset: Int,
        captures: [MonaRegExpCapture],
        namedCaptures: [String: MonaRegExpCapture]
    ) {
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.captures = captures
        self.namedCaptures = namedCaptures
    }
}

/// The result of a single `exec`: an optional match and the updated `lastIndex`.
public struct MonaRegExpExecResult: Equatable, Sendable {

    /// The match, or `nil` if no match was found.
    public let match: MonaRegExpMatch?

    /// The frozen `lastIndex` for the next `exec` call: the match end, or one
    /// past the match start for a zero-length match (progression); `0` on no
    /// match (reset, per ECMAScript for `g`/`y`).
    public let nextLastIndex: Int

    /// Creates an exec result.
    public init(match: MonaRegExpMatch?, nextLastIndex: Int) {
        self.match = match
        self.nextLastIndex = nextLastIndex
    }
}

/// Executes a `MonaRegExpProgram` over raw `[UInt16]` input.
public struct MonaRegExpExecutor {

    /// The compiled program.
    public let program: MonaRegExpProgram

    /// The maximum number of instructions a single match attempt may execute
    /// before throwing `.stepLimitExceeded`.
    public let stepLimit: Int

    /// The maximum backtrack-stack depth before throwing `.stackOverflow`.
    public let stackLimit: Int

    /// The case-conversion provider (non-nil iff case-insensitive matching).
    private let effectiveConverter: MonaCaseConverter?

    /// Creates an executor.
    ///
    /// - Parameters:
    ///   - program: the compiled program.
    ///   - stepLimit: the per-attempt instruction budget (default 1,000,000).
    ///   - stackLimit: the backtrack-stack depth bound (default 50,000).
    ///   - caseConverter: an explicit case converter. When `nil` and the
    ///     program's flags include `.ignoreCase`, the `MonaCaseConverterStub`
    ///     ASCII folder is used.
    public init(
        program: MonaRegExpProgram,
        stepLimit: Int = 1_000_000,
        stackLimit: Int = 50_000,
        caseConverter: MonaCaseConverter? = nil
    ) {
        self.program = program
        self.stepLimit = stepLimit
        self.stackLimit = stackLimit
        if let cc = caseConverter {
            self.effectiveConverter = cc
        } else if program.flags.contains(.ignoreCase) {
            self.effectiveConverter = MonaCaseConverterStub()
        } else {
            self.effectiveConverter = nil
        }
    }

    // MARK: - Public execution

    /// Executes the program against `input` starting at `lastIndex`, returning
    /// the match (if any) and the updated `lastIndex`.
    public func exec(_ input: [UInt16], at lastIndex: Int) throws -> MonaRegExpExecResult {
        let start = max(0, lastIndex)
        let sticky = program.flags.contains(.sticky)
        var match: MonaRegExpMatch? = nil
        if sticky {
            match = try matchAt(input, start: start)
        } else {
            var s = start
            while s <= input.count {
                if let m = try matchAt(input, start: s) {
                    match = m
                    break
                }
                s += 1
            }
        }
        guard let m = match else {
            return MonaRegExpExecResult(match: nil, nextLastIndex: 0)
        }
        let next: Int
        if m.endOffset == m.startOffset {
            next = m.endOffset + 1  // zero-length progression
        } else {
            next = m.endOffset
        }
        return MonaRegExpExecResult(match: m, nextLastIndex: next)
    }

    /// Finds all matches in `input` starting at `from`, up to `limit` matches.
    ///
    /// Handles zero-length progression (advances by one code unit after a
    /// zero-length match) so iteration never loops forever. Without `g` or `y`,
    /// returns at most one match.
    public func findAll(
        in input: [UInt16],
        from position: Int = 0,
        limit: Int = Int.max
    ) throws -> [MonaRegExpMatch] {
        var results: [MonaRegExpMatch] = []
        var idx = max(0, position)
        let continueAfterFirst = program.flags.contains(.global) || program.flags.contains(.sticky)
        while results.count < limit {
            let r = try exec(input, at: idx)
            guard let m = r.match else { break }
            results.append(m)
            idx = r.nextLastIndex
            if idx > input.count { break }
            if !continueAfterFirst { break }
        }
        return results
    }

    // MARK: - VM internals

    /// Runs the main program at a fixed start position, returning the match or
    /// `nil`.
    private func matchAt(_ input: [UInt16], start: Int) throws -> MonaRegExpMatch? {
        guard let caps = try runVM(program: program, input: input, start: start) else {
            return nil
        }
        return buildMatch(from: caps)
    }

    /// The core backtracking VM. Returns the final capture slots array on
    /// success, or `nil` on failure. Throws on resource-limit exhaustion.
    private func runVM(
        program: MonaRegExpProgram,
        input: [UInt16],
        start: Int
    ) throws -> [Int]? {
        var step = 0
        let totalSlots = 2 * (program.captureCount + 1)
        var captures = [Int](repeating: -1, count: totalSlots)
        var stack: [Frame] = []
        stack.reserveCapacity(min(max(stackLimit, 0), 256))
        var pc = 0
        var pos = start
        let instructions = program.instructions
        let n = input.count

        while true {
            step += 1
            if step > stepLimit {
                throw MonaRegExpResourceError.stepLimitExceeded(limit: stepLimit, position: pos)
            }
            let instr = instructions[pc]
            switch instr {
            case .char(let c):
                if pos < n && charEquals(input[pos], c) {
                    pos += 1
                    pc += 1
                } else if !backtrack(&stack, &pc, &pos, &captures) {
                    return nil
                }
            case .anyChar:
                if pos < n {
                    let u = input[pos]
                    if program.flags.contains(.dotAll) || !MonaRegExpCharClass.isLineTerminator(u) {
                        pos += 1
                        pc += 1
                    } else if !backtrack(&stack, &pc, &pos, &captures) {
                        return nil
                    }
                } else if !backtrack(&stack, &pc, &pos, &captures) {
                    return nil
                }
            case .classMatch(let cls):
                if pos < n && cls.matches(input[pos], converter: effectiveConverter) {
                    pos += 1
                    pc += 1
                } else if !backtrack(&stack, &pc, &pos, &captures) {
                    return nil
                }
            case .split(let first, let second):
                if stack.count >= stackLimit {
                    throw MonaRegExpResourceError.stackOverflow(limit: stackLimit, position: pos)
                }
                stack.append(Frame(pc: second, pos: pos, captures: captures))
                pc = first
            case .jump(let target):
                pc = target
            case .save(let slot):
                captures[slot] = pos
                pc += 1
            case .assertStart:
                if isAtStart(pos, input: input) {
                    pc += 1
                } else if !backtrack(&stack, &pc, &pos, &captures) {
                    return nil
                }
            case .assertEnd:
                if isAtEnd(pos, input: input) {
                    pc += 1
                } else if !backtrack(&stack, &pc, &pos, &captures) {
                    return nil
                }
            case .assertWordBoundary(let boundary):
                let wb = isWordBoundary(at: pos, in: input)
                if wb == boundary {
                    pc += 1
                } else if !backtrack(&stack, &pc, &pos, &captures) {
                    return nil
                }
            case .backreference(let k):
                let s = captures[2 * k]
                let e = captures[2 * k + 1]
                if s < 0 || e < 0 {
                    // Unmatched group → matches the empty string.
                    pc += 1
                } else {
                    let len = e - s
                    if pos + len > n {
                        if !backtrack(&stack, &pc, &pos, &captures) { return nil }
                    } else {
                        var ok = true
                        for i in 0..<len {
                            if !charEquals(input[pos + i], input[s + i]) {
                                ok = false
                                break
                            }
                        }
                        if ok {
                            pos += len
                            pc += 1
                        } else if !backtrack(&stack, &pc, &pos, &captures) {
                            return nil
                        }
                    }
                }
            case .lookahead(let sub, let negated):
                let matched = (try runVM(program: sub, input: input, start: pos)) != nil
                if matched != negated {
                    pc += 1
                } else if !backtrack(&stack, &pc, &pos, &captures) {
                    return nil
                }
            case .lookbehind(let sub, let negated):
                let matched = lookbehindMatches(sub, input: input, at: pos)
                if matched != negated {
                    pc += 1
                } else if !backtrack(&stack, &pc, &pos, &captures) {
                    return nil
                }
            case .match:
                return captures
            }
        }
    }

    /// Pops a backtrack frame, restoring `pc`, `pos`, and `captures`. Returns
    /// `false` if the stack is empty (no match).
    private func backtrack(
        _ stack: inout [Frame],
        _ pc: inout Int,
        _ pos: inout Int,
        _ captures: inout [Int]
    ) -> Bool {
        guard let f = stack.popLast() else { return false }
        pc = f.pc
        pos = f.pos
        captures = f.captures
        return true
    }

    /// Returns `true` if the sub-program matches ending exactly at `pos`
    /// (i.e. there is a start `s` such that the sub matches `input[s..<pos]`).
    private func lookbehindMatches(_ sub: MonaRegExpProgram, input: [UInt16], at pos: Int) -> Bool {
        // Try each candidate start from pos down to 0; accept the first whose
        // match ends exactly at pos. The per-call step limit bounds the work.
        var s = pos
        while s >= 0 {
            if let caps = try? runVM(program: sub, input: input, start: s), caps[1] == pos {
                return true
            }
            s -= 1
        }
        return false
    }

    // MARK: - Matching helpers

    /// Returns `true` if `input` and `target` are equal under the case-conversion
    /// provider.
    private func charEquals(_ input: UInt16, _ target: UInt16) -> Bool {
        if let conv = effectiveConverter {
            return conv.foldCase(input) == conv.foldCase(target)
        }
        return input == target
    }

    /// `^` — start of input, or (under `m`) after a line terminator.
    private func isAtStart(_ pos: Int, input: [UInt16]) -> Bool {
        if pos == 0 { return true }
        if program.flags.contains(.multiline) && pos > 0
            && MonaRegExpCharClass.isLineTerminator(input[pos - 1]) {
            return true
        }
        return false
    }

    /// `$` — end of input, or (under `m`) before a line terminator.
    private func isAtEnd(_ pos: Int, input: [UInt16]) -> Bool {
        if pos == input.count { return true }
        if program.flags.contains(.multiline) && pos < input.count
            && MonaRegExpCharClass.isLineTerminator(input[pos]) {
            return true
        }
        return false
    }

    /// `\b` — a transition between a word char (`\w`) and a non-word char.
    private func isWordBoundary(at pos: Int, in input: [UInt16]) -> Bool {
        let before = pos > 0 ? MonaRegExpCharClass.isWord(input[pos - 1]) : false
        let after = pos < input.count ? MonaRegExpCharClass.isWord(input[pos]) : false
        return before != after
    }

    /// Builds a `MonaRegExpMatch` from the capture-slot array.
    private func buildMatch(from slots: [Int]) -> MonaRegExpMatch {
        let start = slots[0]
        let end = slots[1]
        var caps: [MonaRegExpCapture] = []
        caps.reserveCapacity(program.captureCount + 1)
        caps.append(MonaRegExpCapture(start: start, end: end))  // group 0
        if program.captureCount >= 1 {
            for k in 1...program.captureCount {
                let s = slots[2 * k]
                let e = slots[2 * k + 1]
                if s < 0 || e < 0 {
                    caps.append(MonaRegExpCapture(start: -1, end: -1))
                } else {
                    caps.append(MonaRegExpCapture(start: s, end: e))
                }
            }
        }
        var named: [String: MonaRegExpCapture] = [:]
        for (name, k) in program.namedCaptures {
            let s = slots[2 * k]
            let e = slots[2 * k + 1]
            named[name] = (s < 0 || e < 0)
                ? MonaRegExpCapture(start: -1, end: -1)
                : MonaRegExpCapture(start: s, end: e)
        }
        return MonaRegExpMatch(
            startOffset: start,
            endOffset: end,
            captures: caps,
            namedCaptures: named
        )
    }

    /// One saved backtrack continuation.
    private struct Frame {
        let pc: Int
        let pos: Int
        let captures: [Int]
    }
}
