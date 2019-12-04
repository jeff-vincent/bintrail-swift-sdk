import KSCrash
#if canImport(UIKit)
import UIKit
#endif

struct Device: Codable {
    struct Processor: Codable {
        let architecture: String
        let type: Int32
        let subType: Int32?
    }

    struct MemoryInfo: Codable {
        let size: UInt64
        let free: UInt64
        let usable: UInt64
    }

    struct Platform: Codable {
        let name: String
        let versionCode: String
        let versionName: String
    }

    let identifier: String

    let machine: String

    let model: String

    let platform: Platform

    let name: String?

    let localeIdentifier: String?

    let timeZoneIdentifier: String

    let kernelVersion: String

    let bootTime: Date?

    let isJailBroken: Bool

    let processor: Processor

    let memory: MemoryInfo
}
