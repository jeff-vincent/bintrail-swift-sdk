internal enum SessionEventType: String, Codable {
    case log
    case event
}

internal enum SessionEvent {
    case log(Log)
    case event(Event)

    var recordType: SessionEventType {
        switch self {
        case .log: return .log
        case .event: return .event
        }
    }
}

extension SessionEvent: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let type = try container.decode(SessionEventType.self, forKey: .type)

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
