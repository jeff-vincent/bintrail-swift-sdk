internal class PutSessionEventBatchRequest: Encodable {

    let logs: [Log]

    let events: [Event]

    init<T: Sequence>(_ records: T) where T.Element == SessionEvent {

        var logs: [Log] = []
        var events: [Event] = []

        for record in records {
            switch record {
            case .log(let event):
                logs.append(event)
            case .event(let event):
                events.append(event)
            }
        }

        self.logs = logs
        self.events = events
    }
}
