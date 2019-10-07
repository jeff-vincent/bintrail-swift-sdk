internal struct BinaryImage: Encodable {
    let majorVersion: Int
    let minorVersion: Int
    let revisionVersion: Int
    let uuid: UUID
    let name: String

    let vmAddress: UInt
    let address: UInt
    let size: UInt
}
extension BinaryImage: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CrashReport.DecodingKey.self)

        majorVersion = try container.decode(Int.self, forKey: .imageMajorVersion)
        minorVersion = try container.decode(Int.self, forKey: .imageMinorVersion)
        revisionVersion = try container.decode(Int.self, forKey: .imageRevisionVersion)
        uuid = try container.decode(UUID.self, forKey: .uuid)
        name = try container.decode(String.self, forKey: .name)

        vmAddress = try container.decode(UInt.self, forKey: .imageVmAddress)
        address = try container.decode(UInt.self, forKey: .imageAddress)
        size = try container.decode(UInt.self, forKey: .imageSize)
    }
}
