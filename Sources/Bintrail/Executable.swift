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

    struct DecodingKey: CodingKey {

        let intValue: Int? = nil

        init?(intValue: Int) {
            return nil
        }

        internal let stringValue: String

        init(stringValue: String) {
            self.stringValue = stringValue
        }

        static let identifier = DecodingKey(stringValue: KSCrashField_AppUUID)
        static let name = DecodingKey(stringValue: KSCrashField_BundleID)
        static let version = DecodingKey(stringValue: KSCrashField_BundleVersion)
        static let versionName = DecodingKey(stringValue: KSCrashField_BundleShortVersion)
        static let startTime = DecodingKey(stringValue: KSCrashField_AppStartTime)
        static let title = DecodingKey(stringValue: KSCrashField_BundleName)
        static let path = DecodingKey(stringValue: KSCrashField_ExecutablePath)

    }

    init(with decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DecodingKey.self)

        identifier = try container.decode(String.self, forKey: .identifier)
        name = try container.decode(String.self, forKey: .name)
        version = try container.decode(Int?.self, forKey: .version)
        versionName = try container.decode(String.self, forKey: .versionName)

        let startTimeString = try container.decode(String.self, forKey: .startTime)
        startTime = CrashReporter.dateFormatter.date(from: startTimeString)

        title = try container.decode(String.self, forKey: .title)
        path = try container.decode(String.self, forKey: .path)
    }
}
