struct SwiftGenerator {
    /// Name of the automaton
    private let name: String

    /// List of states
    private let states: [String]

    /// Neighborhood type (Moore or VonNeumann)
    private let neighborhoodType: String

    /// Neighborhood range
    private let neighborhoodRange: Int

    /// Space dimension
    private let dimension: Int

    /// List of rules for the automaton
    private let rules: [Rule]

    /// Dictionary mapping string state to int
    private var stateMapping: [String: Int]

    /// String result of the code generation
    private var generatedCode: String = ""

    /// Initializes a new SwiftGenerator with the specified AST.
    ///
    /// - Parameter AST: The source AST to be transformed to code.
    init(_ AST: Automaton) {
        self.name = AST.name

        let world: World = AST.world
        self.states = world.states
        self.neighborhoodType = world.neighborhood.type
        self.neighborhoodRange = world.neighborhood.range
        self.dimension = world.dimension

        self.rules = AST.rules

        stateMapping = Dictionary(uniqueKeysWithValues: zip(self.states, 0..<self.states.count))
    }

    /// Generate the final String containing the swift code
    /// 
    /// - Returns: A string containing the swift code
    mutating func generate() -> String {
        generatedCode += "struct Simulation {\n"
        generatedCode += "    var grid: NDGrid\n"
        generatedCode += "    var history: [NDGrid] = []\n\n"
        generatedCode += "    init(dimensions: [Int]) {\n"
        generatedCode += "        self.grid = NDGrid(dimensions: dimensions, initialValue: 0, neighborhoodType: \"\(neighborhoodType)\", range: \(neighborhoodRange))\n"
        generatedCode += "    }\n\n"

        generateRules()
        generateStep()
        generateSimulate()
        generateDisplay()

        generatedCode += "}\n\n"

        generateNDGrid()
        generateMain()
        return generatedCode
    }

    /// Generates the function responsible for computing the next state of a cell according to the automaton rules
    private mutating func generateRules() {
        generatedCode += "    func nextCell(grid: NDGrid, idx: Int) -> Int {\n"
        generatedCode += "        let currentState: Int = grid.cells[idx]\n"

        for rule: Rule in self.rules {
            guard let from: Int = stateMapping[rule.initialState] else {
                continue
            }
            guard let to: Int = stateMapping[rule.endState] else {
                continue
            }

            generatedCode += "        if currentState == \(from)"

            if let expr: Expression = rule.condition {
                generatedCode += " && \(generateExpr(expr))"                
            }
            
            if rule.probability < 1 {
                generatedCode += " && Double.random(in: 0...1) <= \(rule.probability)" 
            }
            generatedCode += " {\n"
            generatedCode += "            return \(to)\n"
            generatedCode += "        }\n"
        }
        generatedCode += "        return currentState\n"
        generatedCode += "    }\n\n"
    }

    /// Generate the expression code
    /// 
    /// - Parameter expr: The expression to be converted
    /// - Returns: The swift code of the expression
    private func generateExpr(_ expr: Expression) -> String {
        var generatedExpr: String = ""
        
        switch expr {
            case Expression.binary(let left, let op, let right):
                generatedExpr += "(\(generateExpr(left)) \(op.rawValue) \(generateExpr(right)))"
            case Expression.number(let number):
                generatedExpr += String(number)
            case Expression.unary(let op, let right):
                generatedExpr += op.rawValue + " " + generateExpr(right)
            case Expression.neighborShortcut(let state):
                if let stateNum = stateMapping[state] {
                    generatedExpr += "grid.countNeighbors(idx: idx, stateType: \(stateNum))"
                }
            case Expression.call(let functionName, let arguments):
                if functionName == "count_neighbors" && arguments.count == 1 {
                    if let stateNum = stateMapping[arguments[0]] {
                        generatedExpr += "grid.countNeighbors(idx: idx, stateType: \(stateNum))"
                    }
                }
        }
        return generatedExpr
    }

    /// Generate the step function, which updates the grid
    private mutating func generateStep() {
        generatedCode += """
                mutating func step() {
                    let previousGridState: NDGrid = self.grid

                    for i: Int in 0..<grid.cells.count {
                        let newState: Int = nextCell(grid: previousGridState, idx: i)
                        self.grid.cells[i] = newState
                    }
                }\n\n
            """
    }

    /// Generate the simulate function, which runs the automaton for a number of iteration
    private mutating func generateSimulate() {
        generatedCode += """
            mutating func simulate() {
                for i: Int in 0..<100 {
                    print("step \\(i)")
                    displayGrid()
                    history.append(grid)
                    step()
                }
            }\n\n
        """
    }

