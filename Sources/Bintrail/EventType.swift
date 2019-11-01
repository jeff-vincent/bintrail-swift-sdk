public struct EventType: Hashable, Codable {

    internal enum Namespace: String, Codable {
        case ios
        case user
    }

    public enum Significance: Int, Codable {
        case none = 0
        case low = 250
        case `default` = 500
        case high = 750
        case crucial = 1_000
    }

    public enum Outcome: Hashable {
        case positive(Significance)
        case negative(Significance)
        case neutral
    }

    public let name: String

    public let outcome: Outcome?

    let namespace: Namespace

    public init(name: String, outcome: Outcome) {
        self.init(name: name, namespace: .user, outcome: outcome)
    }

    internal init(
        name: String,
        namespace: Namespace,
        outcome: Outcome
    ) {
        self.name = name
        self.namespace = namespace
        self.outcome = outcome
    }
}

extension EventType.Outcome: Codable {

    private enum Effect: String, Codable {
        case positive
        case negative
    }

    private enum CodingKeys: String, CodingKey {
        case effect
        case significance
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let effect = try container.decode(Effect.self, forKey: .effect)

        let significance = try container.decode(EventType.Significance.self, forKey: .significance)

        switch effect {
        case .negative:
            self = .negative(significance)
        case .positive:
            self = .positive(significance)
        }
    }

    public func encode(to encoder: Encoder) throws {

        switch self {
        case .negative(let significance):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(significance, forKey: .significance)
            try container.encode(Effect.negative, forKey: .effect)

        case .positive(let significance):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(significance, forKey: .significance)
            try container.encode(Effect.positive, forKey: .effect)

        case .neutral:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        }
    }
}

internal extension EventType {

    static let foregroundPeriod = EventType(
        name: "inForeground",
        namespace: .ios,
        outcome: .neutral
    )

    static let backgroundPeriod = EventType(
        name: "inBackground",
        namespace: .ios,
        outcome: .neutral
    )

    static let activePeriod = EventType(
        name: "activePeriod",
        namespace: .ios,
        outcome: .neutral
    )

    static let inactivePeriod = EventType(
        name: "inactivePeriod",
        namespace: .ios,
        outcome: .neutral
    )

    static let memoryWarning = EventType(
        name: "memoryWarning",
        namespace: .ios,
        outcome: .negative(.high)
    )
}
