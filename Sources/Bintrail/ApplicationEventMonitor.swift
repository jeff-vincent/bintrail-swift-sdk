import Foundation

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

struct ApplicationEventMonitor {
    #if os(iOS) || os(tvOS) || os(macOS)
    private static var applicationNotificationObservers: [NSObjectProtocol]?

    private static var isMonitoringApplicationNotifications: Bool {
        return applicationNotificationObservers != nil
    }
    #endif

    private static let operationQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        operationQueue.underlyingQueue = dispatchQueue
        return operationQueue
    }()

    private static let dispatchQueue = DispatchQueue(label: "com.bintrail.eventMonitor")

    static func install() {
        let applicationNotificationBlock: (Notification) -> Void = { notification in
            DispatchQueue.main.async {
                ApplicationEventMonitor.handleApplicationNotification(notification: notification)
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

#if os(iOS) || os(tvOS) || os(macOS)

private extension ApplicationEventMonitor {
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
            UIApplication.userDidTakeScreenshotNotification,
            UIApplication.didChangeStatusBarFrameNotification,
            UIApplication.didChangeStatusBarOrientationNotification,
            UIApplication.keyboardWillShowNotification,
            UIApplication.keyboardDidShowNotification,
            UIApplication.keyboardWillHideNotification,
            UIApplication.keyboardDidHideNotification,
            UIApplication.keyboardDidChangeFrameNotification
        ]
        #else
        result += [
            .UIApplicationWillEnterForeground,
            .UIApplicationDidEnterBackground,
            .UIApplicationDidReceiveMemoryWarning,
            .UIApplicationSignificantTimeChange,
            .UIApplicationUserDidTakeScreenshot,
            .UIApplicationDidChangeStatusBarFrame,
            .UIApplicationDidChangeStatusBarOrientation,
            .UIKeyboardWillShow,
            .UIKeyboardDidShow,
            .UIKeyboardWillHide,
            .UIKeyboardDidHide,
            .UIKeyboardDidChangeFrame
        ]
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
            event.add(attribute: application.applicationState != .background, for: "inForeground")
            event.add(attribute: application.applicationState == .active, for: "isActive")
        }
        #elseif os(macOS)
        if let application = notification.object as? NSApplication {
            event.add(attribute: application.isActive, for: "isActive")
            event.add(attribute: application.isHidden, for: "isHidden")
            event.add(attribute: application.isRunning, for: "isRunning")
            event.add(attribute: application.occlusionState.contains(.visible), for: "isVisible")
        }
        #endif
    }
}
#endif
