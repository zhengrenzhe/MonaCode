// MonaContextKey.swift
//
// P05-T002 — Implement command, action, contribution, and pure-text registries.
//
// `MonaContextKey` is the typed context-key type for when-clause / precondition
// evaluation. It reuses the `MonaKeybindingContext` + `MonaContextValue` types
// established by P04-T003's keybinding resolver (Sources/MonaCode/Input/
// MonaKeybindingResolver.swift) — it does NOT invent a parallel context-key
// mechanism. Precondition expressions use the same Monaco when-clause grammar
// (`&&`, `||`, `!`, `==`, `!=`, `=~`, bare-key truthy, parentheses) and evaluate
// against the same `MonaKeybindingContext` the resolver uses for keybinding
// when-clauses, so a command/action precondition and a keybinding when-clause
// observe identical context state.
//
// `MonaPreconditionEvaluator` evaluates a `MonaPrecondition` against a
// `MonaKeybindingContext`. `nil` / empty expressions match unconditionally. A
// parse failure fails safe (no match) so a malformed precondition never silently
// enables a command or action.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

// MARK: - MonaContextKey

/// A typed context key — the Swift counterpart of Monaco's `RawContextKey<T>`.
///
/// A context key is a named slot in the keybinding context whose value (a
/// boolean or string) participates in when-clause / precondition evaluation.
/// `MonaContextKey` is a thin, type-safe name wrapper; the value lookup still
/// goes through `MonaKeybindingContext.value(forKey:)`, the same context the
/// P04-T003 keybinding resolver reads, so there is one context-key mechanism
/// across the whole editor.
public struct MonaContextKey: Hashable, Sendable {

    /// The context-key name (e.g. `"editorTextFocus"`, `"editorReadonly"`).
    public let name: String

    /// Creates a context key with the given name.
    public init(_ name: String) {
        self.name = name
    }

    /// Returns the value of this key in `context`, or `nil` if absent.
    public func value(in context: MonaKeybindingContext) -> MonaContextValue? {
        context.value(forKey: name)
    }

    /// Returns `true` when this key is `true` in `context`.
    public func isSet(in context: MonaKeybindingContext) -> Bool {
        value(in: context) == .bool(true)
    }
}

// MARK: - MonaPrecondition

/// A precondition: a when-clause expression evaluated against a context, or nil
/// (unconditionally enabled). Actions and menu items carry a precondition; a
/// command/action is enabled only when its precondition evaluates to `true`.
public struct MonaPrecondition: Hashable, Sendable {

    /// The when-clause expression, or `nil` for unconditional enablement.
    public let expression: String?

    /// Creates a precondition. `nil` (the default) means unconditional.
    public init(_ expression: String?) {
        self.expression = expression
    }

    /// The unconditional precondition: always enabled.
    public static let unconditional = MonaPrecondition(nil)
}

// MARK: - MonaPreconditionEvaluator

/// Evaluates a `MonaPrecondition` (when-clause) against a `MonaKeybindingContext`.
///
/// Reuses the when-clause grammar + context types established by P04-T003's
/// keybinding resolver. Supported subset (covers Monaco 0.56.0's built-in
/// command/action preconditions):
///   - `&&`, `||`, `!`, parentheses
///   - `key == 'value'` / `key == true` / `key == false`
///   - `key != ...`
///   - `key =~ 'regex'` (regex match)
///   - bare `key` (truthy: `value(forKey: key) == .bool(true)`)
///
/// `nil` or empty expressions match unconditionally. A parse failure fails safe
/// (no match) so a malformed precondition never silently enables an action.
public enum MonaPreconditionEvaluator {

    /// Evaluates `precondition` against `context`.
    public static func evaluate(
        _ precondition: MonaPrecondition,
        context: MonaKeybindingContext
    ) -> Bool {
        guard let expr = precondition.expression, !expr.isEmpty else {
            return true
        }
        let lexer = MonaWhenLexer(input: expr)
        let tokens = lexer.tokenize()
        guard !tokens.isEmpty else { return true }
        var parser = MonaWhenParser(tokens: tokens)
        guard let ast = try? parser.parseExpression(), parser.isAtEnd else {
            return false
        }
        return MonaWhenEvaluator.eval(ast, context: context)
    }
}

