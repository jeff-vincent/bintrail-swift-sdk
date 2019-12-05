import Foundation

#if os(Linux)
import Glibc
#else
import Darwin
#endif

internal var sysctlMachine: String? {
    #if targetEnvironment(simulator)
    return ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"]
    #else
    #if os(macOS)
    return sysctlString(named: "hw.model")
    #else
    return sysctlString(named: "hw.machine")
    #endif
    #endif
}

public var sysctlModel: String? {
    #if targetEnvironment(simulator)
    return "simulator"
    #else
    #if os(macOS)
    return nil
    #else
    return sysctlString(named: "hw.model")
    #endif
    #endif
}

public func sysctlTimeval(named name: String) -> timeval? {
    var value = timeval()
    var size = MemoryLayout.size(ofValue: value)

    if sysctlbyname(name, &value, &size, nil, 0) != 0 {
        return nil
    }

    return value
}

public func sysctlInt32(named name: String) -> Int32? {
    var value: Int32 = 0
    var size = MemoryLayout.size(ofValue: value)

    if sysctlbyname(name, &value, &size, nil, 0) != 0 {
        return nil
    }

    return value
}

public func sysctlDate(named name: String) -> Date? {
    guard let value = sysctlTimeval(named: name) else {
        return nil
    }

    return Date(timeIntervalSince1970: Double(value.tv_sec) + Double(value.tv_usec) * 1_000 * 1_000)
}

public func sysctlString(named name: String) -> String? {
    var size = -1

    if name.isEmpty {
        return nil
    }

    if sysctlbyname(name, nil, &size, nil, 0) != 0 {
        return nil
    }

    var value = [UInt8](repeatElement(0, count: size))

    if sysctlbyname(name, &value, &size, nil, 0) != 0 {
        return nil
    }

    let result = String(cString: value)

    return result.isEmpty ? nil : result
}
