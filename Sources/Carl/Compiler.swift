struct Compiler {
    /// The raw source code string to be compiled.
    let source: String

    /// Optional grid length for each dimension.
    let gridLength: Int?

    /// Number of simulation steps per rendered frame.
    let stepsPerFrame: Int

    init(source: String, gridLength: Int? = nil, stepsPerFrame: Int = 1) {
        self.source = source
        self.gridLength = gridLength
        self.stepsPerFrame = stepsPerFrame
    }

    /// Entry point to compile the source code
    func compile() throws -> String {
        var lexer: Lexer = Lexer(source)
        let tokens: [Token] = try lexer.scanTokens()

        var parser: Parser = Parser(tokens: tokens)
        let automaton: Automaton = try parser.parseAutomaton()

        let semanticAnalyzer: SemanticAnalyzer = SemanticAnalyzer(AST: automaton)
        try semanticAnalyzer.verifySemantic()

        var swiftGenerator: SwiftGenerator = SwiftGenerator(automaton, gridLength: gridLength, stepsPerFrame: stepsPerFrame)
        return try swiftGenerator.generate()
    }
}
