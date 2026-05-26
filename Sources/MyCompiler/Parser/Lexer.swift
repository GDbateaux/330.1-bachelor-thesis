// ====================================================================================
// Inspired by "Crafting Interpreters" by Robert Nystrom (Chapter 4: Scanning)
// Original source: https://craftinginterpreters.com/scanning.html
// ====================================================================================
public struct Lexer{
    /// The source String being used
    public let source: String

    /// The list of tokens produced by the lexer
    public var tokens: [Token] = []

    /// The start index of the token being scanned
    private var start: String.Index

    /// The current index in the source string during scanning.
    private var current: String.Index

    /// The line in the source string
    private var line: Int = 1

    /// Initializes a new Lexer with the specified source string.
    ///
    /// - Parameter source: The source code string to be tokenized.
    init(_ source: String) {
        self.source = source
        self.start = source.startIndex
        self.current = source.startIndex
    }

    /// Scans the source string and populates the tokens array.
    /// 
    /// - Returns: The list of scanned tokens
    mutating func scanTokens() throws -> [Token] {
        while !isAtEnd(){
            start = current
            let c: Character = advance()

            switch c {
                case "{": addToken(TokenType.leftBracket)
                case "}": addToken(TokenType.rightBracket)
                case "(": addToken(TokenType.leftParenthesis)
                case ")": addToken(TokenType.rightParenthesis)
                case ",": addToken(TokenType.comma)
                case "#": addToken(TokenType.hashtag)
                case "+": addToken(TokenType.plus)
                case "/": addToken(TokenType.slash)
                case "*": addToken(TokenType.star)
                case ":": addToken(TokenType.colon)

                case "=":
                    guard match("=") else {
                        throw CompilerError.LexerError(message: "Unexpected '=' (only '==' is allowed)", line: line)
                    }
                    addToken(TokenType.equalEqual)
                case "!":
                    guard match("=") else {
                        throw CompilerError.LexerError(message: "Unexpected '!' (only '!=' is allowed)", line: line)
                    }
                    addToken(TokenType.notEqual)
                case "-": 
                    match(">") ? addToken(TokenType.rightArrow) : addToken(TokenType.minus)
                case "<":
                    match("=") ? addToken(TokenType.lessEqual) : addToken(TokenType.less)
                case ">":
                    match("=") ? addToken(TokenType.greaterEqual) : addToken(TokenType.greater)
                
                case "\n": line += 1
                case " ", "\t", "\r": break

                default: 
                    if isDigit(c) {
                        takeNumber()
                    }
                    else if isIdentifierHead(c) {
                        takeIdentifier()
                    }
                    else {
                        throw CompilerError.LexerError(message: "Unexpected character '\(c)'", line: line)
                    }
            }
        }
        tokens.append(Token(type: TokenType.eof, lexeme: "", line: line))
        return tokens
    }

    /// Consume and returns the next character in the source string
    /// 
    /// - Returns: The character at the current scanning position.
    private mutating func advance() -> Character {
        let char: Character = source[current]
        current = source.index(after: current)
        return char
    }

    /// Checks if the current character matches an expected character. Consume it if it match
    /// 
    /// - Parameter char: Expected character
    /// - Returns: true if the current character matches the current character, otherwise false
    private mutating func match(_ char: Character) -> Bool {
        if (isAtEnd() || source[current] != char) {
            return false
        }
        current = source.index(after: current)
        return true
    }

    /// Returns the current character without consuming it, or nil if at the end
    ///  
    /// - Returns: The character at the current position, or nil if at the end
    private func peek() -> Character? {
        isAtEnd() ? nil : source[current]
    }

    /// Returns the next character without consuming it, or nil if at the end
    ///  
    /// - Returns: The next character at the current position, or nil if at the end
    private func peekNext() -> Character? {
        guard current < source.index(before: source.endIndex) else {
            return nil
        }
        let nextIndex: String.Index = source.index(after: current)
        return source[nextIndex]
    }

    /// Checks if the scanner has reached the end of the string
    /// 
    /// - Returns: true if the scanner is at the end, otherwise false
    private func isAtEnd() -> Bool {
        return current >= source.endIndex
    }

    /// Appends a new token of the specified type to the generated token list.
    ///
    /// - Parameter type: The TokenType classification to assign to the extracted lexeme.
    private mutating func addToken(_ type: TokenType) {
        let lexeme: String = String(source[start..<current])
        tokens.append(Token(type: type, lexeme: lexeme, line: line))
    }

    /// Checks if the given character is a digit
    ///
    /// - Parameter char: The character to evaluate
    /// - Returns: true if the character is a digit. otherwise false
    private func isDigit(_ char: Character) -> Bool {
        return char >= "0" && char <= "9"
    }

    /// Checks if the given character is valid as the starting character of an identifier
    ///
    /// - Parameter char: The character to evaluate
    /// - Returns: true if the character is valid. otherwise false
    private func isIdentifierHead(_ char: Character) -> Bool {
        return char >= "a" && char <= "z" || char >= "A" && char <= "Z"
    }

    /// Checks if the given character is valid inside the body or tail of an identifier
    ///
    /// - Parameter char: The character to evaluate
    /// - Returns: true if the character is valid. otherwise false
    private func isIdentifierTail(_ char: Character) -> Bool {
        return isIdentifierHead(char) || char == "_" || isDigit(char)
    }

    /// Consumes a numeric literal from the source string
    private mutating func takeNumber() {
        while let char = peek(), isDigit(char) {
            _ = advance()
        }

        if let char = peek(), char == ".", let nextChar = peekNext(), isDigit(nextChar)  {
            _ = advance()
            while let char = peek(), isDigit(char) {
                _ = advance()
            }
            addToken(TokenType.float)
        }
        else {
            addToken(TokenType.integer)
        }
    }

    /// Consumes an identifier from the source string
    private mutating func takeIdentifier() {
        while let char = peek(), isIdentifierTail(char) {
            _ = advance()
        }
        addToken(getIdentifierType())
    }

    /// Returns the type of the currently scanned identifer
    /// 
    /// - Returns: The identifier type
    private func getIdentifierType() -> TokenType {
        let lexeme: String = String(source[start..<current])

        let type: TokenType = switch lexeme {
            case "automaton": TokenType.automaton
            case "world": TokenType.world
            case "states": TokenType.states
            case "neighborhood": TokenType.neighborhood
            case "dimension": TokenType.dimension
            case "rules": TokenType.rules
            case "when": TokenType.when
            case "with": TokenType.with
            case "prob": TokenType.prob
            case "or": TokenType.or
            case "and": TokenType.and
            default: TokenType.identifier
        }
        return type
    }
}
