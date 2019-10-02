internal struct SessionStartRequest {
    let timestamp: Date
    let client: ClientInfo
    let device: DeviceInfo
    let sessionId: String?

    init(timestamp: Date, client: ClientInfo, device: DeviceInfo, sessionId: String? = nil) {
        self.timestamp = timestamp
        self.client = client
        self.device = device
        self.sessionId = sessionId
    }
}

extension SessionStartRequest {
    init(_ session: Session) {
        self.init(
            timestamp: session.timestamp, client:
            session.client,
            device: session.device
        )
    }
}

extension SessionStartRequest: Encodable {}
