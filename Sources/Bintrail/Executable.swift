import KSCrash

struct Executable {
    let identifier: String?
    let name: String?
    let version: Int?
    let versionName: String?
    let startTime: Date?

    let title: String?
    let path: String?
}

extension Executable: Encodable {}

extension Executable: Decodable {

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CrashReport.DecodingKey.self)

        identifier = try container.decode(String?.self, forKey: .appUUID)
        name = try container.decode(String?.self, forKey: .bundleId)

        if let value = try container.decode(String?.self, forKey: .bundleVersion) {
            version = Int(value)
        } else {
            version = nil
        }

        versionName = try container.decode(String?.self, forKey: .bundleShortVersion)

        if let value = try container.decode(String?.self, forKey: .appStartTime) {
            startTime = CrashReporter.dateFormatter.date(from: value)
        } else {
            startTime = nil
        }

        title = try container.decode(String?.self, forKey: .bundleName)
        path = try container.decode(String?.self, forKey: .executablePath)
    }
}
