import KSCrash

struct Device: Encodable {

    struct Processor: Encodable {
        let architecture: String
        let type: Int32
        let subType: Int32?
        let binaryType: Int32?
        let binarySubtype: Int32
    }

    struct MemoryInfo: Encodable {
        let size: UInt64
        let free: UInt64
        let usable: UInt64
    }

    let platformName: String
    let platformVersion: String
    let platformVersionName: String

    let kernelVersion: String

    let bootTime: Date?
    let isJailBroken: Bool

    let processor: Processor
    let memory: MemoryInfo

}

extension Device.MemoryInfo: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CrashReport.DecodingKey.self)

        size = try container.decode(UInt64.self, forKey: .size)
        free = try container.decode(UInt64.self, forKey: .free)
        usable = try container.decode(UInt64.self, forKey: .usable)
    }
}

extension Device.Processor: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CrashReport.DecodingKey.self)

        architecture = try container.decode(String.self, forKey: .cpuArchitecture)

        type = try container.decode(Int32.self, forKey: .cpuType)
        subType = try container.decode(Int32.self, forKey: .cpuSubtype)
        binaryType = try container.decode(Int32.self, forKey: .cpuBinaryType)
        binarySubtype = try container.decode(Int32.self, forKey: .cpuBinarySubtype)
    }
}

extension Device: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CrashReport.DecodingKey.self)

        processor = try Processor(from: decoder)
        memory = try container.decode(MemoryInfo.self, forKey: .memory)

        platformName = try container.decode(String.self, forKey: .systemName)
        platformVersion = try container.decode(String.self, forKey: .osVersion)
        platformVersionName = try container.decode(String.self, forKey: .systemVersion)

        kernelVersion = try container.decode(String.self, forKey: .kernelVersion)

        bootTime = CrashReporter.dateFormatter.date(
            from: try container.decode(String.self, forKey: .bootTime)
        )

        isJailBroken = try container.decode(Bool.self, forKey: .isJailBroken)
    }
}
