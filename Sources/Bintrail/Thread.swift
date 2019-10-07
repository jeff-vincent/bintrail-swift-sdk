internal struct Thread: Encodable {

    let crashed: Bool

    let backtrace: Backtrace
}

extension Thread: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CrashReport.DecodingKey.self)
        crashed = try container.decode(Bool.self, forKey: .crashed)
        backtrace = try container.decode(Backtrace.self, forKey: .backtrace)
    }
}
