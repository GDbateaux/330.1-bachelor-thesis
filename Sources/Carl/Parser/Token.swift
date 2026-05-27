public struct Token: Sendable, Equatable {
    public let type: TokenType
    public let lexeme: String
    public let line: Int
}

public enum TokenType: Sendable {
    // keywords
    case automaton
    case world
    case states
    case neighborhood
    case dimension
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
