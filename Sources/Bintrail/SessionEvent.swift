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
