import Foundation

#if canImport(UIKit)
import UIKit
#endif

struct Device: Codable {
    struct Processor: Codable {
        let type: Int32?
        let subType: Int32?
    }

    struct Platform: Codable {
        let name: String?
        let versionCode: String?
        let versionName: String?
    }

    let identifier: String

    let machine: String?

    let model: String?

    let platform: Platform

    let name: String?

    let localeIdentifier: String?

    let timeZoneIdentifier: String

    let kernelVersion: String?

    let bootTime: Date?

    let processor: Processor

    let isSimulated: Bool
}

internal extension Device {
    static var current: Device {
        let uiDevice = UIDevice.current

        #if targetEnvironment(simulator)
        let isSimulated = true
        #else
        let isSimulated = false
        #endif

        return Device(
            identifier: (uiDevice.identifierForVendor ?? UUID()).uuidString,
            machine: sysctlMachine,
            model: sysctlModel,
            platform: Device.Platform(
                name: uiDevice.systemName,
                versionCode: sysctlString(named: "kern.osversion"),
                versionName: uiDevice.systemVersion
            ),
            name: uiDevice.name,
            localeIdentifier: Locale.current.identifier,
            timeZoneIdentifier: TimeZone.current.identifier,
            kernelVersion: sysctlString(named: "kern.version"),
            bootTime: sysctlDate(named: "kern.boottime"),
            processor: Device.Processor(
                type: sysctlInt32(named: "hw.cputype"),
                subType: sysctlInt32(named: "hw.cpusubtype")
            ),
            isSimulated: isSimulated
        )
    }
}