// MARK: - When-clause evaluator (shared grammar)

/// Evaluates a when-clause AST against a `MonaKeybindingContext`.
///
/// This is the same evaluator used by the P04-T003 keybinding resolver's
/// `WhenEvaluator`; it operates on the same `MonaKeybindingContext` /
/// `MonaContextValue` types. It is the single when-clause evaluation path for
/// both keybinding when-clauses and command/action preconditions.
enum MonaWhenEvaluator {

    indirect enum Node {
        case or(Node, Node)
        case and(Node, Node)
        case not(Node)
        case truthy(String)
        case equals(String, MonaContextValue)
        case notEquals(String, MonaContextValue)
        case regex(String, String)
    }

    static func eval(_ node: Node, context: MonaKeybindingContext) -> Bool {
        switch node {
        case .or(let l, let r):
            return eval(l, context: context) || eval(r, context: context)
        case .and(let l, let r):
            return eval(l, context: context) && eval(r, context: context)
        case .not(let n):
            return !eval(n, context: context)
        case .truthy(let key):
            return context.value(forKey: key) == .bool(true)
        case .equals(let key, let rhs):
            return context.value(forKey: key) == rhs
        case .notEquals(let key, let rhs):
            return context.value(forKey: key) != rhs
        case .regex(let key, let pattern):
            guard case .string(let value)? = context.value(forKey: key) else { return false }
            return matchesRegex(value: value, pattern: pattern)
        }
    }

    private static func matchesRegex(value: String, pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return false
        }
        let range = NSRange(value.startIndex..., in: value)
        return regex.firstMatch(in: value, options: [], range: range) != nil
    }
}

// MARK: - When-clause lexer

/// Tokenizes a when-clause expression. Same grammar as P04-T003.
struct MonaWhenLexer {

    enum Token: Equatable {
        case and
        case or
        case not
        case eq
        case neq
        case regex
        case lparen
        case rparen
        case string(String)
        case word(String)
    }

    let input: String

    init(input: String) {
        self.input = input
    }

    func tokenize() -> [Token] {
        var tokens: [Token] = []
        let chars = Array(input)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c.isWhitespace {
                i += 1
                continue
            }
            switch c {
            case "(":
                tokens.append(.lparen); i += 1
            case ")":
                tokens.append(.rparen); i += 1
            case "!":
                if i + 1 < chars.count, chars[i + 1] == "=" {
                    tokens.append(.neq); i += 2
                } else {
                    tokens.append(.not); i += 1
                }
            case "&" where i + 1 < chars.count && chars[i + 1] == "&":
                tokens.append(.and); i += 2
            case "|" where i + 1 < chars.count && chars[i + 1] == "|":
                tokens.append(.or); i += 2
            case "=" where i + 1 < chars.count:
                if chars[i + 1] == "=" {
                    tokens.append(.eq); i += 2
                } else if chars[i + 1] == "~" {
                    tokens.append(.regex); i += 2
                } else {
                    return []
                }
            case "'", "\"":
                let quote = c
                i += 1
                var s = ""
                while i < chars.count, chars[i] != quote {
                    s.append(chars[i])
                    i += 1
                }
                if i < chars.count { i += 1 }
                tokens.append(.string(s))
            case "/":
                // Regex literal: `/pattern/` (the form Monaco's when-clauses use
                // on the RHS of `=~`). The pattern is scanned verbatim between
                // the delimiters so regex metacharacters (`\s`, `\b`, `^`, …)
                // are preserved for `NSRegularExpression`.
                i += 1
                var s = ""
                while i < chars.count, chars[i] != "/" {
                    s.append(chars[i])
                    i += 1
                }
                if i < chars.count { i += 1 }
                tokens.append(.string(s))
            default:
                if c.isLetter || c.isNumber || c == "_" || c == "." {
                    var s = ""
                    while i < chars.count {
                        let d = chars[i]
                        if d.isLetter || d.isNumber || d == "_" || d == "." {
                            s.append(d)
                            i += 1
                        } else {
                            break
                        }
                    }
                    tokens.append(.word(s))
                } else {
                    return []
                }
            }
        }
        return tokens
    }
}

