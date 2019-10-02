internal struct SessionCredentials {
    let token: String
    let expirationDate: Date
}

internal final class SessionEvents {

    internal var logs: [Log] = []

    var isEmpty: Bool {
        return logs.isEmpty
    }

    static var empty: SessionEvents {
        return SessionEvents()
    }
}

extension SessionEvents: Codable {}

extension SessionCredentials: Codable {}

internal final class Session {

    var credentials: SessionCredentials?

    let timestamp: Date

    let client: ClientInfo

    let device: DeviceInfo

    var events: SessionEvents

    init(timestamp: Date) {
        self.timestamp = timestamp
        client = .current
        device = .current
        events = .empty
    }
}

extension Session: Equatable {
    public static func == (lhs: Session, rhs: Session) -> Bool {
        return lhs === rhs
    }
}

internal extension Session {

    func log(
        _ items: Any...,
        type: LogType,
        timestamp: Date,
        terminator: String = " ",
        file: StaticString = #file,
        function: StaticString = #function,
        line: Int = #line,
        column: Int = #column
    ) {
        events.logs.append(
            Log(
                level: type,
                message: items.map({ String(describing: $0) }).joined(separator: terminator),
                line: line,
                column: column,
                function: String(describing: function),
                file: String(describing: file),
                timestamp: timestamp
            )
        )
    }
}

extension Session: Codable {}
