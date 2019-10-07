public protocol AnyUserEvent: AnyObject {

    func add(attribute value: String, for key: String)

    func add<T: BinaryInteger>(metric value: T, for metricType: Event.MetricType)

    func add<T: BinaryFloatingPoint>(metric value: T, for metricType: Event.MetricType)

    func setDuration(_ value: TimeInterval)

    var hasDuration: Bool { get }
}

public final class Event: AnyUserEvent {

    public typealias Metrics = [MetricType: Double]

    public typealias Attributes = [String: String]

    public struct MetricType: RawRepresentable, Hashable {
        public var rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }

    public struct Label: RawRepresentable, Hashable, Codable {
        public var rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }

    public let label: Label

    private var attributes: Attributes

    private var metrics: Metrics

    public let timestamp: Date

    public internal(set) var duration: TimeInterval?

    public var hasDuration: Bool {
        return duration != nil
    }

    internal init(
        label: Label,
        timestamp: Date = Date(),
        duration: TimeInterval? = nil,
        attributes: Attributes = [:],
        metrics: Metrics = [:]
    ) {
        self.label = label
        self.timestamp = timestamp
        self.duration = duration
        self.attributes = attributes
        self.metrics = metrics
    }

    public func add(attribute value: String, for key: String) {
        attributes[key] = value
    }

    public func add<T: LosslessStringConvertible>(attribute value: T, for key: String) {
        attributes[key] = String(value)
    }

    public func add(attribute value: Any, for key: String) {
        attributes[key] = String(describing: value)
    }

    public func add<T: BinaryInteger>(metric value: T, for metricType: Event.MetricType) {
        metrics[metricType] = Double(value)
    }

    public func add<T: BinaryFloatingPoint>(metric value: T, for metricType: Event.MetricType) {
        metrics[metricType] = Double(value)
    }

    public func clock() {
        setDuration(Date().timeIntervalSince(timestamp))
    }

    public func setDuration(_ value: TimeInterval) {
        duration = value
    }
}

extension Event.MetricType: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }
}

extension Event.Label: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }
}

public extension Event.MetricType {
    static let duration: Event.MetricType = "@duration"
}

extension Event: Codable {

    private enum CodingKeys: String, CodingKey {
        case label
        case attributes
        case metrics
        case timestamp
        case duration
    }

    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        var duration = try container.decode(TimeInterval?.self, forKey: .duration)

        if let nonNullDuration = duration {
            duration = nonNullDuration / 1_000
        }

        self.init(
            label: try container.decode(Label.self, forKey: .label),
            timestamp: try container.decode(Date.self, forKey: .timestamp),
            duration: duration,
            attributes: try container.decode(Attributes.self, forKey: .attributes),
            metrics: try container.decode(
                [String: Double].self,
                forKey: .metrics
            ).reduce(into: [:]) { result, keyValue in
                result[Event.MetricType(rawValue: keyValue.key)] = keyValue.value
            }
        )
    }

    public func encode(to encoder: Encoder) throws {

        let stringKeyedMetrics: [String: Double] = metrics.reduce(into: [:]) { result, keyValue in
            result[keyValue.key.rawValue] = keyValue.value
        }

        var duration = self.duration

        if let nonNullDuration = duration {
            duration = nonNullDuration * 1_000
        }

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(label, forKey: .label)
        try container.encode(attributes, forKey: .attributes)
        try container.encode(stringKeyedMetrics, forKey: .metrics)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(duration, forKey: .duration)
    }
}

public func bt_event_start(_ label: Event.Label) -> Event {
    return Event(label: label)
}

public func bt_event_finish(_ event: Event) {
    if event.hasDuration == false {
        event.clock()
    }

    bt_event_register(event)
}

internal func bt_event_register(_ event: Event) {
    Bintrail.shared.currentSession.enqueueEvent(.event(event))
}

public func bt_event<T>(_ label: Event.Label, _ body: (Event) throws -> T) rethrows -> T {

    let event = Event(label: label)
    let value = try body(event)

    bt_event_register(event)
    return value
}
