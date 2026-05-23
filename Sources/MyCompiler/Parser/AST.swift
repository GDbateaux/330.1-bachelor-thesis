struct Automaton {
    let name: String
    let world: World
    let rules: [Rule]
}

struct World {
    let states: [String]
    let neighborhood: Neighborhood
    let dimension: Int
}

struct Rule {
    let initialState: String
    let endState: String
    let condition: Expression?
    let probability: Double
}

struct Neighborhood {
    let type: NeighborhoodType
    let range: Int
}

enum NeighborhoodType {
    case Moore
    case VonNeumann
}

indirect enum Expression {
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
