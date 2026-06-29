/// The tokens produced by the lexer, representing a specific type of element.
public struct Token: Sendable, Equatable {
    public let type: TokenType
    public let lexeme: String
    public let line: Int
}

/// An enumeration defining all valid categories of tokens.
public enum TokenType: Sendable {
    // keywords
    case automaton
    case world
    case states
    case neighborhood
    case dimension
    case initial
    case rules
    case when
    case with
    case prob
    case or
    case and
    
    // Literals
    case identifier
    case float
    case integer

    // Delimiters & Operators
    case leftBracket
    case rightBracket
    case leftParenthesis
    case rightParenthesis
    case comma
    case hashtag
    case minus
    case plus
    case slash
    case star
    case colon
    case rightArrow
    
    // Comparisons
    case equalEqual
    case notEqual
    case less
    case lessEqual
    case greater
    case greaterEqual

    // End of file
    case eof
}
