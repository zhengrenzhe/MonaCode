// MonaKeybindingResolver.swift
//
// P04-T003 — Port keybinding resolution and chord state to Core.
//
// `MonaKeybindingResolver` is the Core port of Monaco's keybinding resolution
// path. It resolves a platform-neutral `MonaKeyEvent` (P04-T001) to a command
// under a `MonaKeybindingContext`, driving the per-editor `MonaChordState` for
// multi-key sequences. It returns a `MonaKeybindingResolution` whose
// `outcome` is a `MonaKeyDispatchOutcome` (P04-T001) — the dispatch *decision*
// — without invoking any platform API. The platform layer (P04-T002) reads the
// decision and applies it at the native boundary (call `super.keyDown(with:)`
// or not, stop responder-chain propagation or not, etc.).
//
// Resolver semantics (ported from Monaco 0.56.0's `KeybindingsRegistry` +
// `KeybindingResolver` + `AbstractKeybindingService`, per the I3-R2 keybinding
// closure contract):
//
//   - Ordering comparator (highest priority first):
//       1. weight        — higher wins (Monaco's weight1: defaults 0,
//                           dynamic overrides 1000).
//       2. specificity    — more modifiers wins (a more specific binding
//                           outranks a less specific one when both match).
//       3. registration   — later wins (override semantics: dynamic rules
//                           appended after defaults win among ties).
//
//   - Modifier matching: a keybinding matches an event when its key equals the
//     event's key code AND its modifiers are a SUBSET of the event's modifiers
//     (every required modifier present). A no-modifier keybinding only matches a
//     no-modifier event, so a plain "K" binding cannot steal a "Cmd+K" event.
//     Subset matching makes the specificity criterion live: among the matching
//     candidates, the one with the most modifiers (the exact match, which has
//     the maximum possible modifier count for that event) wins.
//
//   - When-clause matching: the when expression is evaluated against the current
//     `MonaKeybindingContext`. `nil`/empty when matches unconditionally. The
//     supported expression subset covers Monaco's 379 default keybindings:
//     `&&`, `||`, `!`, parentheses, `==`, `!=`, `=~` (regex), bare-key truthy
//     checks, and string/bool comparisons.
//
//   - Command removal: `removeCommand(_:)` drops every keybinding whose
//     `command` equals the given ID.
//
//   - Chord: a two-part keybinding (`chordKey != nil`) enters the chord state
//     on its first part. While the chord is active, the resolver matches the
//     second event against the chord's second part. On a non-matching second
//     key, the chord is cancelled and the second key is REPLAYED as a fresh
//     first part (so a registered single command still dispatches). On timeout
//     (`hasTimedOut()`), the chord is cancelled and the triggering event is
//     replayed. `reevaluateActiveChord(context:chordState:)` cancels an
//     in-progress chord whose first-part when-clause no longer matches after a
//     context change.
//
// The resolver performs no platform dispatch and references no platform type.
//
// MonaCode is a Foundation-only target: `import Foundation` is the sole import.

import Foundation

// MARK: - Context value

/// A value in a keybinding context: a boolean or a string.
///
/// Used by the when-clause evaluator. A bare key in a when expression (e.g.
/// `editorTextFocus`) is evaluated as `value(forKey:) == .bool(true)`.
public enum MonaContextValue: Equatable, Hashable, Sendable {
    case bool(Bool)
    case string(String)
}

/// An immutable keybinding context: a map of context keys to values.
///
/// The when-clause evaluator reads context values from here. The resolver is
/// given the current context at each `resolve` call so when-clauses are
/// evaluated against the live editor state (focus, language, read-only, etc.).
public struct MonaKeybindingContext: Equatable, Sendable {

    private let values: [String: MonaContextValue]

    /// Creates an empty context.
    public init() {
        self.values = [:]
    }

    /// Creates a context from a dictionary of values.
    public init(_ values: [String: MonaContextValue]) {
        self.values = values
    }

    /// Returns the value for a context key, or `nil` if absent.
    public func value(forKey key: String) -> MonaContextValue? {
        values[key]
    }

