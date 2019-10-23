import KSCrash

struct Executable {

    struct Package: Encodable {
        let identifier: String
        let versionName: String
        let versionCode: Int?
        let name: String
    }

    let name: String

    let identifier: String
    let package: Package
    let startTime: Date?

    let title: String
    let path: String
}

extension Executable: Encodable {}

extension Executable: Decodable {

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CrashReportBody.DecodingKey.self)

        identifier = try container.decode(String.self, forKey: .appUUID)

        package = Package(
            identifier: try container.decode(String.self, forKey: .bundleId),
            versionName: try container.decode(String.self, forKey: .bundleShortVersion),
            versionCode: Int(try container.decode(String.self, forKey: .bundleVersion)),
            name: try container.decode(String.self, forKey: .bundleName)
        )

        startTime = CrashReport.secondPrecisionDateFormatter.date(
            from: try container.decode(String.self, forKey: .appStartTime)
        )

        title = try container.decode(String.self, forKey: .bundleName)
        path = try container.decode(String.self, forKey: .executablePath)
        name = try container.decode(String.self, forKey: .executable)
    }
}
