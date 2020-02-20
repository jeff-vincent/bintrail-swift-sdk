import Foundation

struct Executable: Codable {
    private static let startTime = Date()

    struct Package: Codable {
        let identifier: String

        let versionName: String

        let versionCode: String

        let name: String
    }

    let name: String

    let package: Package

    let startTime: Date

    let path: String

    let isDebug: Bool
}

extension Executable {
    static var current: Executable {
        let bundle = Bundle.main
        let infoDictionary = bundle.infoDictionary ?? [:]

        return Executable(
            name: infoDictionary["CFBundleExecutable"] as? String ?? "Unnamed",
            package: Package(
                identifier: infoDictionary["CFBundleIdentifier"] as? String ?? "unknown",
                versionName: infoDictionary["CFBundleShortVersionString"] as? String ?? "0",
                versionCode: infoDictionary["CFBundleVersion"] as? String ?? "0",
                name: infoDictionary["CFBundleName"] as? String ?? "Unnamed"
            ),
            startTime: Executable.startTime,
            path: bundle.bundlePath,
            isDebug: Sysctl.isDebuggerAttached ?? false
        )
    }
}
