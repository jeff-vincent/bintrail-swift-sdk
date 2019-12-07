@testable import Bintrail
import XCTest

class SysCtlTests: XCTestCase {
    func testExample() throws {

        let device = Device.current

        let encoder = JSONEncoder.bintrailDefault
        encoder.outputFormatting = [.prettyPrinted]
        
        let data = try encoder.encode(device)

        guard let string = String(data: data, encoding: .utf8) else {
            XCTFail()
            return
        }

        print(string)
    }
}
