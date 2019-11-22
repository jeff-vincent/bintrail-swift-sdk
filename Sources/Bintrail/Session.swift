public final class Session {
    
    internal struct Context: Codable {
        let appId: String
        let sessionId: String
    }

    internal var context: Context?

    @Synchronized private(set) var events: [SessionEvent]

    internal func dequeueEvents(count: Int) {
        bt_debug("Dequeueing \(count) event(s) from session.")
        events.removeFirst(count)
    }

    internal func enqueueEvent(_ event: SessionEvent) {
        events.append(event)
    }

    internal init() {
        events = []
    }
}

extension Session: Equatable {
    public static func == (lhs: Session, rhs: Session) -> Bool {
        return lhs === rhs
    }
}

extension Session: Codable {}
