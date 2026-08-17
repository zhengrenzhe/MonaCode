// MonaRegExpCompiler.swift
//
// P02-T004 — Implement the finite ECMAScript RegExp parser and compiler.
//
// `MonaRegExpCompiler` lowers a `MonaRegExpNode` AST into a deterministic
// `MonaRegExpProgram` — a flat array of `MonaRegExpInstruction`s run by
// `MonaRegExpExecutor` via a backtracking virtual machine.
//
// Compilation is a pure function of (AST, flags, captureCount,
// namedCaptures): the same inputs always produce the same instruction array
// (deterministic bytecode). The lowering follows the standard
// backtracking-VM recipes (Russ Cox, "Regular Expression Matching: the
// Virtual Machine Approach"):
//
//   - `x*`  → `L1: SPLIT body, end; body; JUMP L1; end:`
//   - `x+`  → `L1: body; SPLIT L1, end; end:`
//   - `x?`  → `SPLIT body, end; body; end:`
//   - `x{n,m}` → `m` required copies, then `(n-m)` optional copies.
//   - Lazy variants swap the SPLIT branch order (prefer skip).
//   - `a|b` → `SPLIT L_a, L_b; L_a: a; JUMP end; L_b: b; end:`.
//   - Capturing group `k` → `SAVE 2k; body; SAVE 2k+1`.
//   - Group 0 (full match) → `SAVE 0; ...; SAVE 1; MATCH`.
//   - Lookahead/lookbehind compile their body into a sub-program.
//
// Slot numbering: group 0 uses slots 0/1; group k uses 2k/2k+1.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

/// Compiles a RegExp AST into a `MonaRegExpProgram`.
public struct MonaRegExpCompiler {

    /// The compiled program.
    public let program: MonaRegExpProgram

    /// Compiles an AST.
    public init(
        _ ast: MonaRegExpNode,
        flags: MonaRegExpFlags,
        captureCount: Int,
        namedCaptures: [String: Int]
    ) {
        var builder = _MonaRegExpCodeBuilder(
            captureCount: captureCount,
            namedCaptures: namedCaptures,
            flags: flags
        )
        // Group 0 (full match): SAVE 0 at start, SAVE 1 at end, then MATCH.
        builder.emit(.save(0))
        builder.compileNode(ast)
        builder.emit(.save(1))
        builder.emit(.match)
        self.program = builder.finalize()
    }
}

/// Convenience: parse + compile a pattern string with flags into a program.
public func monaRegExpCompile(_ pattern: String, flags: String = "") throws -> MonaRegExpProgram {
    let parser = try MonaRegExpParser(pattern: pattern, flags: flags)
    let compiler = MonaRegExpCompiler(
        parser.ast,
        flags: parser.flags,
        captureCount: parser.captureCount,
        namedCaptures: parser.namedCaptures
    )
    return compiler.program
}

