// The Swift Programming Language
// https://docs.swift.org/swift-book
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
            try compiler.compile()
        }
        catch {
            print(error.localizedDescription)
        }
    }
}