// MARK: - When-clause parser (recursive descent)

/// Parses the when-clause token stream into an AST. Same grammar as P04-T003.
struct MonaWhenParser {

    let tokens: [MonaWhenLexer.Token]
    private var pos: Int = 0

    init(tokens: [MonaWhenLexer.Token]) {
        self.tokens = tokens
    }

    var isAtEnd: Bool { pos >= tokens.count }

    private mutating func peek() -> MonaWhenLexer.Token? {
        pos < tokens.count ? tokens[pos] : nil
    }

    private mutating func consume() -> MonaWhenLexer.Token? {
        guard pos < tokens.count else { return nil }
        let t = tokens[pos]
        pos += 1
        return t
    }

    mutating func parseExpression() throws -> MonaWhenEvaluator.Node {
        return try parseOr()
    }

    private mutating func parseOr() throws -> MonaWhenEvaluator.Node {
        var node = try parseAnd()
        while case .or? = peek() {
            _ = consume()
            let rhs = try parseAnd()
            node = .or(node, rhs)
        }
        return node
    }

    private mutating func parseAnd() throws -> MonaWhenEvaluator.Node {
        var node = try parseNot()
        while case .and? = peek() {
            _ = consume()
            let rhs = try parseNot()
            node = .and(node, rhs)
        }
        return node
    }

    private mutating func parseNot() throws -> MonaWhenEvaluator.Node {
        if case .not? = peek() {
            _ = consume()
            return .not(try parseNot())
        }
        return try parsePrimary()
    }

    private mutating func parsePrimary() throws -> MonaWhenEvaluator.Node {
        switch peek() {
        case .lparen?:
            _ = consume()
            let inner = try parseExpression()
            guard case .rparen? = peek() else { throw MonaWhenParseError.unbalancedParens }
            _ = consume()
            return inner
        case .word?:
            return try parseComparison()
        default:
            throw MonaWhenParseError.unexpectedToken
        }
    }

    private mutating func parseComparison() throws -> MonaWhenEvaluator.Node {
        guard case .word(let key) = consume() else {
            throw MonaWhenParseError.expectedWord
        }
        switch peek() {
        case .eq?, .neq?, .regex?:
            break
        default:
            return .truthy(key)
        }
        guard let op = consume() else { throw MonaWhenParseError.expectedOperator }
        guard let rhs = consume() else { throw MonaWhenParseError.expectedRhs }
        let value = resolveRhs(rhs)
        switch op {
        case .eq:
            return .equals(key, value)
        case .neq:
            return .notEquals(key, value)
        case .regex:
            if case .string(let pattern) = rhs {
                return .regex(key, pattern)
            }
            if case .word(let w) = rhs {
                return .regex(key, w)
            }
            throw MonaWhenParseError.invalidRegexRhs
        default:
            throw MonaWhenParseError.unexpectedOperator
        }
    }

    private func resolveRhs(_ token: MonaWhenLexer.Token) -> MonaContextValue {
        switch token {
        case .string(let s):
            return .string(s)
        case .word("true"):
            return .bool(true)
        case .word("false"):
            return .bool(false)
        case .word(let w):
            return .string(w)
        default:
            return .bool(false)
        }
    }
}

private enum MonaWhenParseError: Error {
    case unbalancedParens
    case unexpectedToken
    case expectedWord
    case expectedOperator
    case expectedRhs
    case invalidRegexRhs
    case unexpectedOperator
}
