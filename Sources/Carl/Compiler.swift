struct Compiler {
    /// The raw source code string to be compiled.
    let source: String

    /// Executes the compilation pipeline.
    func executeCompilation() throws {
        var lexer: Lexer = Lexer(source)
        let tokens: [Token] = try lexer.scanTokens()
        var parser: Parser = Parser(tokens: tokens)
        let _: Automaton = try parser.parseAutomaton()
    }

    /// Compiles the source code for standard runs.
    func compile() {
        do {
            try executeCompilation()
        }
        catch {
            print(error.localizedDescription)
        }
    }

    /// Compiles the source code and captures diagnostic as a string.
    /// This method is tailored for tests.
    ///
    /// - Returns: An empty string "" if compilation succeeds, otherwise the error message string.
    func compileAndCaptureError() -> String {
        do {
            try executeCompilation()
            return ""
        } 
        catch {
            return error.localizedDescription
        }
    }
}
