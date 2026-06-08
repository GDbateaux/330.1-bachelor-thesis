import Foundation

// # Adapted from Stack Overflow, response by @vacawama, accessed on 29.05.2026
// # URL: https://stackoverflow.com/a/51448698
/// Represents a multi-dimensional grid managing cellular automata states
struct NDGrid {
    /// Configuration of offsets relative to a cell
    struct NeighborhoodOffset {
        let linear: Int
        let coordDelta: [Int]
    }

    /// The size of each spatial axis
    let dimensions: [Int]

    /// Total number of cells in the grid
    let totalCellsCount: Int

    /// Total count of neighbors found within the predefined range for a cell with max neighbors
    var numNeighbors: Int

    /// Bit-packed array containing the cell states
    private var cells: [UInt64]

    /// Number of bits to represent a single cell state
    private var bitsPerState: Int

    /// Maximum number of cell states packable inside one 64-bit integer
    private var numCellsPerInt: Int

    /// Type of neighborhood ("Moore" or "VonNeumann")
    private let neighborhoodType: String

    /// Neighborhood range
    private let range: Int

    /// Array containing all offsets for local neighbors.
    private var neighborsOffsets: [NeighborhoodOffset]

    /// Initializes a multi-dimensional grid using bit-packed integer storage.
    /// 
    /// - Parameters:
    ///   - dimensions: Size of each grid axis
    ///   - neighborhoodType: "Moore" or "VonNeumann"
    ///   - range: Distance of neighborhood
    ///   - stateCount: Total possible cell states.
    init(dimensions: [Int], neighborhoodType: String, range: Int, stateCount: Int) {
        self.dimensions = dimensions
        self.neighborhoodType = neighborhoodType
        self.range = range

        // Number of bits for a cell (8 states -> 3 bits)
        self.bitsPerState = Int(ceil(log2(Double(stateCount))))

        // Number of cells in one UInt64 (64 bits)
        self.numCellsPerInt = 64 / bitsPerState
        
        // Number of cells in a grid (width * height * ...)
        self.totalCellsCount = dimensions.reduce(1, *)
        
        // Length of the UInt64 array
        let allocationSize: Int = Int(ceil(Double(totalCellsCount) / Double(numCellsPerInt)))
        self.cells = Array(repeating: 0, count: allocationSize)

        self.neighborsOffsets = []
        self.numNeighbors = 0
        
        if neighborhoodType == "Moore" {
            self.neighborsOffsets = getMooreOffset()
        }
        else {
            self.neighborsOffsets = getVonNeumannOffset()
        }
        self.numNeighbors = neighborsOffsets.count
    }

    /// Sets the state value of a specific cell
    /// - Parameters:
    ///   - idx: Linear index of the target cell
    ///   - stateNum: Numeric value of the new state
    mutating func setCell(idx: Int, stateNum: Int) {
        let maxStates: Int = Int(pow(2.0, Double(bitsPerState)))
        
        if stateNum >= maxStates {
            fatalError("Invalid state: The state \(stateNum) exceeds the maximum allowed capacity for a \(bitsPerState)-bit cell configuration.")
        }

        let arrayIndex: Int = idx / numCellsPerInt
        let bitOffset: Int = (idx % numCellsPerInt) * bitsPerState

        // Mask (0b0...0...0111 if 3 bits)
        let baseMask: UInt64 = (1 << bitsPerState) - 1

        // clear
        cells[arrayIndex] = cells[arrayIndex] & ~(baseMask << bitOffset)
        // Replace with new value
        cells[arrayIndex] = cells[arrayIndex] | (UInt64(stateNum) << bitOffset)
    }

    /// Extracts the state value of a specific cell
    /// 
    /// - Parameter idx: Linear index of the cell
    /// - Returns: The cell state integer, or nil if the index is outside grid boundaries
    func getCell(_ idx: Int) -> Int? {
        let totalCellsCount: Int = dimensions.reduce(1, *)

        if idx < 0 || idx >= totalCellsCount {
            return nil
        }
        let arrayIndex: Int = idx / numCellsPerInt
        let bitOffset: Int = (idx % numCellsPerInt) * bitsPerState

        // Mask (0b0...0...0111 if 3 bits)
        let baseMask: UInt64 = (1 << bitsPerState) - 1

        let cellValue: UInt64 = (cells[arrayIndex] >> bitOffset) & baseMask
        return Int(cellValue)
    }

    /// Counts how many neighbors cells match a specific state
    /// 
    /// - Parameters:
    ///   - idx: Linear index of the reference cell
    ///   - stateType: The target state integer to match
    /// - Returns: The number of matching neighbors cells
    func countNeighbors(idx: Int, stateType: Int) -> Int {
        var res: Int = 0

        for offset: Int in getValidNeighborsOffsets(idx: idx) {
            let neighborIdx: Int = idx + offset
            
            if let type: Int = getCell(neighborIdx) {
                if type == stateType {
                    res += 1
                }
            }
        }
        return res
    }

