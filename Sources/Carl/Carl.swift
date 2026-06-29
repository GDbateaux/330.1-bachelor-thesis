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
            automaton ExcitableMedium {
                world {
                    states {
                        Quiescent,
                        Excited,
                        Refractory1,
                        Refractory2,
                        Refractory3,
                        Refractory4,
                        Refractory5,
                        Refractory6
                    }
                    neighborhood: Moore(1)
                    dimension: 2
                }

                initial {
                    Excited: 1
                }

                rules {
                    Quiescent -> Excited when count_neighbors(Excited) > 0
                    Excited -> Refractory1
                    Refractory1 -> Refractory2
                    Refractory2 -> Refractory3
                    Refractory3 -> Refractory4
                    Refractory4 -> Refractory5
                    Refractory5 -> Refractory6
                    Refractory6 -> Quiescent
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
