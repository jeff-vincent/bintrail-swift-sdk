import Foundation

#if canImport(UIKit)
import UIKit
#endif

#if canImport(WatchKit)
import WatchKit
#endif

struct SystemVersionPlist: Decodable {
    enum CodingKeys: String, CodingKey {
        case productBuildVersion = "ProductBuildVersion"
        case productVersion = "ProductVersion"
        case productName = "ProductName"
    }

    let productBuildVersion: String
    let productVersion: String
    let productName: String
}

private extension OperatingSystemVersion {
    var stringValue: String {
        return [String(majorVersion), String(minorVersion), String(patchVersion)].joined(separator: ".")
    }
}

private extension ProcessInfo {
    var operatingSystemBuild: String? {
        let versionString = ProcessInfo.processInfo.operatingSystemVersionString

        guard
            let startIndex = versionString.range(of: "(Build ")?.upperBound,
            let endIndex = versionString.lastIndex(of: ")") else {
            return nil
        }

        return String(versionString[startIndex ..< endIndex])
    }
}

struct Device: Codable {
    struct Processor: Codable {
        let type: Int32?
        let subType: Int32?
    }

    struct Platform: Codable {
        /// Name of the platform, e.g. `iOS` or `tvOS`
        let name: String

        /// Version code of the platform, e.g. `17C45`
        let versionCode: String?

        /// Version name of the platform, e.g. `13.3`
        let versionName: String?
    }

    /// Device identifier. May or may not be unique to the actual hardware, due to privacy concerns.
    /// For iOS platforms this value corresponds to `UIDevice.identifierForVendor`
    let identifier: String

    /// The machine class, e.g `iPhone12,5`
    let machine: String?

    /// The machine model
    let model: String?

    /// The make of the device, e.g. `Apple`
    let make: String?

    /// Device platform
    let platform: Platform

    /// Device name
    let name: String?

    /// Device locale identifier, e.g. `en`, or `sv_SE`
    let localeIdentifier: String?

    /// Device time zone identifier
    let timeZoneIdentifier: String

    /// Device kernel version
    let kernelVersion: String?

    /// Device boot time
    let bootTime: Date?

    /// Device processor info
    let processor: Processor

    /// Indicates whether the device is simulated
    let isSimulated: Bool
}

internal extension Device {
    static var current: Device {
        let processInfo = ProcessInfo.processInfo

        let identifier: String?
        let isSimulated: Bool
        let name: String?
        let platform: Platform
        let make: String?

        #if os(iOS) || os(tvOS) || os(macOS) || os(watchOS)
        make = "Apple"
        #endif

        #if os(iOS) || os(tvOS)
        let uiDevice = UIDevice.current
        identifier = (uiDevice.identifierForVendor ?? UUID()).uuidString

        let systemName: String
        #if targetEnvironment(macCatalyst)
            systemName = "macOS"
        #else
            systemName = uiDevice.systemName
        #endif

        name = uiDevice.name
        platform = Platform(
            name: systemName,
            versionCode: processInfo.operatingSystemBuild,
            versionName: uiDevice.systemVersion
        )
        #elseif os(watchOS)
        let device = WKInterfaceDevice.current()
        identifier = nil
        name = device.name
        platform = Platform(
            name: "watchOS",
            versionCode: processInfo.operatingSystemBuild,
            versionName: device.systemVersion
        )
        #elseif os(macOS)
        let platformExpert: io_service_t = IOServiceGetMatchingService(
            kIOMasterPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )

        let serialNumberAsCFString = IORegistryEntryCreateCFProperty(
            platformExpert,
            kIOPlatformSerialNumberKey as CFString,
            kCFAllocatorDefault,
            0
        )

        IOObjectRelease(platformExpert)

        identifier = serialNumberAsCFString?.takeUnretainedValue() as? String

        name = Host.current().name
        platform = Platform(
            name: "macOS",
            versionCode: processInfo.operatingSystemBuild,
            versionName: processInfo.operatingSystemVersion.stringValue
        )
        #endif

        #if targetEnvironment(simulator)
        isSimulated = true
        #else
        isSimulated = false
        #endif

        return Device(
            // In case a device identifier has not been established, a unique identifier
            // is given.
            identifier: identifier ?? UUID().uuidString,
            machine: Sysctl.machine,
            model: Sysctl.model,
            make: make,
            platform: platform,
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
