// ====================================================================================
// Inspired by "Crafting Interpreters" by Robert Nystrom (Chapter 6: Parsing Expressions)
// Original source: https://craftinginterpreters.com/parsing-expressions.html
// ====================================================================================
struct Parser {
    // The input tokens
    var tokens: [Token]

    // The current token being scanned
    private var current: Int = 0

    init(tokens: [Token]) {
        self.tokens = tokens
    }

    /// Parses the top-level cellular automaton definition block
    /// 
    /// - Returns: The automaton AST
    mutating func parseAutomaton() throws -> Automaton {
        _ = try consume(TokenType.automaton, "A programme must begin with the keyword 'automaton'.")
        let name: String = try consume(TokenType.identifier, "Name of the automata is missing").lexeme
        _ = try consume(TokenType.leftBracket, "A left bracket '{' is expected after the automata name.")
        
        let worldBlock: World = try parseWorld()
        let rulesBlock: [Rule] = try parseRules()

        _ = try consume(TokenType.rightBracket, "A right bracket '}' is expected at the end of the automata block.")
        return Automaton(name: name, world: worldBlock, rules: rulesBlock)
    }

    /// Parses the world block
    private mutating func parseWorld() throws -> World {
        _ = try consume(TokenType.world, "Expected keyword 'world'.")
        _ = try consume(TokenType.leftBracket, "Expected '{' to start the world block.")
        
        var states: [String] = []
        var neighborhood: Neighborhood = Neighborhood(type: "Moore", range: 1)
        var dimension:Int = 2

        while !isAtEnd() && tokens[current].type != TokenType.rightBracket {
            switch tokens[current].type {
                case TokenType.states: states = try parseStates()
                case TokenType.neighborhood: neighborhood = try parseNeighborhood()
                case TokenType.dimension: dimension = try parseDimension()
                default: throw CompilerError.parserError(message: "Expected 'states', 'neighborhood', 'dimension' inside world block; got '\(tokens[current].lexeme)'.", token: tokens[current])
            }
        }
        
        _ = try consume(TokenType.rightBracket, "Expected '}' to end the world block.")
        return World(states: states, neighborhood: neighborhood, dimension: dimension)
    }

    /// Parses the states declaration block inside the world configuration
    private mutating func parseStates() throws -> [String] {
        var states: [String] = []

        _ = try consume(TokenType.states, "Expected keyword 'states'.")
        _ = try consume(TokenType.leftBracket, "Expected '{' to start the states block.")
        let firstStateToken: Token = try consume(TokenType.identifier, "Expected at least one state identifier.")
        states.append(firstStateToken.lexeme)

        while !isAtEnd() && tokens[current].type != TokenType.rightBracket {
            if tokens[current].type == TokenType.identifier {
                throw CompilerError.parserError(
                    message: "Expected ',' between state identifiers (got '\(tokens[current].lexeme)').", 
                    token: tokens[current]
                )
            }
            _ = try consume(TokenType.comma, "Expected ',' or '}' in states list.")
            if tokens[current].type == TokenType.rightBracket { break }
            
            let state: String = try consume(TokenType.identifier, "Expected state identifier after ','.") .lexeme
            states.append(state)
        }
        _ = try consume(TokenType.rightBracket, "Expected '}' to end the states block.")
        return states
    }
    
    /// Parses the neighborhood statement
    private mutating func parseNeighborhood() throws -> Neighborhood {
        _ = try consume(TokenType.neighborhood, "Expected keyword 'neighborhood'.")
        _ = try consume(TokenType.colon, "Expected ':' after 'neighborhood'.")

        let neighborhoodType: String = try consume(TokenType.identifier, "Expected 'identifier' after 'neighborhood:'.").lexeme
        _ = try consume(TokenType.leftParenthesis, "Expected '(' before neighborhood range.")
        
        let rangeToken: Token = try consume(TokenType.integer, "Expected an integer for neighborhood range.")
        guard let range: Int = Int(rangeToken.lexeme) else {
            throw CompilerError.parserError(
                message: "Neighborhood range must be a valid integer.", 
                token: rangeToken
            )  
        }
        _ = try consume(TokenType.rightParenthesis, "Expected ')' after neighborhood range.")
        return Neighborhood(type: neighborhoodType, range: range)
    }
    
