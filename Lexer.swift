//
// Lexer.swift
//
// SwiSwi - a tiny Swift-like language
//
// Created for the Budapest Swift Meetup
// by Árpád Goretity (H2CO3)
// on 28/10/2015
//
// There's no warranty whatsoever.
//

import Foundation

struct SrcLoc : CustomStringConvertible {
    var line: UInt
    var column: UInt

    init(_ line: UInt, _ column: UInt) {
        self.line = line
        self.column = column
    }

    var description: String {
        return "L:\(line) C:\(column)"
    }
}

struct Token : CustomStringConvertible {
    enum Kind : CustomStringConvertible, Equatable {
        case Word
        case Punct
        case Number
        case StringLiteral
        case Whitespace

        var description: String {
            switch self {
            case .Word:          return "Word"
            case .Punct:         return "Punct"
            case .Number:        return "Number"
            case .StringLiteral: return "StringLiteral"
            case .Whitespace:    return "Whitespaace"
            }
        }
    }

    let kind: Kind
    let location: SrcLoc
    let value: String

    init(_ kind: Kind, _ loc: SrcLoc, _ value: String) {
        self.kind = kind
        self.location = loc
        self.value = value
    }

    var isKeyword: Bool {
        let keywords = NSSet(array: [
            "func",
            "if",
            "else",
            "while",
            "var",
            "return"
        ])
        return keywords.containsObject(value)
    }

    var description: String {
        return "<Token kind: \(kind), location: \(location) value: \(value)>"
    }
}

extension NSCharacterSet {
    // Helper function for character sets
    func graphemeClusterIsMember(char: Character?) -> Bool {
    	if char == nil {
            return false
        }

        for ch in String(char!).unicodeScalars {
            if !self.longCharacterIsMember(UTF32Char(ch)) {
                return false
            }
        }
        return true
    }
}

class Lexer {
    let src: String
    var cursor: String.Index
    var location: SrcLoc
    var error: String?

    // Character classification
    let wordBeginCharSet = NSCharacterSet.letterCharacterSet()
    let wordContCharSet = NSCharacterSet.alphanumericCharacterSet()
    // we only want to allow Arabic digits 0...9 so that we can parse token to a number
    // let numCharSet = NSCharacterSet.decimalDigitCharacterSet()
    let numCharSet = NSCharacterSet(charactersInString: "0123456789")
    let stringCharSet = NSCharacterSet(charactersInString: "'\"")
    let punctCharSet = NSMutableCharacterSet.symbolCharacterSet()
    let spaceCharSet = NSCharacterSet.whitespaceAndNewlineCharacterSet()
    let newlineCharSet = NSCharacterSet.newlineCharacterSet()

    // Constructor
    init(_ src: String) {
        self.src = src
        self.cursor = src.startIndex
        self.punctCharSet.formUnionWithCharacterSet(
            NSCharacterSet.punctuationCharacterSet()
        )
        self.location = SrcLoc(1, 1)
        self.error = nil
    }

    // end-of-input: true if all characters have been processed
    func eof() -> Bool {
        return cursor >= src.endIndex
    }

    // Returns next character at index 'cursor + offset' if within bounds,
    // or nil if reached end-of-input.
    func lookahead(offset: Int) -> Character? {
        if offset < cursor.distanceTo(src.endIndex) {
            return src[cursor.advancedBy(offset)]
        }
        return nil
    }

    // gets next character if any, or nil if reached end-of-input.
    func nextChar() -> Character? {
        return lookahead(0)
    }

    func lookaheadUpTo(length: Int) -> String {
        let actualLength = min(length, cursor.distanceTo(src.endIndex))
        let end = cursor.advancedBy(actualLength)
        return src.substringWithRange(Range(start: cursor, end: end))
    }

    // returns next character if any, advances cursor to subsequent character.
    func step() -> Character? {
        let ch = nextChar()
        cursor++

        // Keep track of line and character number
        if newlineCharSet.graphemeClusterIsMember(ch) {
            location.line++
            location.column = 1
        } else {
            location.column++
        }

        return ch
    }

    // return substring from current position of length at most 'length'
    // then advance cursor by the length of the resulting substring.
    func stepByAtMost(length: Int) -> String {
        var value = ""
        for (var i = 0; i < length && !eof(); i++) {
            value.append(step()!);
        }
        return value
    }

