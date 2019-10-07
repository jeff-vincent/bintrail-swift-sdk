internal struct CrashReport {
    let executable: Executable
}

extension CrashReport: Decodable {

    private enum DecodingKeys: String, CodingKey {
        case system
        case crash
    }

    init(from decoder: Decoder) throws {

        let container = try decoder.container(keyedBy: DecodingKeys.self)

        executable = try container.decode(Executable.self, forKey: .system)
    }
}

extension CrashReport: Encodable {}