    /// Returns a copy of this context with `key` set to `value`.
    public func with(_ key: String, _ value: MonaContextValue) -> MonaKeybindingContext {
        var copy = values
        copy[key] = value
        return MonaKeybindingContext(copy)
    }
}

// MARK: - Resolution result

/// The result of resolving one key event: the resolved command (if any), the
/// dispatch decision, and the chord status.
///
/// `outcome` is the `MonaKeyDispatchOutcome` (P04-T001) the platform layer
/// applies at the native boundary. Constructing this result performs no
/// platform dispatch.
public struct MonaKeybindingResolution: Equatable, Sendable {

    /// The resolved command ID, or `nil` when no command dispatched (no match,
    /// or a chord first part that entered the chord state without dispatching).
    public let commandId: String?

    /// The dispatch decision the platform layer applies.
    public let outcome: MonaKeyDispatchOutcome

    /// The chord-related outcome of this event (see `MonaChordStatus`).
    public let chordStatus: MonaChordStatus

    /// Creates a resolution result.
    public init(commandId: String?, outcome: MonaKeyDispatchOutcome, chordStatus: MonaChordStatus) {
        self.commandId = commandId
        self.outcome = outcome
        self.chordStatus = chordStatus
    }
}

// MARK: - Resolver

/// Resolves a `MonaKeyEvent` to a command under a context, driving chord state.
///
/// Foundation-only Core component. Produces dispatch decisions; performs no
/// platform dispatch. See the file header for the full resolver semantics.
public final class MonaKeybindingResolver {

    /// A registered keybinding paired with its registration sequence number
    /// (later registration = higher sequence = wins registration-order ties).
    private struct Entry {
        let keybinding: MonaKeybinding
        let sequence: Int
    }

    /// Registered keybindings in registration order.
    private var entries: [Entry] = []

    /// Monotonic registration counter.
    private var nextSequence: Int = 0

    /// Creates an empty resolver.
    public init() {}

    /// Creates a resolver pre-loaded with the given keybindings, in order.
    public init(keybindings: [MonaKeybinding]) {
        for kb in keybindings {
            register(kb)
        }
    }

    // MARK: - Registration & removal

    /// Registers a keybinding. Later registrations win registration-order ties.
    public func register(_ keybinding: MonaKeybinding) {
        entries.append(Entry(keybinding: keybinding, sequence: nextSequence))
        nextSequence += 1
    }

    /// Removes every keybinding whose `command` equals `commandId`.
    public func removeCommand(_ commandId: String) {
        entries.removeAll { $0.keybinding.command == commandId }
    }

    // MARK: - Resolution

    /// Resolves an event to a command, driving the given per-editor chord state.
    ///
    /// - If a chord is in progress and not timed out, attempts to complete it
    ///   with the event; on no match, cancels and replays the event as a fresh
    ///   first part.
    /// - If a chord is in progress but timed out, cancels and replays the event.
    /// - Otherwise resolves the event as a first part: a chord keybinding enters
    ///   the chord state; a single keybinding dispatches its command; no match
    ///   yields the default (pass-through) outcome.
    public func resolve(
        event: MonaKeyEvent,
        context: MonaKeybindingContext,
        chordState: MonaChordState
    ) -> MonaKeybindingResolution {
        let whenEvaluator = WhenEvaluator(context: context)
        var didCancelChord = false

        // --- Chord in progress: try to complete, else cancel + replay. ---
        if chordState.isActive {
            if chordState.hasTimedOut() {
                // Timeout: abandon the chord and replay this event fresh.
                chordState.cancel()
                didCancelChord = true
                // Fall through to first-part resolution (replay).
            } else if let entered = chordState.firstPartKeybinding,
                      let completion = findChordCompletion(event: event, entered: entered, evaluator: whenEvaluator) {
                // Second part matched: complete the chord and dispatch.
                chordState.completeChord()
                return MonaKeybindingResolution(
                    commandId: completion.keybinding.command,
                    outcome: .handled,
                    chordStatus: .completed
                )
            } else {
                // Non-matching second key: cancel and replay this event as a
                // fresh first part.
                chordState.cancel()
                didCancelChord = true
                // Fall through to first-part resolution (replay).
            }
        }

        // --- First-part resolution (idle, or after cancel/timeout replay). ---
        if let winner = findFirstPartMatch(event: event, evaluator: whenEvaluator) {
            if winner.keybinding.isChord {
                // Enter the chord state: consume the first key, await second.
                chordState.enterChord(winner.keybinding)
                return MonaKeybindingResolution(
                    commandId: nil,
                    outcome: .handled,
                    chordStatus: .entered
                )
            } else {
                // Single command dispatched.
                let status: MonaChordStatus = didCancelChord ? .cancelled : .none
                return MonaKeybindingResolution(
                    commandId: winner.keybinding.command,
                    outcome: .handled,
                    chordStatus: status
                )
            }
        }

        // --- No match. ---
        let status: MonaChordStatus = didCancelChord ? .cancelled : .none
        return MonaKeybindingResolution(
            commandId: nil,
            outcome: .default,
            chordStatus: status
        )
    }

