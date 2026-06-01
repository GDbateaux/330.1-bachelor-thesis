struct SwiftGenerator {
    private let name: String

    private let states: [String]

    private let neighborhoodType: String

    private let neighborhoodRange: Int

    private let dimension: Int

    private let rules: [Rule]

    private var stateMapping: [String: Int]

    private var textResult: String = ""


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

    mutating func generate() -> String {
        textResult += "struct Simulation {\n"
        textResult += "    var grid: NDGrid\n"
        textResult += "    var history: [NDGrid] = []\n\n"
        textResult += "    init(dimensions: [Int]) {\n"
        textResult += "        self.grid = NDGrid(dimensions: dimensions, initialValue: 0, neighborhoodType: \"\(neighborhoodType)\", range: \(neighborhoodRange))\n"
        textResult += "    }\n\n"

        generateRule()
        generateStep()
        generateSimulate()
        generateDisplay()

        textResult += "}\n\n"

        generateNDGrid()
        generateMain()
        return textResult
    }

    mutating func generateRule() {
        textResult += "    func nextCell(grid: NDGrid, idx: Int) -> Int {\n"
        textResult += "        let currentState: Int = grid.cells[idx]\n"

        for rule: Rule in self.rules {
            guard let from: Int = stateMapping[rule.initialState] else {
                continue
            }
            guard let to: Int = stateMapping[rule.endState] else {
                continue
            }

            textResult += "        if currentState == \(from)"

            if let expr: Expression = rule.condition {
                textResult += " && \(generateExpr(expr))"                
            }
            
            if rule.probability < 1 {
                textResult += " && Double.random(in: 0...1) <= \(rule.probability)" 
            }
            textResult += " {\n"
            textResult += "            return \(to)\n"
            textResult += "        }\n"
        }
        textResult += "        return currentState\n"
        textResult += "    }\n\n"
    }

    func generateExpr(_ expr: Expression) -> String {
        var res: String = ""
        
        switch expr {
            case Expression.binary(let left, let op, let right):
                res += "(\(generateExpr(left)) \(op.rawValue) \(generateExpr(right)))"
            case Expression.number(let number):
                res += String(number)
            case Expression.unary(let op, let right):
                res += op.rawValue + " " + generateExpr(right)
            case Expression.neighborShortcut(let state):
                if let stateNum = stateMapping[state] {
                    res += "Double(grid.countNeighbors(idx: idx, stateType: \(stateNum)))"
                }
            case Expression.call(let functionName, let arguments):
                if functionName == "count_neighbors" && arguments.count == 1 {
                    if let stateNum = stateMapping[arguments[0]] {
                        res += "Double(grid.countNeighbors(idx: idx, stateType: \(stateNum)))"
                    }
                }
        }
        return res
    }

    mutating func generateStep() {
        textResult += """
                mutating func step() {
                    let previousGridState: NDGrid = self.grid

                    for i: Int in 0..<grid.cells.count {
                        let newState: Int = nextCell(grid: previousGridState, idx: i)
                        self.grid.cells[i] = newState
                    }
                }\n\n
            """
    }

    mutating func generateSimulate() {
        textResult += """
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

    mutating func generateDisplay() {
        textResult += """
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
    mutating func generateNDGrid() {
        textResult += """
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
                var actualneighbor: [Int] = centerCoords

                func rec(_ dim: Int) {
                    if dim == dimensions.count {
                        if actualneighbor != centerCoords{
                            result.append(index(actualneighbor))
                        }
                        return
                    }

                    for i: Int in -range...range {
                        if centerCoords[dim] + i >= 0 && centerCoords[dim] + i < dimensions[dim] {
                            actualneighbor[dim] = centerCoords[dim] + i
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
                var actualneighbor: [Int] = centerCoords

                func rec(_ dim: Int) {
                    if dim == dimensions.count {
                        if actualneighbor != centerCoords {
                            var distance: Int = 0

                            for i: Int in 0..<centerCoords.count {
                                distance += abs(centerCoords[i] - actualneighbor[i])
                            }

                            if distance <= range {
                                result.append(index(actualneighbor))
                            }
                        }
                        return
                    }

                    for i: Int in -range...range {
                        if centerCoords[dim] + i >= 0 && centerCoords[dim] + i < dimensions[dim] {
                            actualneighbor[dim] = centerCoords[dim] + i
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
    
    mutating func generateMain() {
        textResult += """
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
