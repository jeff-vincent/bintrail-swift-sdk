internal struct CrashError: Encodable {
    struct Mach: Encodable {
        let code: Int
        let exceptionName: String
        let subcode: Int
        let exception: Int
    }

    struct Signal: Encodable {
        let signal: Int
        let code: Int
    }

    let mach: Mach
    let signal: Signal
    let type: String
    let address: UInt
}

internal struct Crash: Encodable {

    let error: CrashError
    let threads: [Thread]

}

extension Crash: Decodable {

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CrashReport.DecodingKey.self)

        error = try container.decode(CrashError.self, forKey: .error)
        threads = try container.decode([Thread].self, forKey: .threads)
    }
}

extension CrashError.Mach: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CrashReport.DecodingKey.self)

        code = try container.decode(Int.self, forKey: .code)
        exceptionName = try container.decode(String.self, forKey: .exceptionName)
        subcode = try container.decode(Int.self, forKey: .subcode)
        exception = try container.decode(Int.self, forKey: .exception)
    }
}

extension CrashError.Signal: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CrashReport.DecodingKey.self)

        signal = try container.decode(Int.self, forKey: .signal)
        code = try container.decode(Int.self, forKey: .code)
    }
}

extension CrashError: Decodable {

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CrashReport.DecodingKey.self)

        mach = try container.decode(Mach.self, forKey: .mach)
        signal = try container.decode(Signal.self, forKey: .signal)

        type = try container.decode(String.self, forKey: .type)
        address = try container.decode(UInt.self, forKey: .address)
    }
}
