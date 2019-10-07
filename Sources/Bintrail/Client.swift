internal struct Client {

    let versionName: String?
    let versionCode: Int?
    let packageName: String?
    let title: String

    static var current: Client {
        return Client(bundle: .main)
    }

    private init(bundle: Bundle) {
        packageName = bundle.bundleIdentifier

        versionName = bundle.infoDictionary?["CFBundleShortVersionString"] as? String

        if let value = bundle.infoDictionary?["CFBundleVersion"] as? String {
            versionCode = Int(value)
        } else {
            versionCode = nil
        }

        title = bundle.infoDictionary?["CFBundleName"] as? String ?? "Unknown"
    }
}

extension Client: Codable {}
