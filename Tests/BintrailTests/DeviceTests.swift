@testable import Bintrail
import XCTest
class DeviceTests: XCTestCase {
    #if os(macOS)
    func testMacOSModesNil() {
        XCTAssertNil(Device.current.model)
    }
    #endif

    func testMachineNotNil() {
        XCTAssertNotNil(Device.current.machine)
    }

    func testIdentifierNotNil() {
        XCTAssertNotNil(Device.current.identifier)
    }

    func testMakeNotNil() {
        XCTAssertNotNil(Device.current.make)
    }

    func testPlatformNotNil() {
        XCTAssertNotNil(Device.current.platform)
    }

    func testNameNotNil() {
        XCTAssertNotNil(Device.current.name)
    }

    func testLocaleIdentifier() {
        guard let localeIdentifier = Device.current.localeIdentifier else {
            XCTFail("Locale identifier is nil")
            return
        }

        let locale = Locale(identifier: localeIdentifier)

        guard locale.languageCode != nil  else {
            XCTFail("Language identifier nil from reconstructed locale \(localeIdentifier)")
            return
        }
    }

    func testTimeZoneIdentifier() {
        let timeZoneIdentifier = Device.current.timeZoneIdentifier

        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            XCTFail("\(TimeZone.Type.self) not initializable from tz identifier \(timeZoneIdentifier)")
            return
        }

        XCTAssertEqual(timeZone.identifier, timeZoneIdentifier)
    }

    func testBootTimeNotNil() {
        XCTAssertNotNil(Device.current.bootTime)
    }

    func testIsSimulated() {
        #if targetEnvironment(simulator)
        XCTAssertTrue(Device.current.isSimulated)
        #else
        XCTAssertFalse(Device.current.isSimulated)
        #endif
    }

    func testProcessorTypeNotNil() {
        XCTAssertNotNil(Device.current.processor.type)
    }

    func testProcessorSubTypeNotNil() {
        XCTAssertNotNil(Device.current.processor.subType)
    }

    #if os(iOS) || os(tvOS) || os(macOS) || os(watchOS)
    func testApplePlatformName() {
        let devicePlatformName = Device.current.platform.name

        #if os(macOS)
            XCTAssertEqual(devicePlatformName, "macOS")
        #endif

        #if os(tvOS)
            XCTAssertEqual(devicePlatformName, "tvOS")
        #endif

        #if os(iOS)
            #if targetEnvironment(macCatalyst)
        XCTAssertEqual(devicePlatformName, "macOS")
            #else
        XCTAssertEqual(devicePlatformName, "iOS")
            #endif
        #endif

        #if os(watchOS)
            XCTAssertEqual(devicePlatformName, "watchOS")
        #endif
    }
    #endif

    func testPlatformVersionNameNotNil() {
        XCTAssertNotNil(Device.current.platform.versionName)
    }

    func testPlatformVersionCodeNotNil() {
        XCTAssertNotNil(Device.current.platform.versionCode)
    }
}
