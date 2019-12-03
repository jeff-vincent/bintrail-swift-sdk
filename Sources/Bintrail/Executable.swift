import KSCrash

struct Executable: Codable {

    struct Package: Codable {
        let identifier: String
        let versionName: String
        let versionCode: String
        let name: String
    }

    let name: String

    let identifier: String
    let package: Package
    let startTime: Date?

    let title: String
    let path: String
}
