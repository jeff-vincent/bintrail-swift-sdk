public struct EventType: Hashable, Codable {

    internal enum Namespace: String, Codable {
        case ios
        case user
    }

    public let name: String

    let namespace: Namespace

    public init(name: String) {
        self.init(name: name, namespace: .user)
    }

    internal init(
        name: String,
        namespace: Namespace
    ) {
        self.name = name
        self.namespace = namespace
    }
}

extension EventType: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(name: value)
    }
}

internal extension EventType {

    static let foregroundPeriod = EventType(
        name: "inForeground",
        namespace: .ios
    )

    static let backgroundPeriod = EventType(
        name: "inBackground",
        namespace: .ios
    )

    static let activePeriod = EventType(
        name: "activePeriod",
        namespace: .ios
    )

    static let inactivePeriod = EventType(
        name: "inactivePeriod",
        namespace: .ios
    )

    static let memoryWarning = EventType(
        name: "memoryWarning",
        namespace: .ios
    )
}
