@testable import Bintrail
import XCTest
class IngestionTests: XCTestCase {
    // swiftlint:disable function_body_length
    func testIngestion() throws {
        let sessionMetadataIngestedExpectation = expectation(description: "Session meta data ingested")
        sessionMetadataIngestedExpectation.assertForOverFulfill = false

        let sessionEntriesIngestedExpectation = expectation(description: "Session entries ingested")
        sessionEntriesIngestedExpectation.assertForOverFulfill = false

        var observers: [NSObjectProtocol] = []

        // swiftlint:disable discarded_notification_center_observer
        observers.append(
            NotificationCenter.default.addObserver(
                forName: Session.metadataIngestionSuccessNotification,
                object: nil,
                queue: nil) { _ in
                    sessionMetadataIngestedExpectation.fulfill()
            }
        )

        observers.append(
            NotificationCenter.default.addObserver(
                forName: Session.metadataIngestionFailureNotification,
                object: nil,
                queue: nil) { notification in
                    XCTFail((notification.userInfo?[NSUnderlyingErrorKey] as? Error).debugDescription)
                    observers.removeAll()
                    sessionMetadataIngestedExpectation.fulfill()
                    sessionEntriesIngestedExpectation.fulfill()
            }
        )

        observers.append(
            NotificationCenter.default.addObserver(
                forName: Session.entriesIngestionSuccessNotificationName,
                object: nil,
                queue: nil) { _ in
                    sessionEntriesIngestedExpectation.fulfill()
            }
        )

        observers.append(
            NotificationCenter.default.addObserver(
                forName: Session.entriesIngestionFailureNotificationName,
                object: nil,
                queue: nil) { notification in
                    XCTFail((notification.userInfo?[NSUnderlyingErrorKey] as? Error).debugDescription)
                    observers.removeAll()
                    sessionEntriesIngestedExpectation.fulfill()
                    sessionMetadataIngestedExpectation.fulfill()
            }
        )
        // swiftlint:enable discarded_notification_center_observer

        try? FileManager.default.removeItem(at: FileManager.default.bintrailDirectoryUrl!)

        Bintrail.isDebugModeEnabled = true

        try Bintrail.shared.configure(
            keyId: "VDELZJ8HQU7X8TT2BF8I",
            secret: "iVEPb4j7Cq7GLJzTXh6Uu80h49O7D4duGeaa9hFZ",
            monitoring: [
                .applicationNotifications,
                .viewControllerLifecycle
            ]
        )

        bt_log(#function)

        bt_event_register("XCTestEvent") { event in
            event.add(value: sessionMetadataIngestedExpectation.expectationDescription, forAttribute: "exp1")
            event.add(value: sessionEntriesIngestedExpectation.expectationDescription, forAttribute: "exp2")
        }

        waitForExpectations(timeout: 60)
    }
    // swiftlint:enable function_body_length
}
