internal enum SessionEventType: String, Codable {
    case log
}

internal enum SessionEvent {
    case log(Log)

    var eventType: SessionEventType {
        switch self {
        case .log:
            return .log
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
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(eventType, forKey: .type)

        switch self {
        case .log(let log):
            try container.encode(log, forKey: .value)
        }
    }
}
