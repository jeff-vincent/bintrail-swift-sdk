import KSCrash

struct Executable {
    let identifier: String
    let name: String
    let version: Int?
    let versionName: String
    let startTime: Date?

    let title: String
    let path: String
}

extension Executable: Encodable {}

extension Executable: Decodable {

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CrashReport.DecodingKey.self)

        identifier = try container.decode(String.self, forKey: .appUUID)
        name = try container.decode(String.self, forKey: .bundleId)

        version = Int(try container.decode(String.self, forKey: .bundleVersion))

        versionName = try container.decode(String.self, forKey: .bundleShortVersion)

        startTime = CrashReporter.dateFormatter.date(
            from: try container.decode(String.self, forKey: .appStartTime)
        )

        title = try container.decode(String.self, forKey: .bundleName)
        path = try container.decode(String.self, forKey: .executablePath)
    }
}
