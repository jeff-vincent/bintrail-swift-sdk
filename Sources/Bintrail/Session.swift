public final class Session {

    internal struct Context: Codable {
        let appId: String
        let sessionId: String
    }

    internal var context: Context?

    private(set) var events: [SessionEvent]

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

    fileprivate init(context: Context?, events: [SessionEvent]) {
        self.context = context
        self.events = events
    }
}

extension Session: Equatable {
    public static func == (lhs: Session, rhs: Session) -> Bool {
        return lhs === rhs
    }
}

extension Session: Codable {

    private enum CodingKeys: String, CodingKey {
        case context
        case events
    }

    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.init(
            context: try container.decode(Context?.self, forKey: .context),
            events: try container.decode([SessionEvent].self, forKey: .events)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(context, forKey: .context)
        try container.encode(events, forKey: .events)
    }
}
