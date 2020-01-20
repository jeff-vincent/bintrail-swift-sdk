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
        let name: String?
        let versionCode: String?
        let versionName: String?
    }

    let identifier: String?

    /// The machine class
    let machine: String?

    /// The machine model
    let model: String?

    // 
    let make: String?

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
        let processInfo = ProcessInfo.processInfo

        let identifier: String?
        let isSimulated: Bool
        let name: String?
        let platform: Platform
        let make: String?

        #if os(iOS) || os(tvOS) || os(macOS) || os(watchOS)
        make = "Apple"
        #else
        make = nil // TODO: Resolve make for non-Apple platforms
        #endif

        #if os(iOS) || os(tvOS)
        let uiDevice = UIDevice.current
        identifier = (uiDevice.identifierForVendor ?? UUID()).uuidString
        name = uiDevice.name
        platform = Platform(
            name: uiDevice.systemName,
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
        identifier = nil
        name = Host.current().name
        platform = Platform(
            name: "macOS",
            versionCode: processInfo.operatingSystemBuild,
            versionName: processInfo.operatingSystemVersion.stringValue
        )
        #else
        // TODO: Linux
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
