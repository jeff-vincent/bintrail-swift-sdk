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

final class EventMonitor {
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
        weak var eventMonitor: EventMonitor?

        fileprivate let dispatch: (Observable) -> Void

        fileprivate init(eventMonitor: EventMonitor, execute: @escaping (Observable) -> Void) {
            self.eventMonitor = eventMonitor
            self.dispatch = execute
        }

        func remove() {
            self.eventMonitor?.removeObserver(self)
        }

        static func == (lhs: Observer, rhs: Observer) -> Bool {
            return lhs === rhs
        }
    }

    private var notificationObservers: [NSObjectProtocol] = []

    private var observers: [Observer] = []

    private let operationQueue = OperationQueue()

    private let dispatchQueue = DispatchQueue(label: "com.bintrail.eventMonitor")
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
    func addObserver(_ execute: @escaping (Observable) -> Void) -> Observer {
        let observer = Observer(eventMonitor: self, execute: execute)
        observers.append(observer)
        return observer
    }

    func removeObserver(_ observer: Observer) {
        observers = observers.filter { other in
            other != observer
        }
    }

    private func notify(observable: Observable) {
        for observer in observers {
            observer.dispatch(observable)
        }
    }
}

#if os(iOS) || os(tvOS) || os(macOS)
private extension EventMonitor {
    private func monitorApplicationEvents() {
        let applicationNotificationBlock: (Notification) -> Void = { [weak self] notification in
            self?.handleApplicationNotification(notification: notification)
        }

        var notificationNames: [Notification.Name] = [
            Application.willTerminateNotification,
            Application.didBecomeActiveNotification,
            Application.willResignActiveNotification,
            Application.didFinishLaunchingNotification
        ]

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

        let notificationCenter = NotificationCenter.default

        for notificationName in Set(notificationNames) {
            let observer = notificationCenter.addObserver(
                forName: notificationName,
                object: nil,
                queue: operationQueue,
                using: applicationNotificationBlock
            )

            notificationObservers.append(observer)
        }
    }

    private func handleApplicationNotification(notification: Notification) {
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
            bt_log_internal("Unhandled application notification:", notification.name)
        }
    }
}
#endif