    /// Generate the displayGrid function that prints the grid state
    private mutating func generateDisplay() {
        generatedCode += """
            func displayGrid() {
                if grid.dimensions.count == 2 {
                    let width: Int = grid.dimensions[grid.dimensions.count - 1]
                    var line: String = ""

                    for i: Int in 0..<grid.cells.count {
                        if i % width == 0 {
                            print(line)
                            line = ""
                        }
                        line += "\\(grid.cells[i]) "
                    }
                    print(line)
                    print(String(repeating: "-", count: width * 2))
                } else {
                    print("Grid data : \\(grid.cells)")
                }
            }\n\n
        """
    }

    // # Adapted from Stack Overflow, response by @vacawama, accessed on 29.05.2026
    // # URL: https://stackoverflow.com/a/51448698
    /// Generate the NGrid struct used to represent an N-dimensional grid.
    private mutating func generateNDGrid() {
        generatedCode += """
        struct NDGrid {
            let dimensions: [Int]
            var cells: [Int]
            private let neighborhoodType: String
            private let range: Int

            init(dimensions: [Int], initialValue: Int = 0, neighborhoodType: String, range: Int) {
                self.dimensions = dimensions
                cells = Array(repeating: initialValue, count: dimensions.reduce(1, *))

                self.neighborhoodType = neighborhoodType
                self.range = range
            }

            func coordinates(linearIndex: Int) -> [Int] {
                guard linearIndex >= 0 && linearIndex < cells.count else {
                    fatalError("Linear index out of range")
                }

                var idx: Int = linearIndex
                var coords: [Int] = Array(repeating: 0, count: dimensions.count)

                for i: Int in (0..<dimensions.count).reversed() {
                    coords[i] = idx % dimensions[i]
                    idx = idx / dimensions[i]
                }
                return coords
            }

            func countNeighbors(idx: Int, stateType: Int) -> Int {
                var neighborsIdx: [Int] = []
                var res: Int = 0

                switch neighborhoodType {
                    case "Moore": neighborsIdx = getMooreNeighbors(idx)
                    default: neighborsIdx = getVonNeumannNeighbors(idx)
                }

                for neighborIdx: Int in neighborsIdx {
                    if cells[neighborIdx] == stateType {
                        res += 1
                    }
                }
                return res
            }

            private func getMooreNeighbors(_ idx: Int) ->[Int] {
                let centerCoords: [Int] = coordinates(linearIndex: idx)
                var result: [Int] = []
                var actualNeighbor: [Int] = centerCoords

                func rec(_ dim: Int) {
                    if dim == dimensions.count {
                        if actualNeighbor != centerCoords{
                            result.append(index(actualNeighbor))
                        }
                        return
                    }

                    for i: Int in -range...range {
                        if centerCoords[dim] + i >= 0 && centerCoords[dim] + i < dimensions[dim] {
                            actualNeighbor[dim] = centerCoords[dim] + i
                            rec(dim + 1)
                        }
                    }
                }
                rec(0)
                return result
            }

            private func getVonNeumannNeighbors(_ idx: Int) ->[Int] {
                let centerCoords: [Int] = coordinates(linearIndex: idx)
                var result: [Int] = []
                var actualNeighbor: [Int] = centerCoords

                func rec(_ dim: Int) {
                    if dim == dimensions.count {
                        if actualNeighbor != centerCoords {
                            var distance: Int = 0

                            for i: Int in 0..<centerCoords.count {
                                distance += abs(centerCoords[i] - actualNeighbor[i])
                            }

                            if distance <= range {
                                result.append(index(actualNeighbor))
                            }
                        }
                        return
                    }

                    for i: Int in -range...range {
                        if centerCoords[dim] + i >= 0 && centerCoords[dim] + i < dimensions[dim] {
                            actualNeighbor[dim] = centerCoords[dim] + i
                            rec(dim + 1)
                        }
                    }
                }
                rec(0)
                return result
            }

            private func index(_ indices: [Int]) -> Int {
                guard indices.count == dimensions.count else { fatalError("Wrong number of indices: got \\(indices.count), expected \\(dimensions.count)") }
                zip(dimensions, indices).forEach { dim, idx in
                    if idx < 0 || idx >= dim { fatalError("Index out of range") }
                }

                var idx: [Int] = indices
                var dims: [Int] = dimensions
                var product: Int = 1
                var total: Int = idx.removeLast()
                while !idx.isEmpty {
                    product *= dims.removeLast()
                    total += (idx.removeLast() * product)
                }

                return total
            }

            subscript(_ indices: [Int]) -> Int {
                get {
                    return cells[index(indices)]
                }
                set {
                    cells[index(indices)] = newValue
                }
            }
        }\n\n
        """
    }
    
    /// Generates the entry point of the program
    private mutating func generateMain() {
        generatedCode += """
        print("--- Start of \(name) simulation---")
        
        let dims: [Int] = \(Array(repeating: 20, count: dimension))
        var sim: Simulation = Simulation(dimensions: dims)
        
        if sim.grid.cells.count >= 400 {
            sim.grid.cells[200] = 1
            sim.grid.cells[201] = 1
            sim.grid.cells[202] = 1
        }
        
        sim.simulate()\n
        """
    }
}
