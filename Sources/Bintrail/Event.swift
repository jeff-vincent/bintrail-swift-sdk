public final class Event {

    public typealias Metrics = [Metric: Double]

    public typealias Attributes = [String: String]

    public let name: Name

    public private(set) var attributes: Attributes

    public private(set) var metrics: Metrics

    public let timestamp: Date

    public internal(set) var duration: TimeInterval?

    public var hasDuration: Bool {
        return duration != nil
    }

    internal init(
        name: Name,
        timestamp: Date = Date(),
        duration: TimeInterval? = nil,
        attributes: Attributes = [:],
        metrics: Metrics = [:]
    ) {
        self.name = name
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

    public func add<T: BinaryInteger>(value: T, forMetric metric: Event.Metric) {
        metrics[metric] = Double(value)
    }

    public func add<T: BinaryFloatingPoint>(value: T, forMetric metric: Event.Metric) {
        metrics[metric] = Double(value)
    }

    public func clock() {
        setDuration(Date().timeIntervalSince(timestamp))
    }

    public func setDuration(_ value: TimeInterval) {
        duration = value
    }
}

extension Event.Metric: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }
}

public extension Event.Metric {
    static let duration: Event.Metric = "@duration"
}

extension Event: Codable {

    private enum CodingKeys: String, CodingKey {
        case name
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
            name: try container.decode(Name.self, forKey: .name),
            timestamp: try container.decode(Date.self, forKey: .timestamp),
            duration: duration,
            attributes: try container.decode(Attributes.self, forKey: .attributes),
            metrics: try container.decode(
                [String: Double].self,
                forKey: .metrics
            ).reduce(into: [:]) { result, keyValue in
                result[Event.Metric(rawValue: keyValue.key)] = keyValue.value
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
        try container.encode(name, forKey: .name)
        try container.encode(attributes, forKey: .attributes)
        try container.encode(stringKeyedMetrics, forKey: .metrics)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(duration, forKey: .duration)
    }
}

public func bt_event_start(_ name: Event.Name) -> Event {
    return Event(name: name)
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

public func bt_event_register(_ name: Event.Name) {
    bt_event_register(Event(name: name))
}

public func bt_event_register<T>(_ name: Event.Name, _ body: (Event) throws -> T) rethrows -> T {

    let event = Event(name: name)
    let value = try body(event)

    bt_event_register(event)
    return value
}

public extension Event {

    struct Metric: RawRepresentable, Hashable {
        public var rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }

    internal enum Namespace: String, Codable {
        case iOS
        case custom
    }

    struct Name: Hashable, Codable {

        internal let value: String

        internal let namespace: Namespace

        public init(value: String) {
            self.init(value: value, namespace: .custom)
        }

        internal init(
            value: String,
            namespace: Namespace
        ) {
            self.value = value
            self.namespace = namespace
        }
    }
}

extension Event.Name: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value: value)
    }
}

internal extension Event.Name {

    static let foregroundPeriod = Event.Name(value: "inForeground", namespace: .iOS)

    static let backgroundPeriod = Event.Name(value: "inBackground", namespace: .iOS)

    static let activePeriod = Event.Name(value: "activePeriod", namespace: .iOS)

    static let inactivePeriod = Event.Name(value: "inactivePeriod", namespace: .iOS)

    static let memoryWarning = Event.Name(value: "memoryWarning", namespace: .iOS)
}
