struct Automaton: Equatable {
    let name: String
    let world: World
    let rules: [Rule]
}

struct World: Equatable {
    let states: [String]
    let neighborhood: Neighborhood
    let dimension: Int
}

struct Rule: Equatable {
    let initialState: String
    let endState: String
    let condition: Expression?
    let probability: Double
}

struct Neighborhood: Equatable {
    let type: String
    let range: Int
}

indirect enum Expression: Equatable {
    case binary(Expression, BinaryOperator, Expression)
    case unary(UnaryOperator, Expression)
    case number(Double)
    case call(String, [String])
    case neighborShortcut(String)
}

enum UnaryOperator {
    case minus
    case plus
}

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
