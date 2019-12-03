internal class PutSessionEntryBatchRequest: Encodable {

    let logs: [Log]

    let events: [Event]

    let appId: String

    let sessionId: String

    init<T: Sequence>(appId: String, sessionId: String, sessionEvents: T) where T.Element == SessionEntry {

        var logs: [Log] = []
        var events: [Event] = []

        for sessionEvent in sessionEvents {
            switch sessionEvent {
            case .log(let entry):
                logs.append(entry)
            case .event(let entry):
                events.append(entry)
            }
        }

        self.appId = appId
        self.sessionId = sessionId

        self.logs = logs
        self.events = events
    }
}
