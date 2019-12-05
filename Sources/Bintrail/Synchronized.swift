import Foundation
import Dispatch

@propertyWrapper
internal struct Synchronized<Value> {
    let dispatchQueue = DispatchQueue(label: "com.bintrail.sync", attributes: .concurrent)

    private var value: Value

    var wrappedValue: Value {
        get {
            return dispatchQueue.sync {
                value
            }
        }
        set {
            dispatchQueue.sync(flags: .barrier) {
                value = newValue
            }
        }
    }

    init(wrappedValue: Value) {
        self.value = wrappedValue
    }
}

extension Synchronized: Encodable where Value: Encodable {
    func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

extension Synchronized: Decodable where Value: Decodable {
    init(from decoder: Decoder) throws {
        try self.init(wrappedValue: Value(from: decoder))
    }
}
