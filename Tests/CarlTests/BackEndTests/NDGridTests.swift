import Testing
import Foundation
@testable import Carl

@Test func testGridInitialization() {
    let grid1: NDGrid = NDGrid(dimensions: [10, 20], neighborhoodType: "Moore", range: 1, stateCount: 2)
    #expect(grid1.totalCellsCount == 10 * 20)
    #expect(grid1.numNeighbors == 8)

    let grid2: NDGrid = NDGrid(dimensions: [20, 30, 45], neighborhoodType: "VonNeumann", range: 2, stateCount: 2)
    #expect(grid2.totalCellsCount == 20 * 30 * 45)
    #expect(grid2.numNeighbors == 24)
}

@Test func testSetAndGetCell() {
    var grid: NDGrid = NDGrid(dimensions: [5, 5], neighborhoodType: "Moore", range: 1, stateCount: 4)

    grid.setCell(idx: 12, stateNum: 3)

    #expect(grid.getCell(11) == 0)
    #expect(grid.getCell(12) == 3)
    #expect(grid.getCell(25) == nil)
}

@Test func testNeighbors() {
    var grid: NDGrid = NDGrid(dimensions: [3, 3], neighborhoodType: "Moore", range: 1, stateCount: 2)
    grid.setCell(idx: 1, stateNum: 1)
    grid.setCell(idx: 3, stateNum: 1)

    var buffer: [Int] = Array(repeating: 0, count: grid.numNeighbors)
    let count: Int = grid.getNeighbors(idx: 2, neighborBuffer: &buffer)
    #expect(count == 3)
    #expect(buffer[0..<count] == [1, 0, 0])

    #expect(grid.countNeighbors(idx: 2, stateType: 0) == 2)
    #expect(grid.countNeighbors(idx: 2, stateType: 1) == 1) 
}
