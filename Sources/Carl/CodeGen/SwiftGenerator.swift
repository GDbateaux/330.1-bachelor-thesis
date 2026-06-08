import Foundation

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
    mutating func generate() throws -> String {
        generatedCode += "struct Simulation {\n"
        generatedCode += "    var grid: NDGrid\n"
        generatedCode += "    var history: [NDGrid] = []\n"
        generatedCode += "    var lookupNextState: [UInt64:Int]?\n\n"
        generatedCode += "    init(dimensions: [Int]) {\n"
        generatedCode += "        self.grid = NDGrid(dimensions: dimensions, neighborhoodType: \"\(neighborhoodType)\", range: \(neighborhoodRange), stateCount: \(states.count))\n"
        generatedCode += "        self.lookupNextState = buildLookupNextCell()\n"
        generatedCode += "    }\n\n"

        generateRules()
        generateStep()
        generateSimulate()
        generateDisplay()

        generatedCode += "}\n\n"

        try generateNDGrid()
        generateMain()
        return generatedCode
    }

    /// Generates the function responsible for computing the next state of a cell according to the automaton rules
    private mutating func generateRules() {
        generateBuildLookupNextCell()
        generateEvaluateNextState()
        generateNextCell()
        generateGetLookupKey()
    }

    private mutating func generateBuildLookupNextCell() {
        generatedCode += """
            private func buildLookupNextCell() -> [UInt64: Int]? {
                let keyElementsCount: Int = self.grid.numNeighbors + 1
                let stateCount: Int = 2
                let bitsPerState: Int = Int(ceil(log2(Double(stateCount))))
                
                let totalCombinations: Int = Int(pow(Double(stateCount), Double(keyElementsCount)))
                let numTotalBits: Int = bitsPerState * (keyElementsCount)

                if totalCombinations > 1000000 || numTotalBits > 64 {
                    return nil
                }

                var lookupNextState: [UInt64: Int] = [:]

                func rec(currentKey: UInt64, currentIndex: Int, pattern: [Int]) {
                    if currentIndex == keyElementsCount - 1 {
                        for state: Int in 0..<stateCount {
                            let nextPattern: [Int] = pattern + [state]
                            lookupNextState[currentKey | UInt64(state)] = evaluateNextState(pattern: nextPattern)
                        }
                        return
                    }

                    for state: Int in 0..<stateCount {
                        let nextKey: UInt64 = (currentKey | UInt64(state)) << bitsPerState
                        let nextPattern: [Int] = pattern + [state]
                        rec(currentKey: nextKey, currentIndex: currentIndex + 1, pattern: nextPattern)
                    }
                }
                rec(currentKey: 0, currentIndex: 0, pattern: [])
                return lookupNextState
            }\n\n
        """
    }

    private mutating func generateEvaluateNextState() {
        generatedCode += "    func evaluateNextState(pattern: [Int]) -> Int {\n"
        generatedCode += "        let currentState: Int = pattern[0]\n"
        generatedCode += "        let neighbors: [Int] = Array(pattern.dropFirst())\n\n"

        for rule: Rule in self.rules {
            guard let from: Int = stateMapping[rule.initialState] else {
                continue
            }
            guard let to: Int = stateMapping[rule.endState] else {
                continue
            }

            generatedCode += "        if currentState == \(from)"

            if let expr: Expression = rule.condition {
                generatedCode += " && \(generateLookupExpr(expr))"                
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

    private mutating func generateNextCell() {
        generatedCode += """
            func nextCell(grid: NDGrid, idx: Int) -> Int {
                if let lookup = lookupNextState {
                    if let key = getLookupKey(grid: grid, idx: idx) {
                        if let nextState = lookup[key] {
                            return nextState
                        }
                    }
                }

                let currentState: Int = grid.getCell(idx) ?? 0

        \(rulesSwiftCode())
                return currentState
            }\n\n
        """
    }

    private func rulesSwiftCode() -> String {
        var code: String = ""
        for rule: Rule in self.rules {
            guard let from: Int = stateMapping[rule.initialState] else {
                continue
            }
            guard let to: Int = stateMapping[rule.endState] else {
                continue
            }

            code += "        if currentState == \(from)"

            if let expr: Expression = rule.condition {
                code += " && \(generateExpr(expr))"                
            }
            
            if rule.probability < 1 {
                code += " && Double.random(in: 0...1) <= \(rule.probability)" 
            }
            code += " {\n"
            code += "            return \(to)\n"
            code += "        }\n"
        }
        return code
    }

    private mutating func generateGetLookupKey() {
        generatedCode += """
            func getLookupKey(grid: NDGrid, idx: Int) -> UInt64? {
                guard let currentState = grid.getCell(idx) else {
                    return nil
                }

                let neighbors: [Int] = grid.getNeighbors(idx: idx)
                if neighbors.count != grid.numNeighbors {
                    return nil
                }

                let stateCount: Int = \(states.count)
                let bitsPerState: Int = Int(ceil(log2(Double(stateCount))))
                var key: UInt64 = UInt64(currentState)

                for neighbor: Int in neighbors {
                    key = (key << bitsPerState) | UInt64(neighbor)
                }
                return key
            }\n\n
        """
    }

    private mutating func generatecomputeNeighborhoodKey() {
        generatedCode += """
            private func computeNeighborhoodKey(grid: NDGrid, idx: Int, currentState: Int) -> Int64 {
                let stateCount: Int = \(states.count)
                let bitsPerState: Int = Int(ceil(log2(Double(stateCount))))
                var neighborhoodKey: Int64 = Int64(currentState)
                
                for offset in grid.neighborsOffsets {
                    let neighborState = grid.getCell(idx + offset) ?? 0
                    neighborhoodKey = (neighborhoodKey << bitsPerState) | Int64(neighborState)
                }
                return neighborhoodKey
            }\n\n
        """
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

    /// Generate the expression code for the lookup table evaluation
    /// 
    /// - Parameter expr: The expression to be converted
    /// - Returns: The swift code of the expression
    private func generateLookupExpr(_ expr: Expression) -> String {
        var generatedExpr: String = ""
        
        switch expr {
            case Expression.binary(let left, let op, let right):
                generatedExpr += "(\(generateLookupExpr(left)) \(op.rawValue) \(generateLookupExpr(right)))"
            case Expression.number(let number):
                generatedExpr += String(number)
            case Expression.unary(let op, let right):
                generatedExpr += op.rawValue + " " + generateLookupExpr(right)
            case Expression.neighborShortcut(let state):
                if let stateNum = stateMapping[state] {
                    generatedExpr += "neighbors.filter({ $0 == \(stateNum) }).count"
                }
            case Expression.call(let functionName, let arguments):
                if functionName == "count_neighbors" && arguments.count == 1 {
                    if let stateNum = stateMapping[arguments[0]] {
                        generatedExpr += "neighbors.filter({ $0 == \(stateNum) }).count"
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

                    for i: Int in 0..<grid.totalCellsCount {
                        let newState: Int = nextCell(grid: previousGridState, idx: i)
                        self.grid.setCell(idx: i, stateNum: newState)
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

                    for i: Int in 0..<grid.totalCellsCount {
                        if i % width == 0 {
                            print(line)
                            line = ""
                        }
                        line += "\\(grid.getCell(i) ?? 0)"
                    }
                    print(line)
                    print(String(repeating: "-", count: width * 2))
                } else {
                    var allCells: [Int] = []
                    for i: Int in 0..<grid.totalCellsCount {
                        allCells.append(grid.getCell(i) ?? 0)
                    }
                    print("Grid data (linearised): \\(allCells)")
                }
            }\n\n
        """
    }

    /// Generate the NGrid struct used to represent an N-dimensional grid.
    private mutating func generateNDGrid() throws {
        let currentFileURL: URL = URL(fileURLWithPath: #filePath)
        let NDGridURL: URL = currentFileURL.deletingLastPathComponent().appendingPathComponent("NDGrid.swift")
        let sourceCode: String = try String(contentsOf: NDGridURL, encoding: .utf8)

        generatedCode += sourceCode
    }
    
    /// Generates the entry point of the program
    private mutating func generateMain() {
        generatedCode += """
        print("--- Start of \(name) simulation---")
        
        let dims: [Int] = \(Array(repeating: 20, count: dimension))
        var sim: Simulation = Simulation(dimensions: dims)
        
        if sim.grid.totalCellsCount >= 400 {
            sim.grid.setCell(idx: 200, stateNum: 1)
            sim.grid.setCell(idx: 201, stateNum: 1)
            sim.grid.setCell(idx: 202, stateNum: 1)
        }
        
        sim.simulate()\n
        """
    }
}