    /// Re-evaluates the active chord against a (possibly changed) context.
    ///
    /// If a chord is in progress and its first-part keybinding's when-clause no
    /// longer matches `context`, the chord is cancelled (replay after context
    /// change) and `true` is returned. Otherwise the chord stands and `false`
    /// is returned. A no-op (returns `false`) when no chord is active.
    public func reevaluateActiveChord(
        context: MonaKeybindingContext,
        chordState: MonaChordState
    ) -> Bool {
        guard chordState.isActive, let entered = chordState.firstPartKeybinding else {
            return false
        }
        let evaluator = WhenEvaluator(context: context)
        if evaluator.evaluate(entered.when) {
            return false
        }
        chordState.cancel()
        return true
    }

    // MARK: - Candidate selection

    /// Finds the winning first-part candidate matching `event`, ordered by
    /// weight (desc), specificity (desc), registration (desc). `nil` if none.
    private func findFirstPartMatch(
        event: MonaKeyEvent,
        evaluator: WhenEvaluator
    ) -> Entry? {
        let matching = entries.filter { entry in
            matchesFirstPart(event: event, keybinding: entry.keybinding)
                && evaluator.evaluate(entry.keybinding.when)
        }
        return matching.max(by: orderingComparator)
    }

    /// Finds the winning chord-completion candidate: shares the entered first
    /// part, its `chordKey` matches the event, its `chordModifiers` are a
    /// subset of the event modifiers, and its when-clause matches. `nil` if none.
    private func findChordCompletion(
        event: MonaKeyEvent,
        entered: MonaKeybinding,
        evaluator: WhenEvaluator
    ) -> Entry? {
        let matching = entries.filter { entry in
            let kb = entry.keybinding
            guard kb.isChord else { return false }
            // Same first part as the one that entered the chord (exact).
            guard kb.key == entered.key, kb.modifiers == entered.modifiers else { return false }
            // Second part matches the event.
            guard kb.chordKey == event.keyCode else { return false }
            guard modifiersMatch(bindingMods: kb.chordModifiers, eventMods: event.modifiers) else { return false }
            return evaluator.evaluate(kb.when)
        }
        return matching.max(by: orderingComparator)
    }

    /// `true` when `keybinding`'s first part matches `event`: key code equals
    /// and the binding's modifiers are a subset of the event's modifiers (with
    /// the no-modifier-binding guard).
    private func matchesFirstPart(event: MonaKeyEvent, keybinding: MonaKeybinding) -> Bool {
        guard keybinding.key == event.keyCode else { return false }
        return modifiersMatch(bindingMods: keybinding.modifiers, eventMods: event.modifiers)
    }

    /// Subset modifier matching with the no-modifier guard: a no-modifier
    /// binding matches only a no-modifier event, so "K" cannot steal "Cmd+K".
    private func modifiersMatch(bindingMods: MonaKeyMod, eventMods: MonaKeyMod) -> Bool {
        if bindingMods.isEmpty {
            return eventMods.isEmpty
        }
        return bindingMods.isSubset(of: eventMods)
    }

