struct Device: Encodable {

    struct Processor: Encodable {
        let architecture: String
        let type: Int32
        let subType: Int32
        let binaryType: Int32
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
