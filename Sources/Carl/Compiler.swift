struct Compiler {
    let source: String

    func executeCompilation() throws {
        var lexer: Lexer = Lexer(source)
        let tokens: [Token] = try lexer.scanTokens()
        var parser: Parser = Parser(tokens: tokens)
        let _: Automaton = try parser.parseAutomaton()
    }

    func compile() {
        do {
            try executeCompilation()
        }
        catch {
            print(error.localizedDescription)
        }
    }

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
