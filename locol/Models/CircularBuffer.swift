import Foundation

/// A fixed-capacity buffer that overwrites oldest elements when full.
/// Implementation based on Jared Sinclair's CircularBuffer.
public struct CircularBuffer<Element> {
    /// The underlying storage
    var buffer: [Element?]
    
    /// The index of the next element to be written
    private var writeIndex = 0
    
    /// The number of elements currently in the buffer
    private var _count = 0
    
    /// The total capacity of the buffer
    public let capacity: Int
    
    /// Creates a new circular buffer with the specified capacity
    public init(capacity: Int) {
        precondition(capacity > 0, "Capacity must be positive")
        self.capacity = capacity
        self.buffer = Array(repeating: nil, count: capacity)
    }
    
    /// The number of elements currently in the buffer
    public var count: Int {
        _count
    }
    
    /// Appends an element to the buffer, overwriting the oldest element if necessary
    public mutating func append(_ element: Element) {
        buffer[writeIndex] = element
        writeIndex = (writeIndex + 1) % capacity
        _count = Swift.min(_count + 1, capacity)
    }
    
    /// Returns the element at the specified position
    public subscript(index: Int) -> Element {
        get {
            precondition(index >= 0 && index < _count, "Index out of bounds")
            let bufferIndex = (writeIndex - _count + index + capacity) % capacity
            return buffer[bufferIndex]!
        }
    }
}

// MARK: - Collection Conformance
extension CircularBuffer: Collection {
    public var startIndex: Int { 0 }
    public var endIndex: Int { count }
    
    public func index(after i: Int) -> Int {
        i + 1
    }
}

// MARK: - Sequence Conformance
extension CircularBuffer: Sequence {
    public func makeIterator() -> AnyIterator<Element> {
        var index = 0
        return AnyIterator {
            guard index < self.count else { return nil }
            let element = self[index]
            index += 1
            return element
        }
    }
}

// MARK: - Additional Helpers
extension CircularBuffer {
    /// Returns the last element that satisfies the given predicate
    public func last(where predicate: (Element) -> Bool) -> Element? {
        for i in (0..<count).reversed() {
            let element = self[i]
            if predicate(element) {
                return element
            }
        }
        return nil
    }
    
    /// Returns the last element in the buffer
    public var last: Element? {
        guard count > 0 else { return nil }
        return self[count - 1]
    }
} 