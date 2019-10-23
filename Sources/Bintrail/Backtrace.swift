internal struct Backtrace: Collection {

    struct Element: Encodable {
        let symbolAddress: UInt
        let instructionAddress: UInt
        let objectName: String
        let objectAddress: UInt
    }

    private let elements: [Element]

    let isSkipped: Int

    var startIndex: Int {
        elements.startIndex
    }

    var endIndex: Int {
        elements.endIndex
    }

    subscript(position: Int) -> Element {
        elements[position]
    }

    func index(after index: Int) -> Int {
        elements.index(after: index)
    }
}

extension Backtrace: Encodable {

    private enum EncodingKey: String, CodingKey {
        case skipped
        case contents
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: EncodingKey.self)

        try container.encode(isSkipped, forKey: .skipped)
        try container.encode(elements, forKey: .contents)
    }
}

extension Backtrace.Element: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CrashReportBody.DecodingKey.self)

        symbolAddress = try container.decode(UInt.self, forKey: .symbolAddress)
        instructionAddress = try container.decode(UInt.self, forKey: .instructionAddress)
        objectName = try container.decode(String.self, forKey: .objectName)
        objectAddress = try container.decode(UInt.self, forKey: .objectAddress)
    }
}

extension Backtrace: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CrashReportBody.DecodingKey.self)

        isSkipped = try container.decode(Int.self, forKey: .skipped)
        elements = try container.decode([Element].self, forKey: .contents)

    }
}
