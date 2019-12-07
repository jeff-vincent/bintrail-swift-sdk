import Foundation

public final class Event {
    public typealias Metrics = [Metric: Float]

    public typealias Attributes = [String: String]

    public let name: Name

    public private(set) var attributes: Attributes

    public private(set) var metrics: Metrics

    public let timestamp: Date

    internal init(
        name: Name,
        timestamp: Date = Date(),
        attributes: Attributes = [:],
        metrics: Metrics = [:]
    ) {
        self.name = name
        self.timestamp = timestamp
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
        metrics[metric] = Float(value)
    }

    public func add<T: BinaryFloatingPoint>(value: T, forMetric metric: Event.Metric) {
        metrics[metric] = Float(value)
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
    }

    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            name: try container.decode(Name.self, forKey: .name),
            timestamp: try container.decode(Date.self, forKey: .timestamp),
            attributes: try container.decode(Attributes.self, forKey: .attributes),
            metrics: try container.decode(
                [String: Float].self,
                forKey: .metrics
            ).reduce(into: [:]) { result, keyValue in
                result[Event.Metric(rawValue: keyValue.key)] = keyValue.value
            }
        )
    }

    public func encode(to encoder: Encoder) throws {
        let stringKeyedMetrics: [String: Float] = metrics.reduce(into: [:]) { result, keyValue in
            result[keyValue.key.rawValue] = keyValue.value
        }

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(attributes, forKey: .attributes)
        try container.encode(stringKeyedMetrics, forKey: .metrics)
        try container.encode(timestamp, forKey: .timestamp)
    }
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
        case tvOS
        case watchOS
        case macOS
        case linux
        case unknown
        case user

        public static var currentOperatingSystem: Namespace {
            #if os(iOS)
            return .iOS
            #elseif os(tvOS)
            return .tvOS
            #elseif os(watchOS)
            return .watchOS
            #elseif os(macOS)
            return .macOS
            #elseif os(Linux)
            return .linux
            #else
            return .unknown
            #endif
        }
    }

    struct Name: Hashable, Codable {
        internal let value: String

        internal let namespace: Namespace

        public init(value: String) {
            self.init(value: value, namespace: .user)
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
