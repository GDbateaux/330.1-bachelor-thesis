/// The representation of a cellular automaton
struct Automaton: Equatable {
    let name: String
    let world: World
    let rules: [Rule]
}

/// The description of the world being modeled by a cellular automaton.
struct World: Equatable {
    let states: [String]
    let neighborhood: Neighborhood
    let dimension: Int
}

/// A state transition that determines how and when a cell changes from one state to another.
struct Rule: Equatable {
    let initialState: String
    let endState: String
    let condition: Expression?
    let probability: Double
}

/// The definition of a cell's surrounding environment, specifying the shape and reach of its neighbors.
struct Neighborhood: Equatable {
    let type: String
    let range: Int
}

/// An Abstract Syntax Tree representing expressions within a rule.
indirect enum Expression: Equatable {
    case binary(Expression, BinaryOperator, Expression)
    case unary(UnaryOperator, Expression)
    case number(Double)
    case call(String, [String])
    case neighborShortcut(String)
}

/// A prefix operator applied to a single expression.
enum UnaryOperator {
    case minus
    case plus
}

/// An operator used to combine two expressions.
enum BinaryOperator {
    case or
    case and
    case minus
    case plus
    case times
    case divided
    case equalEqual
    case notEqual
    case less
    case lessEqual
    case greater
    case greaterEqual
}
