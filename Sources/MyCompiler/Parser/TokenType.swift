public enum TokenType {
    // keywords
    case automaton
    case world
    case states
    case neighborhood
    case Moore
    case VonNeumann
    case dimension
    case rules
    case when
    case with
    case prob
    case or
    case and
    
    // Literals
    case identifier
    case number

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
}
