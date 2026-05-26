import Testing
@testable import MyCompiler

@Test func testKeywords() throws {
    let input: String = "automaton world states neighborhood dimension rules when with prob or and"
    let expected: [Token] = [
        Token(type: .automaton, lexeme: "automaton", line: 1),
        Token(type: .world, lexeme: "world", line: 1),
        Token(type: .states, lexeme: "states", line: 1),
        Token(type: .neighborhood, lexeme: "neighborhood", line: 1),
        Token(type: .dimension, lexeme: "dimension", line: 1),
        Token(type: .rules, lexeme: "rules", line: 1),
        Token(type: .when, lexeme: "when", line: 1),
        Token(type: .with, lexeme: "with", line: 1),
        Token(type: .prob, lexeme: "prob", line: 1),
        Token(type: .or, lexeme: "or", line: 1),
        Token(type: .and, lexeme: "and", line: 1),
        Token(type: .eof, lexeme: "", line: 1)
    ]

    var lexer: Lexer = Lexer(input)
    let tokens: [Token] = try lexer.scanTokens()

    for (i, expToken) in expected.enumerated(){
        #expect(tokens[i] == expToken)
    }
}

@Test func testNumbers() throws {
    let input: String = "3 42.5 63456456.435345 45"
    let expected: [Token] = [
        Token(type: .integer, lexeme: "3", line: 1),
        Token(type: .float, lexeme: "42.5", line: 1),
        Token(type: .float, lexeme: "63456456.435345", line: 1),
        Token(type: .integer, lexeme: "45", line: 1),
        Token(type: .eof, lexeme: "", line: 1)
    ]

    var lexer: Lexer = Lexer(input)
    let tokens: [Token] = try lexer.scanTokens()

    for (i, expToken) in expected.enumerated(){
        #expect(tokens[i] == expToken)
    }
}

@Test func testIdentifiers() throws {
    let input: String = "Dead Alive Moore Test_4"
    let expected: [Token] = [
        Token(type: .identifier, lexeme: "Dead", line: 1),
        Token(type: .identifier, lexeme: "Alive", line: 1),
        Token(type: .identifier, lexeme: "Moore", line: 1),
        Token(type: .identifier, lexeme: "Test_4", line: 1),
        Token(type: .eof, lexeme: "", line: 1)
    ]

    var lexer: Lexer = Lexer(input)
    let tokens: [Token] = try lexer.scanTokens()

    for (i, expToken) in expected.enumerated(){
        #expect(tokens[i] == expToken)
    }
}

@Test func testDelimitersAndOperators() throws {
    let input: String = "{}(),#-+/*:->"
    let expected: [Token] = [
        Token(type: .leftBracket, lexeme: "{", line: 1),
        Token(type: .rightBracket, lexeme: "}", line: 1),
        Token(type: .leftParenthesis, lexeme: "(", line: 1),
        Token(type: .rightParenthesis, lexeme: ")", line: 1),
        Token(type: .comma, lexeme: ",", line: 1),
        Token(type: .hashtag, lexeme: "#", line: 1),
        Token(type: .minus, lexeme: "-", line: 1),
        Token(type: .plus, lexeme: "+", line: 1),
        Token(type: .slash, lexeme: "/", line: 1),
        Token(type: .star, lexeme: "*", line: 1),
        Token(type: .colon, lexeme: ":", line: 1),
        Token(type: .rightArrow, lexeme: "->", line: 1),
        Token(type: .eof, lexeme: "", line: 1)
    ]

    var lexer: Lexer = Lexer(input)
    let tokens: [Token] = try lexer.scanTokens()

    for (i, expToken) in expected.enumerated(){
        #expect(tokens[i] == expToken)
    }
}

@Test func testComparisons() throws {
    let input: String = "== != < <= > >="
    let expected: [Token] = [
        Token(type: .equalEqual, lexeme: "==", line: 1),
        Token(type: .notEqual, lexeme: "!=", line: 1),
        Token(type: .less, lexeme: "<", line: 1),
        Token(type: .lessEqual, lexeme: "<=", line: 1),
        Token(type: .greater, lexeme: ">", line: 1),
        Token(type: .greaterEqual, lexeme: ">=", line: 1),
        Token(type: .eof, lexeme: "", line: 1)
    ]

    var lexer: Lexer = Lexer(input)
    let tokens: [Token] = try lexer.scanTokens()

    for (i, expToken) in expected.enumerated(){
        #expect(tokens[i] == expToken)
    }
}

@Test func testLineCountingAndWhitespace() throws {
    let input: String = """
    automaton
    
      3.14 \t   {
    """

    let expected: [Token] = [
        .init(type: .automaton, lexeme: "automaton", line: 1),
        .init(type: .float, lexeme: "3.14", line: 3),
        .init(type: .leftBracket, lexeme: "{", line: 3),
        .init(type: .eof, lexeme: "", line: 3)
    ]
    
    var lexer = Lexer(input)
    let tokens = try lexer.scanTokens()
    
    for (i, expToken) in expected.enumerated(){
        #expect(tokens[i] == expToken)
    }
}

@Test func testLexerErrors() {
    var lexerSingleEqual: Lexer = Lexer("states = 4")
    #expect(throws: CompilerError.LexerError(message: "Unexpected \'=\' (only \'==\' is allowed)", line: 1)) {
        try lexerSingleEqual.scanTokens()
    }

    var lexerUnexpectedChar: Lexer = Lexer("$")
    #expect(throws: CompilerError.LexerError(message: "Unexpected character '$'", line: 1)) {
        try lexerUnexpectedChar.scanTokens()
    }

    var lexerUnexpectedExclamation: Lexer = Lexer("!")
    #expect(throws: CompilerError.LexerError(message: "Unexpected '!' (only '!=' is allowed)", line: 1)) {
        try lexerUnexpectedExclamation.scanTokens()
    }
}
