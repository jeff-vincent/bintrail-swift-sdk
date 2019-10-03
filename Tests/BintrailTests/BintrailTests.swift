@testable import Bintrail
import XCTest

class BintrailTests: XCTestCase {

    func testExample() {

        let exp = expectation(description: #function)

        Bintrail.shared.configure(
            keyId: "ORY4X5C7GC4UCZGKAEN0",
            secret: "CsSvrZYvCeheoAhywkDBHqLLyAGWaUUpMJv87LiT"
        )

        for index in 0..<10 {
            bt_log("This is log message #\(index)", type: .debug)
        }

        waitForExpectations(timeout: 60)
    }
}
