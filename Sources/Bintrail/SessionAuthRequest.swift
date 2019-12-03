internal struct SessionInitRequest {

    let executable: Executable?

    let device: Device?

    let startedAt: Date

    init(metadata: Session.Metadata) {
        executable = metadata.executable
        device = metadata.device
        startedAt = metadata.startedAt
    }
}

internal struct SessionInitResponse: Decodable {

    private enum CodingKeys: String, CodingKey {
        case remoteIdentifier = "sessionId"
    }

    let remoteIdentifier: String
}

extension SessionInitRequest: Encodable {}
