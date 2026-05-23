// The Swift Programming Language
// https://docs.swift.org/swift-book
@main
struct MyCompiler {
    static func main() {
        var lexer: Lexer = Lexer("""
            automaton GameOfLife {
            world {
                states { Dead, Alive }
                neighborhood: Moore(1)
                dimension: 2
            }


            rules {
                Dead -> Alive when count_neighbors(Alive) == 3
                Alive -> Dead when count_neighbors(Alive) < 2 or count_neighbors(Alive) > 3
            }
        }
        """)

        do {
            let tokens: [Token] = try lexer.scanTokens()
            var parser: Parser = Parser(tokens: tokens)
            let automaton: Automaton = try parser.parseAutomaton()
            print(automaton.name)
        }
        catch CompilerError.LexerError(let message, let line) {
            print("Lexer error [Line: \(line)]: \(message)")
        }
        catch CompilerError.ParserError(let message, let token) {
            print("Parser error [Line: \(token.line)]: \(message)")
        }
        catch {
            print("Unexpected error: \(error).")
        }
    }
}
