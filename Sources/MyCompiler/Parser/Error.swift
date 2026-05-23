enum CompilerError: Error {
    case LexerError(message: String, line: Int)
    case ParserError(message: String, token: Token)
}
