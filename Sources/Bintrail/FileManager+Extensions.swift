import Foundation

internal extension FileManager {
    var bintrailDirectoryUrl: URL? {
        urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("bintrail")
    }

    func createDirectoryIfNeeded(
        at url: URL,
        withIntermediateDirectories createIntermediates: Bool,
        attributes: [FileAttributeKey: Any]? = nil
    ) throws {
        guard !fileExists(atPath: url.path) else {
            return
        }

        try createDirectory(
            at: url,
            withIntermediateDirectories: createIntermediates,
            attributes: attributes
        )
    }
}
