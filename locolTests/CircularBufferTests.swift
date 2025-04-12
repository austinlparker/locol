import XCTest
@testable import locol

final class CircularBufferTests: XCTestCase {
    
    func testInitialization() {
        let buffer = CircularBuffer<Int>(capacity: 5)
        XCTAssertEqual(buffer.capacity, 5)
        XCTAssertEqual(buffer.count, 0)
    }
    
    func testAppend() {
        var buffer = CircularBuffer<Int>(capacity: 3)
        buffer.append(1)
        XCTAssertEqual(buffer.count, 1)
        XCTAssertEqual(buffer[0], 1)
        
        buffer.append(2)
        XCTAssertEqual(buffer.count, 2)
        XCTAssertEqual(buffer[0], 1)
        XCTAssertEqual(buffer[1], 2)
        
        buffer.append(3)
        XCTAssertEqual(buffer.count, 3)
        XCTAssertEqual(buffer[0], 1)
        XCTAssertEqual(buffer[1], 2)
        XCTAssertEqual(buffer[2], 3)
    }
    
    func testCircularOverwrite() {
        var buffer = CircularBuffer<Int>(capacity: 3)
        buffer.append(1)
        buffer.append(2)
        buffer.append(3)
        
        // This should overwrite the oldest item (1)
        buffer.append(4)
        XCTAssertEqual(buffer.count, 3)
        XCTAssertEqual(buffer[0], 2)
        XCTAssertEqual(buffer[1], 3)
        XCTAssertEqual(buffer[2], 4)
        
        // This should overwrite the oldest item (2)
        buffer.append(5)
        XCTAssertEqual(buffer.count, 3)
        XCTAssertEqual(buffer[0], 3)
        XCTAssertEqual(buffer[1], 4)
        XCTAssertEqual(buffer[2], 5)
    }
    
    func testCollectionConformance() {
        var buffer = CircularBuffer<Int>(capacity: 5)
        buffer.append(1)
        buffer.append(2)
        buffer.append(3)
        
        let array = Array(buffer)
        XCTAssertEqual(array, [1, 2, 3])
        
        let sum = buffer.reduce(0, +)
        XCTAssertEqual(sum, 6)
        
        let containsTwo = buffer.contains(2)
        XCTAssertTrue(containsTwo)
    }
    
    func testLastWherePredicate() {
        var buffer = CircularBuffer<Int>(capacity: 5)
        buffer.append(1)
        buffer.append(2)
        buffer.append(3)
        buffer.append(4)
        buffer.append(5)
        
        let lastEven = buffer.last(where: { $0 % 2 == 0 })
        XCTAssertEqual(lastEven, 4)
        
        let lastGreaterThanFive = buffer.last(where: { $0 > 5 })
        XCTAssertNil(lastGreaterThanFive)
    }
    
    func testLastElement() {
        var buffer = CircularBuffer<Int>(capacity: 3)
        XCTAssertNil(buffer.last)
        
        buffer.append(1)
        XCTAssertEqual(buffer.last, 1)
        
        buffer.append(2)
        XCTAssertEqual(buffer.last, 2)
        
        buffer.append(3)
        XCTAssertEqual(buffer.last, 3)
        
        buffer.append(4)
        XCTAssertEqual(buffer.last, 4)
    }
}