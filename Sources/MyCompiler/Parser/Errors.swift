struct LexerError: Error {
    let message: String
    let line: Int
}
