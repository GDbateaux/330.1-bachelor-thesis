// The Swift Programming Language
// https://docs.swift.org/swift-book
import Foundation

@main
struct Carl {
    static func main() throws {
        var source: String = ""
        
        if CommandLine.arguments.count == 2 {
            let path: String = CommandLine.arguments[1]
            source = try String(contentsOfFile: path, encoding: .utf8)
        } else {
            source = """
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
            """
        }
        let compiler: Compiler = Compiler(source: source)
        do {
            let generated: String = try compiler.compile()

            let url: URL = URL(fileURLWithPath: "Sources/Display/main.swift")
            try generated.write(to: url, atomically: true, encoding: .utf8)
            print("Generated Sources/Display/main.swift")
        }
        catch {
            print(error.localizedDescription)
        }
    }
}
