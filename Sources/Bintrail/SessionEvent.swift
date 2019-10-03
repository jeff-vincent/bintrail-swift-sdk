internal enum SessionEventType: String, Codable {
    case log
    case userEvent
}

internal enum SessionEvent {
    case log(Log)
    case userEvent(UserEvent)

    var recordType: SessionEventType {
        switch self {
        case .log: return .log
        case .userEvent: return .userEvent
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
        case .userEvent:
            self = .userEvent(try container.decode(UserEvent.self, forKey: .value))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(recordType, forKey: .type)

        switch self {
        case .log(let value):
            try container.encode(value, forKey: .value)
        case .userEvent(let value):
            try container.encode(value, forKey: .value)
        }
    }
}
