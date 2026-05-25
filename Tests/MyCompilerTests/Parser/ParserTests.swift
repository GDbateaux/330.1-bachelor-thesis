import Testing
@testable import MyCompiler

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
            neighborhood: Neighborhood(type: NeighborhoodType.VonNeumann, range: 1),
            dimension: 2
        ),
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
                    Expression.number(0.0)
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
                    Expression.number(0.0)
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
            neighborhood: Neighborhood(type: NeighborhoodType.Moore, range: 1),
            dimension: 2
        ),
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
                        Expression.number(1.0)
                    ), 
                    BinaryOperator.or,
                    Expression.binary(
                        Expression.neighborShortcut("ElectronHead"),
                        BinaryOperator.equalEqual,
                        Expression.number(2.0)
                    )
                ),
                probability: 1.0
            )
        ]
    )
    
    #expect(result == expectedAST)
}

@Test func testParserErrors() throws {
    // Missing colon after dimension
    let missingColon: String = """
    automaton Test {
        world { dimension 2 }
        rules {}
    }
    """
    var lexer1: Lexer = Lexer(missingColon)
    var parser1: Parser = Parser(tokens: try lexer1.scanTokens())
    
    #expect(throws: CompilerError.ParserError(message: "Expected ':' after 'dimension'.", 
        token: Token(type: .integer, lexeme: "2", line: 2))) {
        try parser1.parseAutomaton()
    }

    // Missing arrow after first rule
    let missingArrow: String = """
    automaton Test {
        world { dimension: 2 }
        rules {
            Dead Alive
        }
    }
    """
    var lexer2: Lexer = Lexer(missingArrow)
    var parser2: Parser = Parser(tokens: try lexer2.scanTokens())
    
    #expect(throws: CompilerError.ParserError(message: "Expected '->' to follow the initial state.",
        token: Token(type: .identifier, lexeme: "Alive", line: 4))) {
        try parser2.parseAutomaton()
    }

    // Invalid range in neighborhood (expecting integer)
    let invalidRange: String = """
    automaton Test {
        world { neighborhood: Moore(1.5) }
        rules {}
    }
    """
    var lexer3: Lexer = Lexer(invalidRange)
    var parser3: Parser = Parser(tokens: try lexer3.scanTokens())
    
    #expect(throws: CompilerError.ParserError(message: "Expected an integer for neighborhood range.",
        token: Token(type: .float, lexeme: "1.5", line: 2))) {
        try parser3.parseAutomaton()
    }

    // Unknown neighborhood
    let unknownNeighborhood: String = """
    automaton Test {
        world { neighborhood: Custom(1) }
        rules {}
    }
    """
    var lexer4: Lexer = Lexer(unknownNeighborhood)
    var parser4: Parser = Parser(tokens: try lexer4.scanTokens())
    
    #expect(throws: CompilerError.ParserError(message: "Unknown neighborhood type 'Custom'. Expected 'Moore' or 'VonNeumann'.",
        token: Token(type: .identifier, lexeme: "Custom", line: 2))) {
        try parser4.parseAutomaton()
    }

    // Missing comparison after first rule
    let missingComparison: String = """
    automaton Test {
        world { dimension: 2 }
        rules {
            Dead -> Alive when count_neighbors(Alive) == 
        }
    }
    """
    var lexer5 = Lexer(missingComparison)
    var parser5 = Parser(tokens: try lexer5.scanTokens())
    
    #expect(throws: CompilerError.ParserError(message: "Expected a number, a '#' shortcut, a function call, or '('; got '}'.",
        token: Token(type: .rightBracket, lexeme: "}", line: 5))) {
        try parser5.parseAutomaton()
    }

    // Missing name of automata
    let incompleteInput: String = "automaton"
    var lexer6: Lexer = Lexer(incompleteInput)
    var parser6: Parser = Parser(tokens: try lexer6.scanTokens())
    
    #expect(throws: CompilerError.ParserError(message: "Name of the automata is missing",
        token: Token(type: .eof, lexeme: "", line: 1))) {
        try parser6.parseAutomaton()
    }
}
