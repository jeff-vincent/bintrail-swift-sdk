import KSCrash
#if canImport(UIKit)
import UIKit
#endif

struct Device: Encodable {

    struct Processor: Encodable {
        let architecture: String
        let type: Int32
        let subType: Int32?
    }

    struct MemoryInfo: Encodable {
        let size: UInt64
        let free: UInt64
        let usable: UInt64
    }

    struct Platform: Encodable {
        let name: String
        let versionCode: String
        let versionName: String
    }

    let identifier: String

    let platform: Platform

    let name: String?

    let localeIdentifier: String?

    let kernelVersion: String

    let bootTime: Date?
    let isJailBroken: Bool

    let processor: Processor
    let memory: MemoryInfo
}

extension Device.MemoryInfo: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CrashReportBody.DecodingKey.self)

        size = try container.decode(UInt64.self, forKey: .size)
        free = try container.decode(UInt64.self, forKey: .free)
        usable = try container.decode(UInt64.self, forKey: .usable)
    }
}

extension Device.Processor: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CrashReportBody.DecodingKey.self)

        architecture = try container.decode(String.self, forKey: .cpuArchitecture)

        type = try container.decode(Int32.self, forKey: .cpuType)
        subType = try container.decode(Int32.self, forKey: .cpuSubtype)
    }
}

extension Device: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CrashReportBody.DecodingKey.self)

        processor = try container.decode(Processor.self, forKey: .system)

        let systemContainer = try container.nestedContainer(
            keyedBy: CrashReportBody.DecodingKey.self,
            forKey: .system
        )

        if container.contains(.userInfo) {
            let userInfoContainer = try container.nestedContainer(
                keyedBy: CrashReportBody.UserInfo.CodingKeys.self,
                forKey: .userInfo
            )

            name = try userInfoContainer.decodeIfPresent(String.self, forKey: .deviceName)
            localeIdentifier = try userInfoContainer.decodeIfPresent(String.self, forKey: .localeIdentifier)
        } else {
            name = nil
            localeIdentifier = nil
        }

        identifier = try systemContainer.decode(String.self, forKey: .deviceAppHash)

        memory = try systemContainer.decode(MemoryInfo.self, forKey: .memory)

        platform = Platform(
            name: try systemContainer.decode(String.self, forKey: .systemName),
            versionCode: try systemContainer.decode(String.self, forKey: .osVersion),
            versionName: try systemContainer.decode(String.self, forKey: .systemVersion)
        )

        kernelVersion = try systemContainer.decode(String.self, forKey: .kernelVersion)

        bootTime = CrashReporter.dateFormatterSecondPrecision.date(
            from: try systemContainer.decode(String.self, forKey: .bootTime)
        )

        isJailBroken = try systemContainer.decode(Bool.self, forKey: .isJailBroken)
    }
}
