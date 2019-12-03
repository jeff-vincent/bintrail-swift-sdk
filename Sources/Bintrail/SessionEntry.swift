internal enum SessionEntryType: String, Codable {
    case log
    case event
}

internal enum SessionEntry {
    case log(Log)
    case event(Event)

    var recordType: SessionEntryType {
        switch self {
        case .log: return .log
        case .event: return .event
        }
    }
}

internal extension SessionEntry {

    var sendUrgency: Float {
        switch self {
        case .event:
            return 0.25
        case .log(let log):
            switch log.level {
            case .trace: return 0
            case .debug: return 0.1
            case .info: return 0.25
            case .warning: return 0.5
            case .error, .fatal: return 1
            }
        }
    }
}

extension SessionEntry: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let type = try container.decode(SessionEntryType.self, forKey: .type)

        switch type {
        case .log:
            self = .log(try container.decode((Log.self), forKey: .value))
        case .event:
            self = .event(try container.decode(Event.self, forKey: .value))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(recordType, forKey: .type)

        switch self {
        case .log(let value):
            try container.encode(value, forKey: .value)
        case .event(let value):
            try container.encode(value, forKey: .value)
        }
    }
}
