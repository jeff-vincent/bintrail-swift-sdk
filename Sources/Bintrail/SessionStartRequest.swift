internal struct SessionStartRequest {
    let timestamp: Date
    let client: Client
    let device: Device
    let sessionId: String?

    init(timestamp: Date, client: Client, device: Device, sessionId: String? = nil) {
        self.timestamp = timestamp
        self.client = client
        self.device = device
        self.sessionId = sessionId
    }
}

extension SessionStartRequest {
    init(_ session: Session) {
        self.init(
            timestamp: session.startDate,
            client: session.client,
            device: session.device
        )
    }
}

extension SessionStartRequest: Encodable {}
