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

    @SyncWrapper private(set) var records: [SessionEvent]

    internal func dequeueEvents(count: Int) {
        bt_debug("Dequeueing \(count) event(s) from session.")
        records.removeFirst(count)
    }

    internal func enqueueEvent(_ event: SessionEvent) {
        records.append(event)
    }

    internal init() {
        records = []
    }
}

extension Session: Equatable {
    public static func == (lhs: Session, rhs: Session) -> Bool {
        return lhs === rhs
    }
}

extension Session: Codable {}
