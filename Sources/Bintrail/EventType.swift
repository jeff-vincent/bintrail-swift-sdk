public struct EventType: Hashable, Codable {

    internal enum Namespace: String, Codable {
        case executable
        case user
    }

    public enum Significance: Int, Codable {
        case none = 0
        case low = 250
        case `default` = 500
        case high = 750
        case crucial = 1_000
    }

    public enum Effect: Int, Codable {
        case negative = -1
        case neutral = 0
        case positive = 1
    }

    public let name: String

    let namespace: Namespace

    public let significance: Significance

    public let effect: Effect

    public init(name: String, significance: Significance = .default, effect: Effect = .neutral) {
        self.init(name: name, namespace: .user, significance: significance, effect: effect)
    }

    internal init(
        name: String,
        namespace: Namespace,
        significance: Significance,
        effect: Effect
    ) {
        self.name = name
        self.namespace = namespace
        self.significance = significance
        self.effect = effect
    }
}

public extension EventType {

    static let foregroundPeriod = EventType(
        name: "inForeground",
        namespace: .executable,
        significance: .low,
        effect: .neutral
    )

    static let backgroundPeriod = EventType(
        name: "inBackground",
        namespace: .executable,
        significance: .low,
        effect: .neutral
    )

    static let activePeriod = EventType(
        name: "activePeriod",
        namespace: .executable,
        significance: .low,
        effect: .neutral
    )

    static let inactivePeriod = EventType(
        name: "inactivePeriod",
        namespace: .executable,
        significance: .low,
        effect: .neutral
    )

    static let memoryWarning = EventType(
        name: "memoryWarning",
        namespace: .executable,
        significance: .high,
        effect: .negative
    )
}