    /// Parses the dimension statement
    private mutating func parseDimension() throws -> Int {
        _ = try consume(TokenType.dimension, "Expected keyword 'dimension'.")
        _ = try consume(TokenType.colon, "Expected ':' after 'dimension'.")
        
        let dimensionToken: Token = try consume(TokenType.integer, "Expected an integer for dimension.")
        guard let dimension: Int = Int(dimensionToken.lexeme) else {
            throw CompilerError.parserError(
                message: "Dimension must be a valid integer.", 
                token: dimensionToken
            )  
        }
        return dimension
    }

    /// Parses the rules block
    private mutating func parseRules() throws -> [Rule] {
        _ = try consume(TokenType.rules, "Expected keyword 'rules'.")
        _ = try consume(TokenType.leftBracket, "Expected '{' to start the rules block.")
        
        var rules: [Rule] = []

        while !isAtEnd() && tokens[current].type != TokenType.rightBracket {
            let initialState: String = try consume(TokenType.identifier, "Expected a rule definition (e.g., 'state -> state') or '}'; got '\(tokens[current].lexeme)'.").lexeme
            _ = try consume(TokenType.rightArrow, "Expected '->' to follow the initial state.")
            let endState: String = try consume(TokenType.identifier, "Expected end state identifier after '->'").lexeme

            var condition: Expression? = nil
            if match(TokenType.when) {
                condition = try parseExpression()
            }

            var probability: Double = 1
            if match(TokenType.with) {
                _ = try consume(TokenType.prob, "Expected keyword 'prob' after 'with'.")
                probability = try parseProb()
            }
            rules.append(Rule(initialState: initialState, endState: endState, condition: condition, probability: probability))
        }
        
        _ = try consume(TokenType.rightBracket, "Expected '}' to end the rules block.")
        return rules
    }

    /// Parses an expression
    private mutating func parseExpression() throws -> Expression {
        return try parseOrExpr()
    }

    /// Parses the or expression
    private mutating func parseOrExpr() throws -> Expression {
        var expr: Expression = try parseAndExpr()
        
        while match(TokenType.or) {
            let right: Expression = try parseAndExpr()
            expr = Expression.binary(expr, BinaryOperator.or, right)
        }
        return expr
    }

    /// Parses the and expression
    private mutating func parseAndExpr() throws -> Expression {
        var expr: Expression = try parseEquality()
        
        while match(TokenType.and) {
            let right: Expression = try parseEquality()
            expr = Expression.binary(expr, BinaryOperator.and, right)
        }
        return expr
    }

    /// Parses the equality expression
    private mutating func parseEquality() throws -> Expression {
        var expr: Expression = try parseComparison()
        
        if match(TokenType.equalEqual, TokenType.notEqual) {
            let operatorToken: Token = tokens[current - 1]
            let right: Expression = try parseComparison()

            let op: BinaryOperator = operatorToken.type == TokenType.equalEqual ? BinaryOperator.equalEqual : BinaryOperator.notEqual
            expr = Expression.binary(expr, op, right)
        }
        return expr
    }

    /// Parses a comparison expression
    private mutating func parseComparison() throws -> Expression {
        var expr: Expression = try parseTerm()
        
        if match(TokenType.less, TokenType.lessEqual, TokenType.greater, TokenType.greaterEqual) {
            let operatorToken: Token = tokens[current - 1]
            let right: Expression = try parseTerm()
            
            let op: BinaryOperator = switch operatorToken.type {
                case TokenType.less: BinaryOperator.less
                case TokenType.lessEqual: BinaryOperator.lessEqual
                case TokenType.greater: BinaryOperator.greater
                case TokenType.greaterEqual: BinaryOperator.greaterEqual
                default: fatalError("Unreachable")
            }
            
            expr = Expression.binary(expr, op, right)
        }
        return expr
    }
    
    /// Parses a term expression
    private mutating func parseTerm() throws -> Expression {
        var expr: Expression = try parseFactor()
        
        while match(TokenType.minus, TokenType.plus) {
            let operatorToken: Token = tokens[current - 1]
            let op: BinaryOperator = operatorToken.type == TokenType.minus ? BinaryOperator.minus : BinaryOperator.plus

            let right: Expression = try parseFactor()
            expr = Expression.binary(expr, op, right)
        }
        return expr
    }

    /// Parses a factor expression
    private mutating func parseFactor() throws -> Expression {
        var expr: Expression = try parseUnary()
        
        while match(TokenType.star, TokenType.slash) {
            let operatorToken: Token = tokens[current - 1]
            let op: BinaryOperator = operatorToken.type == TokenType.star ? BinaryOperator.times : BinaryOperator.divided

            let right: Expression = try parseUnary()
            expr = Expression.binary(expr, op, right)
        }
        return expr
    }

