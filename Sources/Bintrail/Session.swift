internal struct SessionCredentials {
    let token: String
    let expirationDate: Date
    let appIdentifier: String
    let sessionIdentifier: String
}

extension SessionCredentials: Codable {
    private enum CodingKeys: String, CodingKey {
        case token = "bearerToken"
        case expirationDate = "expiresAt"
        case appIdentifier = "appId"
        case sessionIdentifier = "sessionId"
    }
}

public final class Session {

    internal var credentials: SessionCredentials?

    public let startDate: Date

    let client: Client

    let device: Device

    @SyncWrapper private(set) var records: [SessionEvent]

    internal init(startDate: Date) {
        self.startDate = startDate
        client = .current
        device = .current
        records = []
    }

    internal func dequeueEvents(count: Int) {
        bt_debug("Dequeueing \(count) event(s) from session.")
        records.removeFirst(count)
    }

    internal func enqueueEvent(_ event: SessionEvent) {
        records.append(event)
    }
}

extension Session: Equatable {
    public static func == (lhs: Session, rhs: Session) -> Bool {
        return lhs === rhs
    }
}

extension Session: Codable {}