    //////////////
    // Predicates: test for the type of the next token.
    //////////////
    func isWordBegin() -> Bool {
        return wordBeginCharSet.graphemeClusterIsMember(nextChar())
    }

    func isWordCont() -> Bool {
        return wordContCharSet.graphemeClusterIsMember(nextChar())
    }

    func isNumber() -> Bool {
        return numCharSet.graphemeClusterIsMember(nextChar())
    }

    func isString() -> Bool {
        return stringCharSet.graphemeClusterIsMember(nextChar())
    }

    func isPunct() -> Bool {
        // # starts a line comment
        let ch = nextChar()
        return ch != "#" && punctCharSet.graphemeClusterIsMember(nextChar())
    }

    func isWhitespace() -> Bool {
        // # starts a line comment
        let ch = nextChar()
        return ch == "#" || spaceCharSet.graphemeClusterIsMember(ch)
    }

    func isNewline() -> Bool {
        return newlineCharSet.graphemeClusterIsMember(nextChar())
    }

    //////////////
    // Extractors: actually return the next token.
    //////////////
    func lexWord() -> Token? {
        assert(isWordBegin())
        // Save location
        let loc = location

        var value = ""
        while isWordCont() {
            // if the character is valid for identifier names, it can't be nil.
            value.append(step()!)
        }

        return Token(.Word, loc, value)
    }

    func lexNumber() -> Token? {
        assert(isNumber())

        let loc = location
        var value = ""

        while isNumber() {
            value.append(step()!)
        }

        if nextChar() == "." {
            value.append(step()!)

            while isNumber() {
                value.append(step()!)
            }
        }

        return Token(.Number, loc, value)
    }

    func lexString() -> Token? {
        assert(isString())

        // Save location
        let loc = location

        var value = ""

        // skip leading quote or apostrophe
        let startDelim = step()

        while nextChar() != startDelim && !eof() {
            if newlineCharSet.graphemeClusterIsMember(nextChar()) {
                error = "string literal cannot contain line breaks"
                return nil
            }

            value.append(step()!)
        }

        if eof() {
            error = "unterminated string literal"
            return nil
        }

        // skip trailing quote or apostrophe
        step()

        return Token(.StringLiteral, loc, value)
    }

    func lexPunct() -> Token? {
        assert(isPunct())
        let loc = location

        let ops = [
            "++", "+", "--", "->", "-", "*", "/", ":", ".",
            ",", ";", "(", ")", "{", "}", "[", "]",
            "<=", "<", ">=", ">", "!=", "==", "&&", "||", "!",
            "="
        ];

        for (_, op) in ops.enumerate() {
            let candidate = lookaheadUpTo(op.characters.count)
            if candidate == op {
                let value = stepByAtMost(op.characters.count)
                return Token(.Punct, loc, value)
            }
        }

        error = "unrecognized operator: '\(nextChar())'"
        return nil
    }

    func lexWhitespace() -> Token? {
        assert(isWhitespace())

        let loc = location

        if nextChar() == "#" {
            // line comment, skip '#'
            step()
            while !eof() && !isNewline() {
                step()
            }
        } else {
            // real whitespace
            while isWhitespace() {
                step()
            }
        }

        return Token(.Whitespace, loc, "") // ignored anyway
    }

    // Extracts the next token if any.
    // On EOF or error, returns nil.
    func nextToken() -> Token? {
        struct PredAndExtr {
            let predicate: () -> Bool
            let extract: () -> Token?
        }

        let lexers = [
            PredAndExtr(predicate: isWordBegin,  extract: lexWord),
            PredAndExtr(predicate: isNumber,     extract: lexNumber),
            PredAndExtr(predicate: isString,     extract: lexString),
            PredAndExtr(predicate: isPunct,      extract: lexPunct),
            PredAndExtr(predicate: isWhitespace, extract: lexWhitespace),
        ]

        for (_, fns) in lexers.enumerate() {
            if fns.predicate() {
                return fns.extract()
            }
        }

        return nil
    }

    func lex() -> [Token]? {
        var tokens: [Token] = []

        // var token: Token?
        while let token = nextToken() {
            if token.kind != .Whitespace {
                tokens.append(token)
            }
        }

        return error == nil ? tokens : nil
    }
}
