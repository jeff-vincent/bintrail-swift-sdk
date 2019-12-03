internal class SessionEntriesBatch: Encodable {

    let logs: [Log]

    let events: [Event]

    let sessionId: String

    init<T: Sequence>(sessionId: String, entries: T) where T.Element == SessionEntry {

        var logs: [Log] = []
        var events: [Event] = []

        for entry in entries {
            switch entry {
            case .log(let entry):
                logs.append(entry)
            case .event(let entry):
                events.append(entry)
            }
        }

        self.sessionId = sessionId

        self.logs = logs
        self.events = events
    }
}
