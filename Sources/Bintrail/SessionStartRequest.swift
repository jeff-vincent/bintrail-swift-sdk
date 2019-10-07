internal struct SessionStartRequest {
    let client: Executable
    let device: Device
}


extension SessionStartRequest: Encodable {}
