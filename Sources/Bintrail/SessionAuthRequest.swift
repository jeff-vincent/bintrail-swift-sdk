internal struct SessionAuthRequest {
    let executable: Executable
    let device: Device
}

extension SessionAuthRequest: Encodable {}
