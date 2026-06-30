import Foundation

struct SwiftGenerator {
    /// Name of the automaton
    private let name: String

    /// List of states
    private let states: [String]

    /// Neighborhood type (Moore, VonNeumann or Hexagonal)
    private let neighborhoodType: String

    /// Neighborhood range
    private let neighborhoodRange: Int

    /// Space dimension
    private let dimension: Int

    /// Optional grid length for each dimension
    private let gridLength: Int?

    /// Initial state probability of the grid
    private let initial: [String: Double]?

    /// List of rules for the automaton
    private let rules: [Rule]

    /// Dictionary mapping string state to int
    private var stateMapping: [String: Int]

    /// String result of the code generation
    private var generatedCode: String = ""

    /// Initializes a new SwiftGenerator with the specified AST.
    ///
    /// - Parameter AST: The source AST to be transformed to code.
    /// - Parameter gridLength: Optional grid length for each dimension.
    init(_ AST: Automaton, gridLength: Int? = nil) {
        self.name = AST.name

        let world: World = AST.world
        self.states = world.states
        self.neighborhoodType = world.neighborhood.type
        self.neighborhoodRange = world.neighborhood.range
        self.dimension = world.dimension

        self.gridLength = gridLength

        self.initial = AST.initial
        self.rules = AST.rules

        stateMapping = Dictionary(uniqueKeysWithValues: zip(self.states, 0..<self.states.count))
    }

