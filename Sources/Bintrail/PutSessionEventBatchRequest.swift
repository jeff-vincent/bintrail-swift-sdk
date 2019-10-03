internal class PutSessionEventBatchRequest: Encodable {

    let logs: [Log]

    init<T: Sequence>(_ events: T) where T.Element == SessionEvent {

        var logs: [Log] = []

        for event in events {
            switch event {
            case .log(let log):
                logs.append(log)
            }
        }

        self.logs = logs
    }
}
