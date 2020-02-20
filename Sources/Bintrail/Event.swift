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
            add(value: value, forAttribute: String(describing: key))
        }
    }

    public func add(value: String?, forAttribute key: String) {
        attributes[key] = value
    }

    public func add<T: LosslessStringConvertible>(value: T, forAttribute key: String) {
        attributes[key] = String(value)
    }

    public func add(value: Any, forAttribute key: String) {
        attributes[key] = String(describing: value)
    }

    public func add<T: BinaryInteger>(value: T, forMetric metric: Event.Metric) {
        metrics[metric] = Float(value)
    }

    public func add<T: BinaryFloatingPoint>(value: T, forMetric metric: Event.Metric) {
        metrics[metric] = Float(value)
    }
}

extension Event: CustomDebugStringConvertible {
    public var debugDescription: String {
        var string = String(format: "[EVENT]: %@", String(describing: name))

        if !attributes.isEmpty {
            string += "\n\tAttributes:\n"
            string += attributes.map { kvp in
                return String(format: "\t\t%@: %@", kvp.key, kvp.value)
            }.joined(separator: "\n")
        }

        if !metrics.isEmpty {
            string += "\n\tMetrics:\n"
            string += metrics.map { kvp in
                return String(
                    format: "\t\t%@: %@",
                    String(describing: kvp.key),
                    String(describing: kvp.value)
                )
            }.joined(separator: "\n")
        }

        return string
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
    if Sysctl.isDebuggerAttached == true {
        debugPrint(event)
    }

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

    internal struct Namespace: RawRepresentable, Hashable, Codable {
        var rawValue: String

        init(rawValue: String) {
            self.rawValue = rawValue
        }

        public static let user = Namespace(rawValue: "user")

        #if os(iOS) || os(tvOS) || os(macOS)
        public static var applicationNotification: Namespace {
            #if os(iOS) || os(tvOS)
            return "UIKit.UIApplication.Notification"
            #elseif os(macOS)
            return "AppKit.NSApplication.Notification"
            #endif
        }

        public static var viewControllerLifecycle: Namespace {
            #if os(iOS) || os(tvOS)
            return "UIKit.UIViewController.Lifecycle"
            #elseif os(macOS)
            return "AppKit.NSViewController.Lifecycle"
            #endif
        }
        #endif
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

extension Event.Metric: CustomStringConvertible {
    public var description: String {
        rawValue
    }
}

extension Event.Name: CustomDebugStringConvertible {
    public var debugDescription: String {
        guard namespace != .user else {
            return value
        }

        return String(format: "%@.%@", String(describing: namespace), value)
    }
}

extension Event.Namespace: CustomDebugStringConvertible {
    public var debugDescription: String {
        return rawValue
    }
}

extension Event.Namespace: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        self.init(rawValue: value)
    }
}

extension Event.Name: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value: value)
    }
}