    /// Generate the final String containing the swift code
    /// 
    /// - Returns: A string containing the swift code
    mutating func generate() throws -> String {
        generatedCode += "import Foundation\n"
        generatedCode += "import CRaylib\n\n"
        generatedCode += "struct Simulation {\n"
        generatedCode += "    var grid: NDGrid\n"
        generatedCode += "    var history: [NDGrid] = []\n"
        generatedCode += "    var stateNames: [String] = \(states)\n"
        generatedCode += "    let stateCount = \(states.count)\n"
        generatedCode += "    let bitsPerState: Int\n"
        generatedCode += "    var lookupNextState: [UInt64:Int]?\n\n"
        generatedCode += "    init(dimensions: [Int]) {\n"
        generatedCode += "        self.grid = NDGrid(dimensions: dimensions, neighborhoodType: \"\(neighborhoodType)\", range: \(neighborhoodRange), stateCount: \(states.count))\n"
        generatedCode += "        self.bitsPerState = Int(ceil(log2(Double(stateCount))))\n"
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

    /// Generates the function that pre-computes all state transitions into an optional lookup dictionary for fast evaluation
    private mutating func generateBuildLookupNextCell() {
        generatedCode += """
            private func buildLookupNextCell() -> [UInt64: Int]? {
                let keyElementsCount: Int = self.grid.numNeighbors + 1
                let stateCount: Int = \(states.count)
                let numTotalBits: Int = bitsPerState * keyElementsCount

                if numTotalBits > 64 {
                    return nil
                }

                let totalCombinations: Int = Int(pow(Double(stateCount), Double(keyElementsCount)))

                if totalCombinations > 1000000 {
                    return nil
                }

                var lookupNextState: [UInt64: Int] = [:]

                func rec(currentKey: UInt64, currentIndex: Int, pattern: [Int]) {
                    if currentIndex == keyElementsCount - 1 {
                        for state: Int in 0..<stateCount {
                            let nextPattern: [Int] = pattern + [state]
                            if let nextState = evaluateNextState(pattern: nextPattern) {
                                lookupNextState[currentKey | UInt64(state)] = nextState
                            }
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

    /// Generates the evaluateNextState function that determines the target state from a pattern using automaton rules
    private mutating func generateEvaluateNextState() {
        generatedCode += "    private func evaluateNextState(pattern: [Int]) -> Int? {\n"
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
                generatedCode += " {\n"
                generatedCode += "            return nil\n"
                generatedCode += "        }\n"
            }
            else {
                generatedCode += " {\n"
                generatedCode += "            return \(to)\n"
                generatedCode += "        }\n"
            }
        }
        generatedCode += "        return currentState\n"
        generatedCode += "    }\n\n"
    }

    /// Generates the nextCell function that computes the next state of a single cell, using the lookup table if possible
    private mutating func generateNextCell() {
        generatedCode += """
            private func nextCell(grid: NDGrid, idx: Int, neighborBuffer: inout [Int]) -> Int {
                if let lookup = lookupNextState {
                    if let key = getLookupKey(grid: grid, idx: idx, neighborBuffer: &neighborBuffer) {
                        if let nextState = lookup[key] {
                            return nextState
                        }
                    }
                }

                var stateCounts: [Int] = Array(repeating: 0, count: stateCount)
                let currentState: Int = grid.getCell(idx) ?? 0
                let neighborsCount: Int = grid.getNeighbors(idx: idx, neighborBuffer: &neighborBuffer)

                for i: Int in 0 ..< neighborsCount {
                    stateCounts[neighborBuffer[i]] += 1
                }
        \(rulesSwiftCode())
                return currentState
            }\n\n
        """
    }

    /// Generates the conditional code that applies rules sequentially at runtime (fallback when no lookup table is used)
    /// 
    /// - Returns: The swift code of the rules
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
                code += " && Double.random(in: 0..<1) <= \(rule.probability)" 
            }
            code += " {\n"
            code += "            return \(to)\n"
            code += "        }\n"
        }
        return code
    }

    /// Generates the getLookupKey function that builds a key from a cell and its neighbors for lookup table access
    private mutating func generateGetLookupKey() {
        generatedCode += """
            private func getLookupKey(grid: NDGrid, idx: Int, neighborBuffer: inout [Int]) -> UInt64? {
                guard let currentState = grid.getCell(idx) else {
                    return nil
                }

                let neighborsCount: Int = grid.getNeighbors(idx: idx, neighborBuffer: &neighborBuffer)
                if neighborsCount != grid.numNeighbors {
                    return nil
                }

                var key: UInt64 = UInt64(currentState)

                for i: Int in 0..<neighborsCount {
                    key = (key << bitsPerState) | UInt64(neighborBuffer[i])
                }
                return key
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
                    generatedExpr += "stateCounts[\(stateNum)]"
                }
            case Expression.call(let functionName, let arguments):
                if functionName == "count_neighbors" && arguments.count == 1 {
                    if let stateNum = stateMapping[arguments[0]] {
                        generatedExpr += "stateCounts[\(stateNum)]"
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

    /// Generate the step annd stepBack functions, which updates the grid
    private mutating func generateStep() {
        generatedCode += """
                mutating func step() {
                    let previousGridState: NDGrid = self.grid
                    var neighborBuffer: [Int] = [Int](repeating: 0, count: grid.numNeighbors)
                    
                    history.append(previousGridState)
                    if history.count > 100 {
                        history.removeFirst()
                    }

                    for i: Int in 0..<grid.totalCellsCount {
                        let newState: Int = nextCell(grid: previousGridState, idx: i, neighborBuffer: &neighborBuffer)
                        self.grid.setCell(idx: i, stateNum: newState)
                    }
                }

                mutating func stepBack() {
                    if history.count > 0 {
                        let previousGrid: NDGrid = history.removeLast()
                        grid = previousGrid
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
    
    /// Generate block for grid initialisation
    private mutating func generateInitial() {
        guard let initial: [String: Double] = initial else { 
            return 
        }

        if initial.isEmpty {
            return
        }
        
        let initialSorted: [(String, Double)] = initial.sorted{ $0.key < $1.key }
        generatedCode += """
        for i: Int in 0..<sim.grid.totalCellsCount {
            let r: Double = Double.random(in: 0..<1)\n

        """
        
        var probSum: Double = 0.0
        for (state, prob) in initialSorted {
            probSum += prob
            if prob == 0 { 
                continue 
            }

            let stateIdx: Int = stateMapping[state]!
            let prefix: String = probSum == prob ? "if" : "else if"
            generatedCode += """
                \(prefix) r < \(probSum) { 
                    sim.grid.setCell(idx: i, stateNum: \(stateIdx)) 
                }\n
            """
        }
        
        generatedCode += """
        }\n
        
        """
    }

    /// Generates the entry point of the program
    private mutating func generateMain() {
        generatedCode += "\n"

        if dimension > 3 {
            generatedCode += """
            let dims: [Int] = \(Array(repeating: gridLength ?? 20, count: dimension))
            var sim: Simulation = Simulation(dimensions: dims)
            """
            generateInitial()

            generatedCode += """
            print("Info: Rendering not available in \\(dims.count)D automaton.")
            sim.simulate()\n
            """
        }
        else if dimension == 3 {
            generatedCode += """
            let dims: [Int] = \(Array(repeating: gridLength ?? 20, count: dimension))
            var isRunning: Bool = true
            var sim: Simulation = Simulation(dimensions: dims)

            """
            generateInitial()
            
            generatedCode += """
            let gridW: Int = dims[0]
            let gridH: Int = dims[1]
            let gridD: Int = dims.count >= 3 ? dims[2] : 1 

            let screenWidth: Int32 = 800;
            let screenHeight: Int32 = screenWidth;

            let worldSize: Float = 40
            let cellSize: Float = worldSize / Float(max(gridW, max(gridH, gridD)))
            let layerCellSize: Float = Float(max(2, min(screenWidth / Int32(gridW), screenHeight / Int32(gridH))))

            let stateCount: Int = \(states.count)
            var colors: [Color] = []

            var showMenu: Bool = false
            var editionMode: Bool = false
            var editingLayer: Int = 0
            var selectedColorPicker: Int = -1

            for i: Int in 0..<stateCount {
                switch i {
                    case 0: colors.append(Color(r: 0, g: 0, b: 0, a: 0))
                    case 1: colors.append(Color(r: 255, g: 255, b: 255, a: 255))
                    default: colors.append(ColorFromHSV(Float(i - 2) * (360.0 / Float(stateCount - 2)), 0.8, 0.9))
                }
            }

            SetConfigFlags(UInt32(FLAG_WINDOW_RESIZABLE.rawValue))
            InitWindow(screenWidth, screenHeight, "\(name)")
            SetTargetFPS(30)
            var camera: Camera3D = Camera3D(
                position: Vector3(x: 100, y: 100, z: 100),
                target: Vector3(x: 0, y: 0, z: 0),
                up: Vector3(x: 0, y: 1, z: 0),
                fovy: 45,
                projection : Int32(CAMERA_PERSPECTIVE.rawValue)
            )

            let gridContentW: Float = Float(gridW) * layerCellSize
            let gridContentH: Float = Float(gridH) * layerCellSize
            var editCamera: Camera2D = Camera2D(
                offset: Vector2(x: Float(screenWidth) / 2, y: Float(screenHeight) / 2),
                target: Vector2(x: gridContentW / 2, y: gridContentH / 2),
                rotation: 0,
                zoom: 0.96
            )
            GuiSetIconScale(3)

            let cx: Float = Float(gridW) * cellSize / 2
            let cy: Float = Float(gridH) * cellSize / 2
            let cz: Float = Float(gridD) * cellSize / 2

            while !WindowShouldClose() {
                if !showMenu {
                    if IsKeyPressed(Int32(KEY_E.rawValue)) {
                        editionMode = !editionMode
                        isRunning = false
                    }

                    if editionMode {
                        if IsKeyPressed(Int32(KEY_UP.rawValue)) {
                            editingLayer = min(editingLayer + 1, gridD - 1)
                        }
                        if IsKeyPressed(Int32(KEY_DOWN.rawValue)) {
                            editingLayer = max(editingLayer - 1, 0)
                        }

                        if IsMouseButtonDown(Int32(MOUSE_BUTTON_LEFT.rawValue)) {
                            var delta: Vector2 = GetMouseDelta()
                            delta = Vector2Scale(delta, -1.0/editCamera.zoom)
                            editCamera.target = Vector2Add(editCamera.target, delta)
                        }

                        let wheel: Float = GetMouseWheelMove()
                        if wheel != 0 {
                            let mouseWorldPos: Vector2 = GetScreenToWorld2D(GetMousePosition(), editCamera)

                            editCamera.offset = GetMousePosition()
                            editCamera.target = mouseWorldPos

                            let scale: Float = 0.2 * wheel
                            editCamera.zoom = Clamp(expf(logf(editCamera.zoom)+scale), 0.125, 64.0)
                        }

                        if IsMouseButtonPressed(Int32(MOUSE_BUTTON_RIGHT.rawValue)) {
                            let mousePosition: Vector2 = GetScreenToWorld2D(GetMousePosition(), editCamera)

                            let cellX: Int = Int(floor(mousePosition.x / layerCellSize))
                            let cellY: Int = gridH - 1 - Int(floor(mousePosition.y / layerCellSize))

                            if cellX >= 0 && cellX < gridW && cellY >= 0 && cellY < gridH {
                                let i: Int = editingLayer * gridH * gridW + cellY * gridW + cellX
                                let current: Int = sim.grid.getCell(i) ?? 0
                                sim.grid.setCell(idx: i, stateNum: (current + 1) % stateCount)
                            }
                        }
                    }
                    else {
                        if IsMouseButtonDown(Int32(MOUSE_BUTTON_LEFT.rawValue)) {
                            UpdateCamera(&camera, Int32(CAMERA_THIRD_PERSON.rawValue));
                        }

                        let wheel: Float = GetMouseWheelMove()
                        if wheel != 0 {
                            let cameraPos: Vector3 = camera.position
                            let dist: Float = sqrt(cameraPos.x * cameraPos.x + cameraPos.y * cameraPos.y + cameraPos.z * cameraPos.z)
                            let newDist: Float = max(dist - wheel * 20, 1.0)
                            camera.position = Vector3Scale(cameraPos, newDist / dist)
                        }

                        if IsKeyPressed(Int32(KEY_SPACE.rawValue)) {
                            isRunning = !isRunning
                        }
                    }

                    if !isRunning && IsKeyPressed(Int32(KEY_RIGHT.rawValue)) {
                        sim.step()
                    }

                    if !isRunning && IsKeyPressed(Int32(KEY_LEFT.rawValue)) {
                        sim.stepBack()
                    }
                }

                BeginDrawing()
                    ClearBackground(Color(r: 20, g: 20, b: 20, a: 255))

                    if editionMode {
                        BeginMode2D(editCamera)
                            let baseZ: Int = editingLayer * gridW * gridH
                            for y: Int in 0..<gridH {
                                for x: Int in 0..<gridW {
                                    let i: Int = baseZ + y * gridW + x
                                    let state: Int = sim.grid.getCell(i) ?? 0
                                    let color: Color = colors[state]
                                    if color.a > 0 {
                                        DrawRectangle(Int32(Float(x) * layerCellSize), Int32(Float(gridH - 1 - y) * layerCellSize), Int32(layerCellSize), Int32(layerCellSize), color)
                                    }
                                }
                            }
                        EndMode2D()
                        DrawText("Layer: \\(editingLayer + 1)/\\(gridD)  (UP/DOWN)", 70, 15, 20, Color(r: 255, g: 255, b: 255, a: 255))
                    }
                    else {
                        BeginMode3D(camera)
                            for i: Int in 0..<sim.grid.totalCellsCount {
                                let state: Int = sim.grid.getCell(i) ?? 0
                                let color: Color = colors[state]
                                if color.a == 0 { 
                                    continue 
                                }

                                let coords: [Int] = sim.grid.coordinates(linearIndex: i)
                                let x: Int = coords[0]
                                let y: Int = coords[1]
                                let z: Int = coords[2]

                                DrawCube(Vector3(x: Float(x) * cellSize - cx, y: Float(y) * cellSize - cy, z: Float(z) * cellSize - cz), cellSize, cellSize, cellSize, color)
                            }
                        EndMode3D()
                    }

                    if showMenu {
                        let menuWidth: Float = Float(GetScreenWidth()) / 3
                        GuiPanel(Rectangle(x: 0, y: 0, width: menuWidth, height: Float(GetScreenHeight())), "MENU")

                        for i: Int in 0..<stateCount {
                            let row: Int32 = 30 + Int32(i) * 30
                            DrawRectangle(5, row, 20, 20, colors[i])

                            if GuiButton(Rectangle(x: 30, y: Float(row), width: menuWidth - 40, height: 20), sim.stateNames[i]) != 0 {
                                selectedColorPicker = selectedColorPicker == i ? -1 : i
                            }
                        }

                        if selectedColorPicker >= 0 {
                            let popupWidth: Float = 260
                            let popupHeight: Float = 230
                            let popupX: Float = (Float(GetScreenWidth()) - popupWidth) / 2
                            let popupY: Float = (Float(GetScreenHeight()) - popupHeight) / 2

                            DrawRectangle(0, 0, GetScreenWidth(), GetScreenHeight(), Color(r: 0, g: 0, b: 0, a: 60))
                            if GuiWindowBox(Rectangle(x: popupX, y: popupY, width: popupWidth, height: popupHeight), sim.stateNames[selectedColorPicker]) == 1 {
                                selectedColorPicker = -1
                            }
                            else {
                                GuiColorPicker(Rectangle(x: popupX + 10, y: popupY + 30, width: popupWidth - 40, height: popupHeight - 100), "", &colors[selectedColorPicker])
                                
                                var isVisible: Bool = colors[selectedColorPicker].a > 0
                                GuiCheckBox(Rectangle(x: popupX + 10, y: popupY + 170, width: 20, height: 20), "Visible", &isVisible)
                                colors[selectedColorPicker].a = isVisible ? 255 : 0
                            }
                        }
                        else{
                            if IsMouseButtonPressed(Int32(MOUSE_BUTTON_LEFT.rawValue)) && GetMouseX() > GetScreenWidth() / 3 {
                                selectedColorPicker = -1
                                showMenu = false
                            }
                        } 
                    }
                    else {
                        if GuiButton(Rectangle(x: 10, y: 10, width: 50, height: 50), GuiIconText(Int32(ICON_BURGER_MENU.rawValue), "")) != 0 {
                            showMenu = true
                            isRunning = false
                        }
                    }
                    DrawFPS(GetScreenWidth() - 110, 10)
                EndDrawing()

                if isRunning {
                    sim.step()
                }
            }
            CloseWindow()
            """
        }
        else if neighborhoodType == "Hexagonal" {
            // Hex grid math adapted from https://www.redblobgames.com/grids/hexagons/
            generatedCode += """
            let dims: [Int] = \(Array(repeating: gridLength ?? 200, count: dimension))
            var isRunning: Bool = true
            var sim: Simulation = Simulation(dimensions: dims)

            """
            generateInitial()

            generatedCode += """
            let screenWidth: Int32 = 800;
            let screenHeight: Int32 = screenWidth;

            let gridW: Int = dims.count >= 2 ? dims[1] : dims[0]
            let gridH: Int = dims.count >= 2 ? dims[0] : 1
            let hexSize: Float = max(20.0, min(Float(screenWidth / Int32(gridW)), Float(screenHeight / Int32(gridH))))
            let radius: Float = hexSize / sqrtf(3.0) // (2 / sqrtf(3.0)) * (hexSize / 2)

            let stateCount: Int = \(states.count)
            var colors: [Color] = []

            var showMenu: Bool = false
            var selectedColorPicker: Int = -1

            for i: Int in 0..<stateCount {
                switch i {
                    case 0: colors.append(Color(r: 0, g: 0, b: 0, a: 255))
                    case 1: colors.append(Color(r: 255, g: 255, b: 255, a: 255))
                    default: colors.append(ColorFromHSV(Float(i - 2) * (360.0 / Float(stateCount - 2)), 0.8, 0.9))
                }
            }

            // --- Hex helpers ---
            // Hex grid math adapted from https://www.redblobgames.com/grids/hexagons/
            func axialToCoord(_ q: Int, _ r: Int) -> (Int, Int) {
                let parity: Int = r & 1
                let col: Int = q + (r - parity) / 2
                let row: Int = r
                return (col, row)
            }

            func axialRound(_ qFloat: Float, _ rFloat: Float) -> (Int, Int) {
                let sFloat: Float = -qFloat - rFloat
                var q: Float = round(qFloat)
                var r: Float = round(rFloat)
                let s: Float = round(sFloat)

                let qDiff: Float = abs(q - qFloat)
                let rDiff: Float = abs(r - rFloat)
                let sdiff: Float = abs(s - sFloat)

                if qDiff > rDiff && qDiff > sdiff {
                    q = -r-s
                }
                else if rDiff > sdiff {
                    r = -q-s
                }
                return (Int(q), Int(r))
            }

            func pixelToHexCoord(x: Float, y: Float) -> (Int, Int) {
                let x: Float = x / radius
                let y: Float = y / radius

                let q: Float = (sqrt(3.0) / 3 * x  - 1.0 / 3.0 * y)
                let r: Float = (2.0 / 3.0 * y)
                let (roundQ, roundR) = axialRound(q, r)
                return axialToCoord(roundQ, roundR)
            }

            // --- Display ---
            SetConfigFlags(UInt32(FLAG_WINDOW_RESIZABLE.rawValue))
            InitWindow(screenWidth, screenHeight, "\(name)")
            SetTargetFPS(30)
            var camera: Camera2D = Camera2D(
                offset: Vector2(x: 0, y: 0),
                target: Vector2(x: 0, y: 0),
                rotation: 0,
                zoom: 1.0
            )
            GuiSetIconScale(3)

            while !WindowShouldClose() {
                if !showMenu {
                    if IsMouseButtonDown(Int32(MOUSE_BUTTON_LEFT.rawValue)) {
                        var delta: Vector2 = GetMouseDelta()
                        delta = Vector2Scale(delta, -1.0/camera.zoom)
                        camera.target = Vector2Add(camera.target, delta)
                    }

                    let wheel: Float = GetMouseWheelMove()
                    if wheel != 0 {
                        let mouseWorldPos: Vector2 = GetScreenToWorld2D(GetMousePosition(), camera)

                        camera.offset = GetMousePosition()
                        camera.target = mouseWorldPos

                        let scale: Float = 0.2 * wheel
                        camera.zoom = Clamp(expf(logf(camera.zoom)+scale), 0.125, 64.0)
                    }

                    if IsMouseButtonPressed(Int32(MOUSE_BUTTON_RIGHT.rawValue)) {
                        let mousePosition: Vector2 = GetScreenToWorld2D(GetMousePosition(), camera)
                        let (hexX, hexY) = pixelToHexCoord(x: mousePosition.x, y: mousePosition.y)

                        if hexX >= 0 && hexX < gridW && hexY >= 0 && hexY < gridH {
                            let i: Int = hexY * gridW + hexX
                            let current: Int = sim.grid.getCell(i) ?? 0
                            sim.grid.setCell(idx: i, stateNum: (current + 1) % stateCount)
                        }
                    }

                    if IsKeyPressed(Int32(KEY_SPACE.rawValue)) {
                        isRunning = !isRunning
                    }

                    if !isRunning && IsKeyPressed(Int32(KEY_RIGHT.rawValue)) {
                        sim.step()
                    }

                    if !isRunning && IsKeyPressed(Int32(KEY_LEFT.rawValue)) {
                        sim.stepBack()
                    }
                }

                BeginDrawing()
                    ClearBackground(Color(r: 20, g: 20, b: 20, a: 255))
                    DrawFPS(GetScreenWidth() - 110, 10)

                    BeginMode2D(camera)
                        let width: Int = sim.grid.dimensions[sim.grid.dimensions.count - 1]
                        var x: Int = 0
                        var y: Int = 0
                        for i: Int in 0..<sim.grid.totalCellsCount {
                            let state: Int = sim.grid.getCell(i) ?? 0
                            let color: Color = colors[state]

                            if y % 2 == 0 {
                                DrawPoly(Vector2(x: Float(x) * hexSize, y: Float(y) * 1.5 * radius), 6, radius, 30, color)
                            }
                            else {
                                DrawPoly(Vector2(x: Float(x) * hexSize + hexSize / 2, y: Float(y) * 1.5 * radius), 6, radius, 30, color)
                            }

                            x += 1
                            if x % width == 0 && i != 0 {
                                y += 1
                                x = 0
                            }
                        }
                    EndMode2D()

                    if showMenu {
                        let menuWidth: Float = Float(GetScreenWidth()) / 3
                        GuiPanel(Rectangle(x: 0, y: 0, width: menuWidth, height: Float(GetScreenHeight())), "MENU")

                        for i: Int in 0..<stateCount {
                            let row: Int32 = 30 + Int32(i) * 30
                            DrawRectangle(5, row, 20, 20, colors[i])

                            if GuiButton(Rectangle(x: 30, y: Float(row), width: menuWidth - 40, height: 20), sim.stateNames[i]) != 0 {
                                selectedColorPicker = selectedColorPicker == i ? -1 : i
                            }
                        }

                        if selectedColorPicker >= 0 {
                            let popupWidth: Float = 260
                            let popupHeight: Float = 230
                            let popupX: Float = (Float(GetScreenWidth()) - popupWidth) / 2
                            let popupY: Float = (Float(GetScreenHeight()) - popupHeight) / 2

                            DrawRectangle(0, 0, GetScreenWidth(), GetScreenHeight(), Color(r: 0, g: 0, b: 0, a: 60))
                            if GuiWindowBox(Rectangle(x: popupX, y: popupY, width: popupWidth, height: popupHeight), sim.stateNames[selectedColorPicker]) == 1 {
                                selectedColorPicker = -1
                            }
                            else {
                                GuiColorPicker(Rectangle(x: popupX + 10, y: popupY + 30, width: popupWidth - 40, height: popupHeight - 100), "", &colors[selectedColorPicker])
                                
                                var alphaVal: Float = Float(colors[selectedColorPicker].a) / 255.0
                                GuiColorBarAlpha(Rectangle(x: popupX + 10, y: popupY + 170, width: popupWidth - 40, height: 20), "", &alphaVal)
                                colors[selectedColorPicker].a = UInt8(alphaVal * 255.0)
                            }
                        }
                        else {
                            if IsMouseButtonPressed(Int32(MOUSE_BUTTON_LEFT.rawValue)) && GetMouseX() > GetScreenWidth() / 3 {
                                selectedColorPicker = -1
                                showMenu = false
                                isRunning = true
                            }
                        }
                    }
                    else {
                        if GuiButton(Rectangle(x: 10, y: 10, width: 50, height: 50), GuiIconText(Int32(ICON_BURGER_MENU.rawValue), "")) != 0 {
                            showMenu = true
                            isRunning = false
                        }
                    }
                    DrawFPS(GetScreenWidth() - 110, 10)
                EndDrawing()

                if isRunning {
                    sim.step()
                }
            }
            CloseWindow()\n
            """
        }
        else {
            // Inspired by "Raylib examples"
            // Original source: https://www.raylib.com/examples.html
            generatedCode += """
            let dims: [Int] = \(Array(repeating: gridLength ?? 200, count: dimension))
            var isRunning: Bool = true
            var sim: Simulation = Simulation(dimensions: dims)

            """
            generateInitial()
            
            generatedCode += """
            let screenWidth: Int32 = 800;
            let screenHeight: Int32 = screenWidth;

            let gridW: Int = dims.count >= 2 ? dims[1] : dims[0]
            let gridH: Int = dims.count >= 2 ? dims[0] : 1
            let cellSize: Int32 = max(2, min(screenWidth / Int32(gridW), screenHeight / Int32(gridH)))

            let stateCount: Int = \(states.count)
            var colors: [Color] = []

            var showMenu: Bool = false
            var selectedColorPicker: Int = -1

            for i: Int in 0..<stateCount {
                switch i {
                    case 0: colors.append(Color(r: 0, g: 0, b: 0, a: 255))
                    case 1: colors.append(Color(r: 255, g: 255, b: 255, a: 255))
                    default: colors.append(ColorFromHSV(Float(i - 2) * (360.0 / Float(stateCount - 2)), 0.8, 0.9))
                }
            }

            SetConfigFlags(UInt32(FLAG_WINDOW_RESIZABLE.rawValue))
            InitWindow(screenWidth, screenHeight, "\(name)")
            SetTargetFPS(60)
            var camera: Camera2D = Camera2D(
                offset: Vector2(x: 0, y: 0),
                target: Vector2(x: 0, y: 0),
                rotation: 0,
                zoom: 1.0
            )
            GuiSetIconScale(3)

            while !WindowShouldClose() {
                if !showMenu {
                    if IsMouseButtonDown(Int32(MOUSE_BUTTON_LEFT.rawValue)) {
                        var delta: Vector2 = GetMouseDelta()
                        delta = Vector2Scale(delta, -1.0/camera.zoom)
                        camera.target = Vector2Add(camera.target, delta)
                    }

                    let wheel: Float = GetMouseWheelMove()
                    if wheel != 0 {
                        let mouseWorldPos: Vector2 = GetScreenToWorld2D(GetMousePosition(), camera)

                        camera.offset = GetMousePosition()
                        camera.target = mouseWorldPos

                        let scale: Float = 0.2 * wheel
                        camera.zoom = Clamp(expf(logf(camera.zoom)+scale), 0.125, 64.0)
                    }

                    if IsMouseButtonPressed(Int32(MOUSE_BUTTON_RIGHT.rawValue)) {
                        let mousePosition: Vector2 = GetScreenToWorld2D(GetMousePosition(), camera)

                        let cellX: Int = Int(floor(mousePosition.x / Float(cellSize)))
                        let cellY: Int = Int(floor(mousePosition.y / Float(cellSize)))

                        if cellX >= 0 && cellX < gridW && cellY >= 0 && cellY < gridH {
                            let i: Int = cellY * gridW + cellX
                            let current: Int = sim.grid.getCell(i) ?? 0
                            sim.grid.setCell(idx: i, stateNum: (current + 1) % stateCount)
                        }
                    }

                    if IsKeyPressed(Int32(KEY_SPACE.rawValue)) {
                        isRunning = !isRunning
                    }

                    if !isRunning && IsKeyPressed(Int32(KEY_RIGHT.rawValue)) {
                        sim.step()
                    }

                    if !isRunning && IsKeyPressed(Int32(KEY_LEFT.rawValue)) {
                        sim.stepBack()
                    }
                }

                BeginDrawing()
                    ClearBackground(Color(r: 20, g: 20, b: 20, a: 255))

                    BeginMode2D(camera)
                        let width: Int = sim.grid.dimensions[sim.grid.dimensions.count - 1]
                        var x: Int = 0
                        var y: Int = 0
                        for i: Int in 0..<sim.grid.totalCellsCount {
                            let state: Int = sim.grid.getCell(i) ?? 0
                            let color: Color = colors[state]
                            DrawRectangle(Int32(x)*cellSize, Int32(y)*cellSize, cellSize, cellSize, color)
                            x += 1
                            if x % width == 0 && i != 0 {
                                y += 1
                                x = 0
                            }
                        }
                    EndMode2D()

                    if showMenu {
                        let menuWidth: Float = Float(GetScreenWidth()) / 3
                        GuiPanel(Rectangle(x: 0, y: 0, width: menuWidth, height: Float(GetScreenHeight())), "MENU")

                        for i: Int in 0..<stateCount {
                            let row: Int32 = 30 + Int32(i) * 30
                            DrawRectangle(5, row, 20, 20, colors[i])

                            if GuiButton(Rectangle(x: 30, y: Float(row), width: menuWidth - 40, height: 20), sim.stateNames[i]) != 0 {
                                selectedColorPicker = selectedColorPicker == i ? -1 : i
                            }
                        }

                        if selectedColorPicker >= 0 {
                            let popupWidth: Float = 260
                            let popupHeight: Float = 230
                            let popupX: Float = (Float(GetScreenWidth()) - popupWidth) / 2
                            let popupY: Float = (Float(GetScreenHeight()) - popupHeight) / 2

                            DrawRectangle(0, 0, GetScreenWidth(), GetScreenHeight(), Color(r: 0, g: 0, b: 0, a: 60))
                            if GuiWindowBox(Rectangle(x: popupX, y: popupY, width: popupWidth, height: popupHeight), sim.stateNames[selectedColorPicker]) == 1 {
                                selectedColorPicker = -1
                            }
                            else {
                                GuiColorPicker(Rectangle(x: popupX + 10, y: popupY + 30, width: popupWidth - 40, height: popupHeight - 100), "", &colors[selectedColorPicker])
                                
                                var alphaVal: Float = Float(colors[selectedColorPicker].a) / 255.0
                                GuiColorBarAlpha(Rectangle(x: popupX + 10, y: popupY + 170, width: popupWidth - 40, height: 20), "", &alphaVal)
                                colors[selectedColorPicker].a = UInt8(alphaVal * 255.0)
                            }
                        }
                        else {
                            if IsMouseButtonPressed(Int32(MOUSE_BUTTON_LEFT.rawValue)) && GetMouseX() > GetScreenWidth() / 3 {
                                selectedColorPicker = -1
                                showMenu = false
                                isRunning = true
                            }
                        }
                    }
                    else {
                        if GuiButton(Rectangle(x: 10, y: 10, width: 50, height: 50), GuiIconText(Int32(ICON_BURGER_MENU.rawValue), "")) != 0 {
                            showMenu = true
                            isRunning = false
                        }
                    }
                    DrawFPS(GetScreenWidth() - 110, 10)
                EndDrawing()

                if isRunning {
                    sim.step()
                }
            }
            CloseWindow()\n
            """
        }

    }
}
