internal struct SessionStartRequest {
    let timestamp: Date
    let client: Client
    let device: DeviceInfo

    init(timestamp: Date, client: Client, device: DeviceInfo) {
        self.timestamp = timestamp
        self.client = client
        self.device = device
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
