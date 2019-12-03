public final class Event {

    public typealias Metrics = [MetricType: Double]

    public typealias Attributes = [String: String]

    public struct MetricType: RawRepresentable, Hashable {
        public var rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }

    public let type: EventType

    private var attributes: Attributes

    private var metrics: Metrics

    public let timestamp: Date

    public internal(set) var duration: TimeInterval?

    public var hasDuration: Bool {
        return duration != nil
    }

    internal init(
        type: EventType,
        timestamp: Date = Date(),
        duration: TimeInterval? = nil,
        attributes: Attributes = [:],
        metrics: Metrics = [:]
    ) {
        self.type = type
        self.timestamp = timestamp
        self.duration = duration
        self.attributes = attributes
        self.metrics = metrics
    }

    public func add(attributes: [AnyHashable: Any]) {
        for (key, value) in attributes {
            add(attribute: value, for: String(describing: key))
        }
    }

    public func add(attribute value: String?, for key: String) {
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

public extension Event.MetricType {
    static let duration: Event.MetricType = "@duration"
}

extension Event: Codable {

    private enum CodingKeys: String, CodingKey {
        case type
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
            type: try container.decode(EventType.self, forKey: .type),
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
        try container.encode(type, forKey: .type)
        try container.encode(attributes, forKey: .attributes)
        try container.encode(stringKeyedMetrics, forKey: .metrics)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(duration, forKey: .duration)
    }
}

public func bt_event_start(_ type: EventType) -> Event {
    return Event(type: type)
}

public func bt_event_finish(_ event: Event) {
    if event.hasDuration == false {
        event.clock()
    }

    bt_event_register(event)
}

internal func bt_event_register(_ event: Event) {
    Bintrail.shared.currentSession.add(.event(event))
}

public func bt_event_register(_ type: EventType) {
    bt_event_register(Event(type: type))
}

public func bt_event_register<T>(_ type: EventType, _ body: (Event) throws -> T) rethrows -> T {

    let event = Event(type: type)
    let value = try body(event)

    bt_event_register(event)
    return value
}
