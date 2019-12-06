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

    let identifier: String?

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
        let identifier: String?
        let isSimulated: Bool
        let platformName: String?
        let name: String?

        #if canImport(UIKit)
        let uiDevice = UIDevice.current
        identifier = (uiDevice.identifierForVendor ?? UUID()).uuidString
        platformName = uiDevice.systemVersion
        name = uiDevice.name
        #else
        identifier = nil
        platformName = Sysctl.operatingSystemType
        name = Sysctl.hostName
        #endif

        #if targetEnvironment(simulator)
        isSimulated = true
        #else
        isSimulated = false
        #endif

        return Device(
            identifier: identifier,
            machine: Sysctl.machine,
            model: Sysctl.model,
            platform: Device.Platform(
                name: platformName,
                versionCode: Sysctl.operatingSystemVersion,
                versionName: Sysctl.operatingSystemRelease
            ),
            name: name,
            localeIdentifier: Locale.current.identifier,
            timeZoneIdentifier: TimeZone.current.identifier,
            kernelVersion: Sysctl.kernelVersion,
            bootTime: Sysctl.bootTime,
            processor: Device.Processor(
                type: Sysctl.cpuType,
                subType: Sysctl.cpuSubtype
            ),
            isSimulated: isSimulated
        )
    }
}