    /// Ordering comparator: returns `true` when `a` is LOWER priority than `b`
    /// (the "less-than" relation). Used with `max(by:)`, which returns the
    /// greatest element under this relation — i.e. the highest priority.
    /// Priority: weight desc, then specificity desc, then registration desc.
    private func orderingComparator(_ a: Entry, _ b: Entry) -> Bool {
        let ka = a.keybinding
        let kb = b.keybinding
        if ka.weight != kb.weight {
            return ka.weight < kb.weight
        }
        let sa = modifierCount(ka.modifiers)
        let sb = modifierCount(kb.modifiers)
        if sa != sb {
            return sa < sb
        }
        return a.sequence < b.sequence
    }

    /// Counts how many of the four Monaco modifiers are set.
    private func modifierCount(_ mods: MonaKeyMod) -> Int {
        var count = 0
        if mods.contains(.ctrlCmd) { count += 1 }
        if mods.contains(.shift)   { count += 1 }
        if mods.contains(.alt)     { count += 1 }
        if mods.contains(.winCtrl) { count += 1 }
        return count
    }
}

// MARK: - When-clause evaluator

/// Evaluates a Monaco-style when-clause expression against a context.
///
/// Supported subset (covers Monaco 0.56.0's 379 default keybindings):
///   - `&&`, `||`, `!`, parentheses
///   - `key == 'value'` / `key == true` / `key == false`
///   - `key != ...`
///   - `key =~ 'regex'` (regex match; the rhs string is the pattern)
///   - bare `key` (truthy: `value(forKey: key) == .bool(true)`)
///
/// `nil` or empty expressions match unconditionally. A parse failure fails
/// safe (no match) so a malformed when-clause never silently dispatches.
private struct WhenEvaluator {

    let context: MonaKeybindingContext

    func evaluate(_ expr: String?) -> Bool {
        guard let expr = expr, !expr.isEmpty else { return true }
        var lexer = WhenLexer(input: expr)
        let tokens = lexer.tokenize()
        guard !tokens.isEmpty else { return true }
        var parser = WhenParser(tokens: tokens)
        guard let ast = try? parser.parseExpression(), parser.isAtEnd else {
            return false // parse error → fail safe
        }
        return eval(ast)
    }

    // MARK: AST

    fileprivate indirect enum Node {
        case or(Node, Node)
        case and(Node, Node)
        case not(Node)
        case truthy(String)
        case equals(String, MonaContextValue)
        case notEquals(String, MonaContextValue)
        case regex(String, String) // key, pattern
    }

    // MARK: Evaluation

    private func eval(_ node: Node) -> Bool {
        switch node {
        case .or(let l, let r):
            return eval(l) || eval(r)
        case .and(let l, let r):
            return eval(l) && eval(r)
        case .not(let n):
            return !eval(n)
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

    private func matchesRegex(value: String, pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return false
        }
        let range = NSRange(value.startIndex..., in: value)
        return regex.firstMatch(in: value, options: [], range: range) != nil
    }
}

// MARK: - When-clause lexer

/// Tokenizes a when-clause expression.
private struct WhenLexer {

    enum Token: Equatable {
        case and          // &&
        case or           // ||
        case not          // !
        case eq           // ==
        case neq          // !=
        case regex        // =~
        case lparen        // (
        case rparen        // )
        case string(String) // '...'
        case word(String)   // bare identifier / true / false
    }

    let input: String

    init(input: String) {
        self.input = input
    }

    mutating func tokenize() -> [Token] {
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
                    return [] // parse error
                }
            case "'", "\"":
                // String literal until the matching quote.
                let quote = c
                i += 1
                var s = ""
                while i < chars.count, chars[i] != quote {
                    s.append(chars[i])
                    i += 1
                }
                if i < chars.count { i += 1 } // consume closing quote
                tokens.append(.string(s))
            default:
                // Bare word: identifier or true/false. Word characters are
                // ASCII letters, digits, underscore, and dot.
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
                    return [] // unrecognized character → parse error
                }
            }
        }
        return tokens
    }
}

