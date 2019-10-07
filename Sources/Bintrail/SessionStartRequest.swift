internal struct SessionStartRequest {
    let executable: Executable
    let device: Device
}

extension SessionStartRequest: Encodable {}