/// The internal mutable code builder.
fileprivate struct _MonaRegExpCodeBuilder {

    var code: [MonaRegExpInstruction] = []
    let captureCount: Int
    let namedCaptures: [String: Int]
    let flags: MonaRegExpFlags

    mutating func emit(_ instr: MonaRegExpInstruction) {
        code.append(instr)
    }

    func finalize() -> MonaRegExpProgram {
        return MonaRegExpProgram(
            instructions: code,
            captureCount: captureCount,
            namedCaptures: namedCaptures,
            flags: flags
        )
    }

    // MARK: - Node compilation

    mutating func compileNode(_ node: MonaRegExpNode) {
        switch node {
        case .empty:
            break
        case .character(let c):
            emit(.char(c))
        case .anyChar:
            emit(.anyChar)
        case .charClass(let cls):
            emit(.classMatch(cls))
        case .concatenation(let terms):
            for t in terms {
                compileNode(t)
            }
        case .alternation(let alts):
            compileAlternation(alts)
        case .quantifier(let q):
            compileQuantifier(q)
        case .group(let g):
            compileGroup(g)
        case .assertion(let a):
            compileAssertion(a)
        case .backreference(let n):
            emit(.backreference(n))
        case .namedBackreference(let name):
            emit(.backreference(namedCaptures[name] ?? 0))
        }
    }

    // MARK: - Alternation

    mutating func compileAlternation(_ alts: [MonaRegExpNode]) {
        if alts.isEmpty {
            return  // empty alternation matches the empty string
        }
        if alts.count == 1 {
            compileNode(alts[0])
            return
        }
        var endJumps: [Int] = []
        for i in 0..<alts.count {
            if i < alts.count - 1 {
                // SPLIT: first = this branch, second = next split/branch.
                let splitIdx = code.count
                emit(.split(first: 0, second: 0))  // placeholder
                let firstTarget = code.count
                compileNode(alts[i])
                let jmpIdx = code.count
                emit(.jump(0))  // placeholder jump to end
                endJumps.append(jmpIdx)
                let secondTarget = code.count  // start of next split/branch
                code[splitIdx] = .split(first: firstTarget, second: secondTarget)
            } else {
                // Last branch — no split.
                compileNode(alts[i])
            }
        }
        let endTarget = code.count
        for j in endJumps {
            code[j] = .jump(endTarget)
        }
    }

    // MARK: - Quantifier

    mutating func compileQuantifier(_ q: MonaRegExpQuantifier) {
        let body = q.atom
        let mn = q.min
        let mx = q.max  // nil = infinity

        // Required copies.
        for _ in 0..<mn {
            compileNode(body)
        }

        if mx == nil {
            // Star after the required copies.
            compileStar(body, greedy: q.greedy)
        } else if let mx = mx {
            // Optional copies: (mx - mn) of them.
            let optionals = mx - mn
            if optionals == 0 {
                return
            }
            var endJumps: [Int] = []
            for _ in 0..<optionals {
                let splitIdx = code.count
                emit(.split(first: 0, second: 0))  // placeholder
                let bodyTarget = code.count
                compileNode(body)
                let jmpIdx = code.count
                emit(.jump(0))  // to end
                endJumps.append(jmpIdx)
                let skipTarget = code.count  // after the jump
                if q.greedy {
                    code[splitIdx] = .split(first: bodyTarget, second: skipTarget)
                } else {
                    code[splitIdx] = .split(first: skipTarget, second: bodyTarget)
                }
            }
            let endTarget = code.count
            for j in endJumps {
                code[j] = .jump(endTarget)
            }
        }
    }

    /// Compiles a greedy/lazy star of `body`:
    /// `L1: SPLIT body, end; body; JUMP L1; end:`
    mutating func compileStar(_ body: MonaRegExpNode, greedy: Bool) {
        let l1 = code.count
        let splitIdx = code.count
        emit(.split(first: 0, second: 0))  // placeholder
        let bodyTarget = code.count
        compileNode(body)
        emit(.jump(l1))  // loop back to the split
        let endTarget = code.count  // after the jump
        if greedy {
            code[splitIdx] = .split(first: bodyTarget, second: endTarget)
        } else {
            code[splitIdx] = .split(first: endTarget, second: bodyTarget)
        }
    }

    // MARK: - Group

    mutating func compileGroup(_ g: MonaRegExpGroup) {
        switch g.kind {
        case .nonCapturing:
            compileNode(g.node)
        case .capturing, .named:
            let k = g.index
            emit(.save(2 * k))       // group k start (slot 2k)
            compileNode(g.node)
            emit(.save(2 * k + 1))   // group k end (slot 2k+1)
        }
    }

    // MARK: - Assertion

    mutating func compileAssertion(_ a: MonaRegExpAssertion) {
        switch a {
        case .start:
            emit(.assertStart)
        case .end:
            emit(.assertEnd)
        case .wordBoundary:
            emit(.assertWordBoundary(true))
        case .notWordBoundary:
            emit(.assertWordBoundary(false))
        case .lookahead(let node, let negated):
            let sub = compileSubprogram(node)
            emit(.lookahead(sub, negated))
        case .lookbehind(let node, let negated):
            let sub = compileSubprogram(node)
            emit(.lookbehind(sub, negated))
        }
    }

    /// Compiles `node` as a self-contained sub-program (SAVE 0; body; SAVE 1;
    /// MATCH) for use by a lookaround. Lookaround captures are local to the
    /// sub-program (captureCount 0).
    func compileSubprogram(_ node: MonaRegExpNode) -> MonaRegExpProgram {
        var sub = _MonaRegExpCodeBuilder(
            captureCount: 0,
            namedCaptures: [:],
            flags: flags
        )
        sub.emit(.save(0))
        sub.compileNode(node)
        sub.emit(.save(1))
        sub.emit(.match)
        return sub.finalize()
    }
}