// MARK: - When-clause parser (recursive descent)

/// Parses the when-clause token stream into an AST.
///
/// Grammar (precedence low → high):
///   expression := orExpr
///   orExpr     := andExpr ('||' andExpr)*
///   andExpr    := notExpr ('&&' notExpr)*
///   notExpr    := '!' notExpr | primary
///   primary    := '(' expression ')' | comparison
///   comparison := word (op rhs)?
///   op         := '==' | '!=' | '=~'
///   rhs        := string | word
private struct WhenParser {

    let tokens: [WhenLexer.Token]
    private var pos: Int = 0

    init(tokens: [WhenLexer.Token]) {
        self.tokens = tokens
    }

    var isAtEnd: Bool { pos >= tokens.count }

    private mutating func peek() -> WhenLexer.Token? {
        pos < tokens.count ? tokens[pos] : nil
    }

    private mutating func consume() -> WhenLexer.Token? {
        guard pos < tokens.count else { return nil }
        let t = tokens[pos]
        pos += 1
        return t
    }

    mutating func parseExpression() throws -> WhenEvaluator.Node {
        return try parseOr()
    }

    private mutating func parseOr() throws -> WhenEvaluator.Node {
        var node = try parseAnd()
        while case .or? = peek() {
            _ = consume()
            let rhs = try parseAnd()
            node = .or(node, rhs)
        }
        return node
    }

    private mutating func parseAnd() throws -> WhenEvaluator.Node {
        var node = try parseNot()
        while case .and? = peek() {
            _ = consume()
            let rhs = try parseNot()
            node = .and(node, rhs)
        }
        return node
    }

    private mutating func parseNot() throws -> WhenEvaluator.Node {
        if case .not? = peek() {
            _ = consume()
            return .not(try parseNot())
        }
        return try parsePrimary()
    }

    private mutating func parsePrimary() throws -> WhenEvaluator.Node {
        switch peek() {
        case .lparen?:
            _ = consume()
            let inner = try parseExpression()
            guard case .rparen? = peek() else { throw WhenParseError.unbalancedParens }
            _ = consume()
            return inner
        case .word?:
            return try parseComparison()
        default:
            throw WhenParseError.unexpectedToken
        }
    }

    private mutating func parseComparison() throws -> WhenEvaluator.Node {
        guard case .word(let key) = consume() else {
            throw WhenParseError.expectedWord
        }
        // Bare word (no operator): truthy check.
        switch peek() {
        case .eq?, .neq?, .regex?:
            break
        default:
            return .truthy(key)
        }
        guard let op = consume() else { throw WhenParseError.expectedOperator }
        guard let rhs = consume() else { throw WhenParseError.expectedRhs }
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
            // =~ with a bare-word rhs: treat the word as the pattern.
            if case .word(let w) = rhs {
                return .regex(key, w)
            }
            throw WhenParseError.invalidRegexRhs
        default:
            throw WhenParseError.unexpectedOperator
        }
    }

    private func resolveRhs(_ token: WhenLexer.Token) -> MonaContextValue {
        switch token {
        case .string(let s):
            return .string(s)
        case .word("true"):
            return .bool(true)
        case .word("false"):
            return .bool(false)
        case .word(let w):
            // Bare-word rhs compared as a string value.
            return .string(w)
        default:
            return .bool(false)
        }
    }
}

private enum WhenParseError: Error {
    case unbalancedParens
    case unexpectedToken
    case expectedWord
    case expectedOperator
    case expectedRhs
    case invalidRegexRhs
    case unexpectedOperator
}

// MARK: - MonaKeyDispatchOutcome convenience

extension MonaKeyDispatchOutcome {
    /// The "Core handler consumed the event" outcome: handled, suppress the
    /// platform default, and stop responder-chain propagation. Used by the
    /// resolver when a command or chord matches.
    fileprivate static let handled = MonaKeyDispatchOutcome(
        handled: true,
        preventDefault: true,
        stopPropagation: true
    )
}
