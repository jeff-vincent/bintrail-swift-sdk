@testable import Bintrail
import XCTest
class SysctlTests: XCTestCase {
    func testIsDebuggerAttachedNotNil() {
        XCTAssert(Sysctl.isDebuggerAttached != nil)
    }

    func testHostNameNotNil() {
        XCTAssert(Sysctl.hostName != nil)
    }

    func testMachineNotNil() {
        XCTAssert(Sysctl.machine != nil)
    }
}
