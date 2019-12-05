import Dispatch

internal struct Queue<T> {
    private let syncQueue = DispatchQueue(label: "com.bintrail.queue", attributes: .concurrent)

    private var elements: [T] = []

    var count: Int {
        syncQueue.sync {
            elements.count
        }
    }

    var isEmpty: Bool {
        syncQueue.sync {
            elements.isEmpty
        }
    }

    mutating func enqueue(_ element: T) {
        syncQueue.sync(flags: .barrier) {
            elements.append(element)
        }
    }

    mutating func enqueue<U>(_ newElements: U) where U: Sequence, U.Element == T {
        syncQueue.sync(flags: .barrier) {
            elements += Array(newElements)
        }
    }

    mutating func dequeueAll() -> [T] {
        var result: [T] = []

        syncQueue.sync(flags: .barrier) {
            result = elements
            elements = []
        }

        return result
    }

    mutating func dequeue() -> T? {
        return dequeue(maxCount: 1).first
    }

    mutating func dequeue(maxCount: Int) -> [T] {
        var result: [T] = []

        syncQueue.sync(flags: .barrier) {
            while result.count < maxCount && !elements.isEmpty {
                result.append(elements.removeFirst())
            }
        }

        return result
    }

    var front: T? {
        syncQueue.sync {
            elements.first
        }
    }
}
