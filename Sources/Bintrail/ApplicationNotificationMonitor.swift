#if os(iOS) || os(tvOS) || os(macOS)
import Foundation

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

struct ApplicationNotificationMonitor {
    private static var applicationNotificationObservers: [NSObjectProtocol]?

    private static var isMonitoringApplicationNotifications: Bool {
        return applicationNotificationObservers != nil
    }

    private static let operationQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        operationQueue.underlyingQueue = dispatchQueue
        return operationQueue
    }()

    private static let dispatchQueue = DispatchQueue(label: "com.bintrail.eventMonitor")

    static func install() {
        let applicationNotificationBlock: (Notification) -> Void = { notification in
            DispatchQueue.main.async {
                ApplicationNotificationMonitor.handleApplicationNotification(notification: notification)
            }
        }

        let notificationCenter = NotificationCenter.default

        applicationNotificationObservers = nil

        var newObservers: [NSObjectProtocol] = []

        for notificationName in applicationNotificationNames {
            let observer = notificationCenter.addObserver(
                forName: notificationName,
                object: nil,
                queue: operationQueue,
                using: applicationNotificationBlock
            )

            newObservers.append(observer)
        }

        applicationNotificationObservers = newObservers
    }
}

private extension ApplicationNotificationMonitor {
    #if os(macOS)
    static var macOSApplicationNotificationNames: Set<Notification.Name> {
        [
            NSApplication.willTerminateNotification,
            NSApplication.didBecomeActiveNotification,
            NSApplication.willResignActiveNotification,
            NSApplication.didFinishLaunchingNotification
        ]
    }
    #endif

    #if os(iOS) || os(tvOS)
    static var iOSApplicationNotificationNames: Set<Notification.Name> {
        var result: [Notification.Name] = []

        #if swift(>=4.2)
        result += [
            UIApplication.willTerminateNotification,
            UIApplication.didBecomeActiveNotification,
            UIApplication.willResignActiveNotification,
            UIApplication.didFinishLaunchingNotification
        ]
        #else
        result += [
            .UIApplicationWillTerminate,
            .UIApplicationDidBecomeActive,
            .UIApplicationWillResignActive,
            .UIApplicationDidFinishLaunching
        ]
        #endif

        #if swift(>=4.2)
        result += [
            UIApplication.willEnterForegroundNotification,
            UIApplication.didEnterBackgroundNotification,
            UIApplication.didReceiveMemoryWarningNotification,
            UIApplication.significantTimeChangeNotification,
            UIApplication.userDidTakeScreenshotNotification
        ]

        #if os(iOS)
        result += [
            UIApplication.didChangeStatusBarFrameNotification,
            UIApplication.didChangeStatusBarOrientationNotification,
            UIApplication.keyboardWillShowNotification,
            UIApplication.keyboardDidShowNotification,
            UIApplication.keyboardWillHideNotification,
            UIApplication.keyboardDidHideNotification,
            UIApplication.keyboardDidChangeFrameNotification
        ]
        #endif

        #else
        result += [
            .UIApplicationWillEnterForeground,
            .UIApplicationDidEnterBackground,
            .UIApplicationDidReceiveMemoryWarning,
            .UIApplicationSignificantTimeChange,
            .UIApplicationUserDidTakeScreenshot
        ]

        #if os(iOS)
        result += [
            .UIApplicationDidChangeStatusBarFrame,
            .UIApplicationDidChangeStatusBarOrientation,
            .UIKeyboardWillShow,
            .UIKeyboardDidShow,
            .UIKeyboardWillHide,
            .UIKeyboardDidHide,
            .UIKeyboardDidChangeFrame
        ]
        #endif

        #endif

        return Set(result)
    }
    #endif

    static var applicationNotificationNames: Set<NSNotification.Name> {
        #if os(iOS) || os(tvOS)
        return iOSApplicationNotificationNames
        #elseif os(macOS)
        return macOSApplicationNotificationNames
        #endif
    }

    static func handleApplicationNotification(notification: Notification) {
        let event = Event(
            name: Event.Name(
                value: notification.name.rawValue,
                namespace: .applicationNotification
            )
        )

        defer {
            bt_event_register(event)
        }

        #if os(iOS) || os(tvOS)
        if let application = notification.object as? UIApplication {
            event.add(value: application.applicationState != .background, forAttribute: "inForeground")
            event.add(value: application.applicationState == .active, forAttribute: "isActive")
        }
        #elseif os(macOS)
        if let application = notification.object as? NSApplication {
            event.add(value: application.isActive, forAttribute: "isActive")
            event.add(value: application.isHidden, forAttribute: "isHidden")
            event.add(value: application.isRunning, forAttribute: "isRunning")
            event.add(value: application.occlusionState.contains(.visible), forAttribute: "isVisible")
        }
        #endif
    }
}
#endif