    /// Collects the current state values of all valid surrounding neighbors
    /// 
    /// - Parameter idx: Linear index of the reference cell
    /// - Returns: An array containing the integer states of all neighbors
    func getNeighbors(idx: Int) -> [Int] {
        var result: [Int] = []

        for offset: Int in getValidNeighborsOffsets(idx: idx) {
            if let neighbor = getCell(idx + offset) {
                result.append(neighbor)
            }
        }
        return result
    }

    /// Get linear index offsets that fit inside the grid boundaries
    /// 
    /// - Parameter idx: Linear index of the reference cell
    /// - Returns: Array of linear offsets that do not cross edges
    private func getValidNeighborsOffsets(idx: Int)-> [Int] {
        let coords: [Int] = coordinates(linearIndex: idx)
        var res: [Int] = []
        var isValid: Bool = true

        for offset: NeighborhoodOffset in neighborsOffsets {
            for d: Int in 0..<dimensions.count {
                let targetCoord: Int = coords[d] + offset.coordDelta[d]

                if targetCoord < 0 || targetCoord >= dimensions[d] {
                    isValid = false
                }
            }

            if isValid {
                res.append(offset.linear)
            }
            isValid = true
        }
        return res
    }

    /// Generates offsets for a Moore neighborhood
    /// 
    /// - Returns: An array of NeighborhoodOffset configurations
    private func getMooreOffset() -> [NeighborhoodOffset] {
        var result: [NeighborhoodOffset] = []
        var actualOffset: Int = 0
        var offsetByDim: [Int] = Array(repeating: 0, count: dimensions.count)
        var multiplier: Int = 1

        for i: Int in (0..<dimensions.count).reversed() {
            offsetByDim[i] = multiplier
            multiplier *= dimensions[i]
        }

        func rec(_ dim: Int = 0, _ currentDelta: [Int] = Array(repeating: 0, count: dimensions.count)) {
            if dim == dimensions.count {
                if actualOffset != 0 {
                    result.append(NeighborhoodOffset(linear: actualOffset, coordDelta: currentDelta))
                }
                return
            }

            for i: Int in -range...range {
                actualOffset += i * offsetByDim[dim]

                var nextDelta: [Int] = currentDelta
                nextDelta[dim] = i

                rec(dim + 1, nextDelta)
                actualOffset -= i * offsetByDim[dim]
            }
        }
        rec()
        return result
    }

    /// Generates offsets for a Von Neumann neighborhood
    /// 
    /// - Returns: An array of NeighborhoodOffset configurations
    private func getVonNeumannOffset() -> [NeighborhoodOffset] {
        var result: [NeighborhoodOffset] = []
        var actualOffset: Int = 0
        var offsetByDim: [Int] = Array(repeating: 0, count: dimensions.count)
        var multiplier: Int = 1

        for i: Int in (0..<dimensions.count).reversed() {
            offsetByDim[i] = multiplier
            multiplier *= dimensions[i]
        }

        func rec(_ dim: Int = 0, _ distance: Int = 0, _ currentDelta: [Int] = Array(repeating: 0, count: dimensions.count)) {
            if distance > range { return }

            if dim == dimensions.count {
                if actualOffset != 0 {
                    if distance <= range {
                        result.append(NeighborhoodOffset(linear: actualOffset, coordDelta: currentDelta))
                    }
                }
                return
            }

            for i: Int in -range...range {
                actualOffset += i * offsetByDim[dim]
                var nextDelta: [Int] = currentDelta
                nextDelta[dim] = i
                rec(dim + 1, distance + abs(i), nextDelta)
                actualOffset -= i * offsetByDim[dim]
            }
        }
        rec()
        return result
    }

    /// Converts multi-dimensional coordinates into its linear array index
    /// 
    /// - Parameter indices: Array of coordinate across all grid dimensions
    /// - Returns: Linear array index integer
    private func index(_ indices: [Int]) -> Int {
        guard indices.count == dimensions.count else { 
            fatalError("Wrong number of indices: got \\(indices.count), expected \\(dimensions.count)") 
        }

        zip(dimensions, indices).forEach { dim, idx in
            if idx < 0 || idx >= dim { 
                fatalError("Index out of range") 
            }
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

    /// Converts a linear array index into its multi-dimensional coordinate components
    /// 
    /// - Parameter linearIndex: Linear array index integer
    /// - Returns:  An array containing coordinates for each specific axis
    private func coordinates(linearIndex: Int) -> [Int] {
        guard linearIndex >= 0 && linearIndex < totalCellsCount else {
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
}
