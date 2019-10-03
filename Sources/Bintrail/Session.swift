internal struct SessionCredentials {
    let token: String
    let expirationDate: Date
}

extension SessionCredentials: Codable {
    private enum CodingKeys: String, CodingKey {
        case token = "bearerToken"
        case expirationDate = "expiresAt"
    }
}

public final class Session {

    internal var credentials: SessionCredentials?

    public let startDate: Date

    let client: Client

    let device: Device

    @SyncWrapper private(set) var events: [SessionEvent]

    internal init(startDate: Date) {
        self.startDate = startDate
        client = .current
        device = .current
        events = []
    }

    internal func dequeueEvents(count: Int) {
        bt_debug("Dequeueing \(count) event(s) from session.")
        events.removeFirst(count)
    }

    internal func enqueueEvent(_ event: SessionEvent) {
        events.append(event)
    }
}

extension Session: Equatable {
    public static func == (lhs: Session, rhs: Session) -> Bool {
        return lhs === rhs
    }
}

internal extension Session {

    func log(
        _ items: [Any],
        type: LogType,
        timestamp: Date,
        terminator: String = " ",
        file: StaticString = #file,
        function: StaticString = #function,
        line: Int = #line,
        column: Int = #column
    ) {
        let log = Log(
            level: type,
            message: items.map({ String(describing: $0) }).joined(separator: terminator),
            line: line,
            column: column,
            function: String(describing: function),
            file: String(describing: file),
            timestamp: timestamp
        )

        enqueueEvent(.log(log))
    }
}

extension Session: Codable {}
