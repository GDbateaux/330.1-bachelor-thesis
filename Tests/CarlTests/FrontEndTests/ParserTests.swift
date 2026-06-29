import Testing
@testable import Carl

@Test func testForestFire() throws {
    let input: String = """
    automaton ForestFire {
        world {
            states {
                Fire,
                Tree,
                Empty,
                Ash,
            }
            neighborhood: VonNeumann(1)
            dimension: 2
        }

        initial {
            Fire: 0.2
            Tree: 0.4
            Empty: 0.4
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

    var lexer: Lexer = Lexer(input)
    let tokens: [Token] = try lexer.scanTokens()
    
    var parser: Parser = Parser(tokens: tokens)
    let result: Automaton = try parser.parseAutomaton()
    
    let expectedAST: Automaton = Automaton(
        name: "ForestFire",
        world: World(
            states: ["Fire", "Tree", "Empty", "Ash"],
            neighborhood: Neighborhood(type: "VonNeumann", range: 1),
            dimension: 2
        ),
        initial: ["Fire" : 0.2, "Tree" : 0.4, "Empty" : 0.4],
        rules: [
            Rule(
                initialState: "Fire",
                endState: "Ash",
                condition: nil,
                probability: 1.0
            ),
            Rule(
                initialState: "Tree",
                endState: "Fire",
                condition: Expression.binary(
                    Expression.call("count_neighbors", ["Fire"]),
                    BinaryOperator.greater,
                    Expression.number(0)
                ),
                probability: 1.0
            ),
            Rule(
                initialState: "Tree",
                endState: "Fire",
                condition: nil,
                probability: 0.01
            ),
            Rule(
                initialState: "Ash",
                endState: "Empty",
                condition: Expression.binary(
                    Expression.call("count_neighbors", ["Fire"]),
                    BinaryOperator.equalEqual,
                    Expression.number(0)
                ),
                probability: 1.0
            ),
            Rule(
                initialState: "Empty",
                endState: "Tree",
                condition: nil,
                probability: 0.01
            )
        ]
    )
    
    #expect(result == expectedAST)
}

@Test func testWireworld() throws {
    let input: String = """
    automaton Wireworld {
        world {
            states {
                Empty,
                ElectronHead,
                ElectronTail,
                Conductor
            }
            neighborhood: Moore(1)
            dimension: 2
        }

        rules {
            ElectronHead -> ElectronTail
            ElectronTail -> Conductor
            Conductor -> ElectronHead when #ElectronHead == 1 or #ElectronHead == 2
        }
    }
    """

    var lexer: Lexer = Lexer(input)
    let tokens: [Token] = try lexer.scanTokens()
    
    var parser: Parser = Parser(tokens: tokens)
    let result: Automaton = try parser.parseAutomaton()
    
    let expectedAST: Automaton = Automaton(
        name: "Wireworld",
        world: World(
            states: ["Empty", "ElectronHead", "ElectronTail", "Conductor"],
            neighborhood: Neighborhood(type: "Moore", range: 1),
            dimension: 2
        ),
        initial: [:],
        rules: [
            Rule(
                initialState: "ElectronHead",
                endState: "ElectronTail",
                condition: nil,
                probability: 1.0
            ),
            Rule(
                initialState: "ElectronTail",
                endState: "Conductor",
                condition: nil,
                probability: 1.0
            ),
            Rule(
                initialState: "Conductor",
                endState: "ElectronHead",
                condition: Expression.binary(
                    Expression.binary(
                        Expression.neighborShortcut("ElectronHead"),
                        BinaryOperator.equalEqual,
                        Expression.number(1)
                    ), 
                    BinaryOperator.or,
                    Expression.binary(
                        Expression.neighborShortcut("ElectronHead"),
                        BinaryOperator.equalEqual,
                        Expression.number(2)
                    )
                ),
                probability: 1.0
            )
        ]
    )
    
    #expect(result == expectedAST)
}
