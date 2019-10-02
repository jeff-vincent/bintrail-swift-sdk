import Foundation
#if canImport(UIKit)
import UIKit
#endif

internal struct DeviceInfo {
    let identifier: String
    let name: String
    let model: String
    let make: String
    let platformVersion: String
    let platform: String
    let locale: Locale

    #if canImport(UIKit)

    static var current: DeviceInfo {
        return DeviceInfo(device: .current)
    }

    private init(device: UIDevice) {
        identifier = (device.identifierForVendor ?? UUID()).uuidString
        name = device.name
        model = device.model
        make = "Apple"
        platformVersion = device.systemVersion
        platform = device.systemName
        locale = Locale.current
    }
    #endif
}

extension DeviceInfo: Codable {}
