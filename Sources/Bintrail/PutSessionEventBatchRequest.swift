internal class PutSessionEventBatchRequest: Encodable {

    let logs: [Log]

    let events: [Event]
    
    let appId: String
    
    let sessionId: String

    init<T: Sequence>(appId: String, sessionId: String, sessionEvents: T) where T.Element == SessionEvent {

        var logs: [Log] = []
        var events: [Event] = []

        for sessionEvent in sessionEvents {
            switch sessionEvent {
            case .log(let event):
                logs.append(event)
            case .event(let event):
                events.append(event)
            }
        }
        
        self.appId = appId
        self.sessionId = sessionId
        
        self.logs = logs
        self.events = events
    }
}
