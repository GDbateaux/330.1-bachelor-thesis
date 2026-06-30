struct Compiler {
    /// The raw source code string to be compiled.
    let source: String

    /// Optional grid length for each dimension.
    let gridLength: Int?

    init(source: String, gridLength: Int? = nil) {
        self.source = source
        self.gridLength = gridLength
    }

    /// Entry point to compile the source code
    func compile() throws -> String {
        var lexer: Lexer = Lexer(source)
        let tokens: [Token] = try lexer.scanTokens()

        var parser: Parser = Parser(tokens: tokens)
        let automaton: Automaton = try parser.parseAutomaton()

        let semanticAnalyzer: SemanticAnalyzer = SemanticAnalyzer(AST: automaton)
        try semanticAnalyzer.verifySemantic()

        var swiftGenerator: SwiftGenerator = SwiftGenerator(automaton, gridLength: gridLength)
        return try swiftGenerator.generate()
    }
}
