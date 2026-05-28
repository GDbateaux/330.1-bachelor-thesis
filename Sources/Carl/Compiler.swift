struct Compiler {
    /// The raw source code string to be compiled.
    let source: String

    /// Entry point to compile the source code
    func compile() throws {
        var lexer: Lexer = Lexer(source)
        let tokens: [Token] = try lexer.scanTokens()
        var parser: Parser = Parser(tokens: tokens)
        let _: Automaton = try parser.parseAutomaton()
    }
}
