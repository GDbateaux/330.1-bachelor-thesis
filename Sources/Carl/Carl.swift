// The Swift Programming Language
// https://docs.swift.org/swift-book
import Foundation

@main
struct Carl {
    static func main() throws {
        let compiler: Compiler = Compiler(source: """
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
            let generated: String = try compiler.compile()

            let url: URL = URL(fileURLWithPath: "GameOfLife.swift")
            try generated.write(to: url, atomically: true, encoding: .utf8)
        }
        catch {
            print(error.localizedDescription)
        }
    }
}
