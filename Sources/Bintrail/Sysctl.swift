import Foundation

#if os(Linux)
import Glibc
#else
import Darwin
#endif

/// https://www.freebsd.org/cgi/man.cgi?sysctl(3)
struct Sysctl {
    enum Error: Swift.Error {
        case unknown
        case malformedUTF8
        case invalidSize
        case posixError(POSIXErrorCode)

        init(errno: Int32) {
            self = POSIXErrorCode(rawValue: errno).map { errorCode in
                Error.posixError(errorCode)
            } ?? Error.unknown
        }
    }

    static func requiredSize(for keys: [Int32]) throws -> Int {
        var keys = keys
        var size = 0

        guard sysctl(&keys, UInt32(keys.count), nil, &size, nil, 0) == 0 else {
            throw Error(errno: errno)
        }

        return size
    }

    static func data(for keys: [Int32]) throws -> [Int8] {
        var size = try requiredSize(for: keys)
        var keys = keys

        var data = [Int8](repeating: 0, count: size)

        guard sysctl(&keys, UInt32(keys.count), &data, &size, nil, 0) == 0 else {
            throw Error(errno: errno)
        }

        return data
    }

    static func keys(for name: String) throws -> [Int32] {
        var keysBufferSize = Int(CTL_MAXNAME)
        var keysBuffer = [Int32](repeating: 0, count: keysBufferSize)
        try keysBuffer.withUnsafeMutableBufferPointer { (lbp: inout UnsafeMutableBufferPointer<Int32>) throws in
            try name.withCString { (nbp: UnsafePointer<Int8>) throws in
                guard sysctlnametomib(nbp, lbp.baseAddress, &keysBufferSize) == 0 else {
                    throw POSIXErrorCode(rawValue: errno).map { Error.posixError($0) } ?? Error.unknown
                }
            }
        }
        if keysBuffer.count > keysBufferSize {
            keysBuffer.removeSubrange(keysBufferSize..<keysBuffer.count)
        }
        return keysBuffer
    }

    static func value<T>(ofType: T.Type, for keys: [Int32]) throws -> T {
        let buffer = try data(for: keys)
        if buffer.count != MemoryLayout<T>.size {
            throw Error.invalidSize
        }
        return try buffer.withUnsafeBufferPointer { bufferPointer throws -> T in
            guard let baseAddress = bufferPointer.baseAddress else { throw Error.unknown }
            return baseAddress.withMemoryRebound(to: T.self, capacity: 1) { $0.pointee }
        }
    }

    static func string(for keys: [Int32]) throws -> String {
        let value = try data(for: keys)
        return String(cString: value)
    }

    static func date(for keys: [Int32]) throws -> Date {
        let timeValue = try self.time(for: keys)
        return Date(timeIntervalSince1970: Double(timeValue.tv_sec) + Double(timeValue.tv_usec) / 1_000 / 1_000)
    }

    static func time(for keys: [Int32]) throws -> timeval {
        var data = timeval()

        try populate(value: &data, for: keys)

        return data
    }

    static func populate<T>(value: inout T, for keys: [Int32]) throws {
        var size = try requiredSize(for: keys)
        var keys = keys

        guard sysctl(&keys, UInt32(keys.count), &value, &size, nil, 0) == 0 else {
            throw Error(errno: errno)
        }
    }

    static var hostName: String? {
        try? Sysctl.string(for: [CTL_KERN, KERN_HOSTNAME])
    }

    static let isDebuggerAttached: Bool? = {
        var data = kinfo_proc()

        do {
            try populate(
                value: &data,
                for: [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
            )

            return data.kp_proc.p_flag & P_TRACED != 0
        } catch {
            return nil
        }
    }()

    static var machine: String? {
        #if targetEnvironment(simulator)
        return ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"]
        #else
        #if os(macOS)
            return try? Sysctl.string(for: [CTL_HW, HW_MODEL])
        #else
            return try? Sysctl.string(for: [CTL_HW, HW_MACHINE])
        #endif
        #endif
    }

    static var model: String? {
        #if targetEnvironment(simulator)
        return "simulator"
        #else
        #if os(macOS)
        return nil
        #else
        return try? Sysctl.string(for: [CTL_HW, HW_MODEL])
        #endif
        #endif
    }

    /// E.g "Darwin"
    static var operatingSystemType: String? {
        try? string(for: [CTL_KERN, KERN_OSTYPE])
    }

    static var operatingSystemVersion: String? {
        try? string(for: [CTL_KERN, KERN_OSVERSION])
    }

    static var kernelVersion: String? {
        try? string(for: [CTL_KERN, KERN_VERSION])
    }

    static var bootTime: Date? {
        try? date(for: [CTL_KERN, KERN_BOOTTIME])
    }

    static var cpuType: Int32? {
        try? value(ofType: Int32.self, for: Sysctl.keys(for: "hw.cputype"))
    }

    static var cpuSubtype: Int32? {
        try? value(ofType: Int32.self, for: Sysctl.keys(for: "hw.cpusubtype"))
    }

    static var cpuCount: Int32? {
        try? value(ofType: Int32.self, for: [CTL_HW, HW_NCPU])
    }

    #if os(macOS)
    static var cpuFrequency: Int64? {
        try? value(ofType: Int64.self, for: [CTL_HW, HW_CPU_FREQ])
    }

    static var memorySize: UInt64? {
        try? value(ofType: UInt64.self, for: [CTL_HW, HW_MEMSIZE])
    }
    #endif
}
