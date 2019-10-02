internal struct ClientInfo {

    let versionName: String?
    let versionCode: Int?
    let packageName: String?
    let title: String?

    static var current: ClientInfo {
        return ClientInfo(bundle: .main)
    }

    private init(bundle: Bundle) {
        packageName = bundle.bundleIdentifier

        versionName = bundle.infoDictionary?["CFBundleShortVersionString"] as? String

        if let value = bundle.infoDictionary?["CFBundleVersion"] as? String {
            versionCode = Int(value)
        } else {
            versionCode = nil
        }

        title = bundle.infoDictionary?["CFBundleDisplayName"] as? String
    }
}

extension ClientInfo: Codable {}
