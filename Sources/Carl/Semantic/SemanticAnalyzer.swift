struct SemanticAnalyzer {
    /// The input AST automaton
    let AST: Automaton

    /// Represents the types supported by the rule expressions.
    enum ExpressionType {
        case number
        case boolean
    }

    /// Entry point for the semantic analysis phase.
    func verifySemantic() throws {
        try verifyWorld()
        try verifyRules()
    }

    /// Validates the world block.
    private func verifyWorld() throws {
        try verifyNeighborhood()
        try verifyDimension()
    }

    /// Validates the neighborhood type and range parameters.
    private func verifyNeighborhood() throws {
        let neighborhoodStr: String = AST.world.neighborhood.type
        let range: Int = AST.world.neighborhood.range

        if neighborhoodStr != "VonNeumann" && neighborhoodStr != "Moore" {
            throw CompilerError.semanticError(message: "Unknown neighborhood type '\(neighborhoodStr)'. Expected 'Moore' or 'VonNeumann'.")
        }

        if range <= 0 {
            throw CompilerError.semanticError(message: "Neighborhood range must be greater than 0 (got \(range)).")
        }
    }

    /// Validates the spatial dimensions of the cellular automaton grid.
    private func verifyDimension() throws {
        let dimension: Int = AST.world.dimension
        
        if dimension <= 0 {
            throw CompilerError.semanticError(message: "Dimension must be greater than 0 (got \(dimension)).")
        }
    }

    /// Validates rules.
    private func verifyRules() throws{
        let states: [String] = AST.world.states
        let rules: [Rule] = AST.rules

        for rule: Rule in rules {
            if !states.contains(rule.initialState) {
                throw CompilerError.semanticError(message: "State '\(rule.initialState)' used in rules is not declared in the world states.")
            }

            if !states.contains(rule.endState) {
                throw CompilerError.semanticError(message: "Target state '\(rule.endState)' used in rules is not declared in the world states.")
            }

            if rule.probability < 0.0 || rule.probability > 1.0 {
                throw CompilerError.semanticError(message: "Probability for rule '\(rule.initialState) -> \(rule.endState)' must be between 0.0 and 1.0 (got \(rule.probability)).")
            }

            if let condition: Expression = rule.condition {
                if try verifyExpression(condition) != ExpressionType.boolean {
                    throw CompilerError.semanticError(message: "The 'when' condition in rule '\(rule.initialState) -> \(rule.endState)' must evaluate to a boolean, but it evaluates to a number.")
                }
            }
        }
    }

    /// Traverses and verify expression
    /// - Parameter expr: The expression node to validate.
    /// - Returns: The ExpressionType produced by the expression.
    private func verifyExpression(_ expr: Expression) throws -> ExpressionType {
        let states: [String] = AST.world.states

        switch expr {
            case .binary(let left, let op, let right):
                let leftType: ExpressionType = try verifyExpression(left)
                let rightType: ExpressionType = try verifyExpression(right)
                
                switch op {
                    case .minus, .plus, .times, .divided:
                        if leftType != ExpressionType.number || rightType != ExpressionType.number {
                            throw CompilerError.semanticError(message: "Arithmetic operator '\(op)' expects numeric operands.")
                        }
                        return ExpressionType.number
                    case .or, .and:
                        if leftType != ExpressionType.boolean || rightType != ExpressionType.boolean {
                            throw CompilerError.semanticError(message: "Logical operator '\(op)' expects boolean operands.")
                        }
                        return ExpressionType.boolean
                    case .equalEqual, .notEqual:
                        if leftType != rightType {
                            throw CompilerError.semanticError(message: "Cannot compare different types with '\(op)'.")
                        }
                        return ExpressionType.boolean
                    case .less, .lessEqual, .greater, .greaterEqual:
                        if leftType != ExpressionType.number || rightType != ExpressionType.number {
                            throw CompilerError.semanticError(message: "Comparison operator '\(op)' expects numeric operands.")
                        }
                        return ExpressionType.boolean
                }
            case .unary(let op, let expr):
                if try verifyExpression(expr) != ExpressionType.number {
                    throw CompilerError.semanticError(message: "Unary operator '\(op)' can only be applied to numbers.")
                }
                return ExpressionType.number
            case .number(_): 
                return ExpressionType.number
            case .call(let functionName, let parameters):
                if functionName == "count_neighbors" {
                    if parameters.count != 1 {
                        throw CompilerError.semanticError(message: "Function 'count_neighbors' expects exactly 1 argument.")
                    }
                    
                    let firstParam: String = parameters[0]
                    if !states.contains(firstParam) {
                        throw CompilerError.semanticError(message: "Argument '\(firstParam)' in 'count_neighbors' is not a valid declared state.")
                    }
                    return ExpressionType.number
                } else {
                    throw CompilerError.semanticError(message: "Unknown function call '\(functionName)'.")
                }
            case .neighborShortcut(let stateName):
                if !states.contains(stateName) {
                    throw CompilerError.semanticError(message: "Neighbor shortcut '#\(stateName)' references an unknown state.")
                }
                return ExpressionType.number
        }
    }
}
