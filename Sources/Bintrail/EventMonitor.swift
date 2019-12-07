import Foundation

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

#if canImport(WatchKit)
import WatchKit
#endif

struct EventMonitor {
    #if os(iOS) || os(tvOS)
    typealias Application = UIApplication
    #elseif os(macOS)
    typealias Application = NSApplication
    #endif

    enum Observable {
        case termination
        case applicationState(Application.State)
    }

    final class Observer: Equatable {
        fileprivate let dispatch: (Observable) -> Void

        fileprivate init(execute: @escaping (Observable) -> Void) {
            self.dispatch = execute
        }

        func remove() {
            EventMonitor.removeObserver(self)
        }

        static func == (lhs: Observer, rhs: Observer) -> Bool {
            return lhs === rhs
        }
    }

    #if os(iOS) || os(tvOS) || os(macOS) || os(watchOS)
    private static var applicationNotificationObservers: [NSObjectProtocol]?

    private static var isMonitoringApplicationNotifications: Bool {
        return applicationNotificationObservers != nil
    }
    #endif

    private static var observers: [Observer] = []

    private static let operationQueue = OperationQueue()

    private static let dispatchQueue = DispatchQueue(label: "com.bintrail.eventMonitor")
}

#if os(macOS)
extension EventMonitor.Application {
    enum State {
        case active
        case inactive
        case occluded
    }
}
#endif

extension EventMonitor {
    static func addObserver(_ execute: @escaping (Observable) -> Void) -> Observer {
        let observer = Observer(execute: execute)
        observers.append(observer)
        return observer
    }

    static func removeObserver(_ observer: Observer) {
        observers = observers.filter { other in
            other != observer
        }
    }

    private static func notify(observable: Observable) {
        for observer in observers {
            observer.dispatch(observable)
        }
    }
}

#if os(iOS) || os(tvOS) || os(macOS)
internal extension EventMonitor {
    static func monitorApplicationEvents(verbose: Bool) {
        let applicationNotificationBlock: (Notification) -> Void = { notification in
            DispatchQueue.main.async {
                EventMonitor.handleApplicationNotification(notification: notification)
            }
        }

        var notificationNames: [Notification.Name] = [
            Application.willTerminateNotification,
            Application.didBecomeActiveNotification,
            Application.willResignActiveNotification,
            Application.didFinishLaunchingNotification
        ]

        if verbose {
            #if os(iOS) || os(tvOS)
            notificationNames += [
                Application.willEnterForegroundNotification,
                Application.didEnterBackgroundNotification,
                Application.didReceiveMemoryWarningNotification,
                Application.significantTimeChangeNotification,
                Application.userDidTakeScreenshotNotification,
                Application.didChangeStatusBarFrameNotification,
                Application.didChangeStatusBarOrientationNotification,
                Application.backgroundRefreshStatusDidChangeNotification,
                Application.keyboardWillShowNotification,
                Application.keyboardDidShowNotification,
                Application.keyboardWillHideNotification,
                Application.keyboardDidHideNotification,
                Application.keyboardDidChangeFrameNotification
            ]
            #endif
        }

        let notificationCenter = NotificationCenter.default

        applicationNotificationObservers = nil

        var newObservers: [NSObjectProtocol] = []

        for notificationName in Set(notificationNames) {
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

    private static func handleApplicationNotification(notification: Notification) {
        guard let application = notification.object as? Application else {
            return
        }

        let event = Event(name: Event.Name(value: notification.name.rawValue, namespace: .currentOperatingSystem))

        defer {
            bt_event_register(event)
        }

        #if os(iOS) || os(tvOS)
        event.add(attribute: application.applicationState, for: "applicationState")
        #elseif os(macOS)
        event.add(attribute: application.occlusionState, for: "occlusionState")
        #endif

        switch notification.name {
        case Application.willTerminateNotification:
            notify(observable: .termination)
        #if os(macOS)
        case Application.didBecomeActiveNotification:
            notify(observable: .applicationState(.active))
        case Application.willResignActiveNotification:
            notify(observable: .applicationState(.inactive))
        case Application.didChangeOcclusionStateNotification:
            if application.occlusionState.contains(.visible) {
                notify(observable: .applicationState(.active))
            } else {
                notify(observable: .applicationState(.occluded))
            }
        #endif
        default:
            break
        }
    }
}
#endif
