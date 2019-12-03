import Foundation

internal extension FileManager {

    var bintrailDirectoryUrl: URL? {
        urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("bintrail")
    }
}