    /// Parses an unary expression
    private mutating func parseUnary() throws -> Expression {
        if match(TokenType.minus, TokenType.plus) {
            let operatorToken: Token = tokens[current - 1]
            let op: UnaryOperator = operatorToken.type == TokenType.minus ? UnaryOperator.minus : UnaryOperator.plus

            let right: Expression = try parsePrimary()
            return Expression.unary(op, right)
        }
        return try parsePrimary()
    }

    /// Parses a primary expression
    private mutating func parsePrimary() throws -> Expression {
        if match(TokenType.integer) {
            let lastToken: Token = tokens[current-1]
            guard let number: Int = Int(lastToken.lexeme) else {
                throw CompilerError.parserError(
                    message: "Invalid number", 
                    token: lastToken
                )  
            }
            return Expression.number(number)
        }
        else if match(TokenType.leftParenthesis) {
            let expr: Expression = try parseExpression()
            _ = try consume(TokenType.rightParenthesis, "Expected ')' after expression.")
            return expr
        }
        else if match(TokenType.hashtag) {
            let stateToken: Token = try consume(TokenType.identifier, "Expected state identifier after '#'.")
            return Expression.neighborShortcut(stateToken.lexeme)
        }
        else if match(TokenType.identifier){
            let functionName: String = tokens[current-1].lexeme
            var parameters: [String] = []

            _ = try consume(TokenType.leftParenthesis, "Expected '(' after function name '\(functionName)'.")

            if (match(TokenType.identifier)) {
                parameters.append(tokens[current-1].lexeme)

                while (match(TokenType.comma)) {
                    let parameter: String = try consume(TokenType.identifier, "Expected an identifier after ','.").lexeme
                    parameters.append(parameter)
                }
            }
            _ = try consume(TokenType.rightParenthesis, "Expected ')' after function arguments.")
            return Expression.call(functionName, parameters)
        }
        throw CompilerError.parserError(
            message: "Expected an integer number, a '#' shortcut, a function call, or '('; got '\(tokens[current].lexeme)'.",
            token: tokens[current]
        )
    }

    /// Parses the probability value following a 'with prob'
    private mutating func parseProb() throws -> Double {
        let token: Token = tokens[current]

        if match(TokenType.integer, TokenType.float) {
            guard let probability: Double = Double(token.lexeme) else {
                throw CompilerError.parserError(
                    message: "Probability must be a valid number (integer or float).", 
                    token: token
                )  
            }
            return probability
        }

        throw CompilerError.parserError(
            message: "Expected a number (integer or float) for probability.", 
            token: token
        )
    }

    /// Checks if the current token matches any of the specified types, consuming it if a match is found.
    ///
    /// - Parameter tokenTypes: A variadic list of token types to compare against the current token.
    /// - Returns: 'true' if the current token matches one of the types; otherwise, 'false'.
    private mutating func match(_ tokenTypes: TokenType...) -> Bool {
        for tokenType in tokenTypes{
            if (check(tokenType)) {
                _ = advance()
                return true
            }
        } 
        return false
    }

    //// Validates if the current token is of the expected type without consuming it.
    ///
    /// - Parameter tokenType: The token type to look for.
    /// - Returns: 'true' if the current token matches the given type; otherwise, 'false'.
    private func check(_ tokenType: TokenType) -> Bool {
        !isAtEnd() && tokenType == tokens[current].type
    }

    /// Enforces that the current token is of the expected type, consuming it, or throws a syntax error.
    ///
    /// - Parameters:
    ///   - tokenType: The expected token type to be consumed.
    ///   - message: The error description to be thrown if the validation fails.
    /// - Returns: The validated and consumed 'Token'.
    /// - Throws: 'CompilerError.parserError' if the current token type does not match.
    private mutating func consume(_ tokenType: TokenType, _ message: String) throws -> Token {
        if !check(tokenType) {
            throw CompilerError.parserError(message: message, token: tokens[current])
        }
        return advance()
    }

    /// Consumes the current token and advances the internal stream pointer by one.
    ///
    /// - Returns: The `Token` that was current before advancing.
    private mutating func advance() -> Token {
        if (!isAtEnd()) {
            current += 1
        }
        return tokens[current - 1]
    }

    /// Checks if the parser has reached the end of the token stream.
    ///
    /// - Returns: 'true' if the current token type is 'eof'; otherwise, 'false'.
    private func isAtEnd() -> Bool {
        return tokens[current].type == TokenType.eof
    }
}
