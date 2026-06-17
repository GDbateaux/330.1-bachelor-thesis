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
            automaton ForestFire {
                world {
                    states {
                        Fire,
                        Tree,
                        Empty,
                        Ash
                    }
                    neighborhood: VonNeumann(1)
                    dimension: 2
                }
                
                rules {
                    Fire -> Ash
                    Tree -> Fire when count_neighbors(Fire) > 0
                    Tree -> Fire with prob 0.01
                    Ash -> Empty when count_neighbors(Fire) == 0
                    Empty -> Tree with prob 0.01
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
