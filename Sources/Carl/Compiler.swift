struct Compiler {
    /// The raw source code string to be compiled.
    let source: String

    /// Entry point to compile the source code
    func compile() throws -> String {
        var lexer: Lexer = Lexer(source)
        let tokens: [Token] = try lexer.scanTokens()

        var parser: Parser = Parser(tokens: tokens)
        let automaton: Automaton = try parser.parseAutomaton()

        let semanticAnalyzer: SemanticAnalyzer = SemanticAnalyzer(AST: automaton)
        try semanticAnalyzer.verifySemantic()

        var swiftGenerator: SwiftGenerator = SwiftGenerator(automaton)
        return try swiftGenerator.generate()
    }
}
