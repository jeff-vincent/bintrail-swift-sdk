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
    #elseif os(watchOS)
    struct Application {}
    #endif

    enum Observable {
        case termination
        #if os(iOS) || os(tvOS) || os(macOS) || os(watchOS)
        case applicationState(Application.State)
        #endif
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

    #if os(iOS) || os(tvOS) || os(macOS)
    private static var applicationNotificationObservers: [NSObjectProtocol]?

    private static var isMonitoringApplicationNotifications: Bool {
        return applicationNotificationObservers != nil
    }
    #endif

    private static var observers: [Observer] = []

    private static let operationQueue = OperationQueue()

    private static let dispatchQueue = DispatchQueue(label: "com.bintrail.eventMonitor")
}


internal extension EventMonitor.Application {
    #if os(macOS)
    enum State {
        case active
        case inactive
    }
    #elseif os(watchOS)
    typealias State = WKApplicationState
    #endif
}


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
        if let application = notification.object as? Application {
            event.add(attribute: application.applicationState != .background, for: "inForeground")
            event.add(attribute: application.applicationState == .active, for: "isActive")
        }
        #elseif os(macOS)
        if let application = notification.object as? Application {
            event.add(attribute: application.isActive, for: "isActive")
            event.add(attribute: application.isHidden, for: "isHidden")
            event.add(attribute: application.isRunning, for: "isRunning")
            event.add(attribute: application.occlusionState.contains(.visible), for: "isVisible")
        }
        #endif

        switch notification.name {
        case Application.willTerminateNotification:
            notify(observable: .termination)
        case Application.didBecomeActiveNotification:
            notify(observable: .applicationState(.active))
        case Application.willResignActiveNotification:
            notify(observable: .applicationState(.inactive))
        default:
            break
        }
    }
}
#endif
