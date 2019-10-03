internal class PutSessionEventBatchRequest: Encodable {

    let logs: [Log]

    let userEvents: [UserEvent]

    init<T: Sequence>(_ records: T) where T.Element == SessionEvent {

        var logs: [Log] = []
        var userEvents: [UserEvent] = []

        for record in records {
            switch record {
            case .log(let event):
                logs.append(event)
            case .userEvent(let event):
                userEvents.append(event)
            }
        }

        self.logs = logs
        self.userEvents = userEvents
    }
}
