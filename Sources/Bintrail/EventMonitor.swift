import Foundation

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

final class EventMonitor {
    #if canImport(UIKit)
    private typealias Application = UIApplication
    #elseif canImport(AppKit)
    private typealias Application = NSApplication
    #endif

    enum ExecutableState {
        case active
        case inactive
    }

    final class ExecutableStateObserver: Equatable {
        weak var eventMonitor: EventMonitor?

        fileprivate let dispatch: (ExecutableState) -> Void

        fileprivate init(eventMonitor: EventMonitor, execute: @escaping (ExecutableState) -> Void) {
            self.eventMonitor = eventMonitor
            self.dispatch = execute
        }

        func remove() {
            self.eventMonitor?.removeObserver(self)
        }

        static func == (lhs: ExecutableStateObserver, rhs: ExecutableStateObserver) -> Bool {
            return lhs === rhs
        }
    }

    private var executableStateObservers: [ExecutableStateObserver] = []

    private var activeEventsByName: [Event.Name: Event] = [:]

    private let operationQueue = OperationQueue()

    private let dispatchQueue = DispatchQueue(label: "com.bintrail.eventMonitor")

    private var exclusiveNotificationObserversByName: [Notification.Name: NSObjectProtocol] = [:]

    private var nonExclusiveNotificationObservers: [NSObjectProtocol] = []

    init() {
        subscribeToAppNotifications()
    }

    func observeNotification(
        named notificationName: Notification.Name,
        object: Any? = nil,
        isExclusive: Bool,
        using block: @escaping (Notification) -> Void
    ) {
        let observer = NotificationCenter.default.addObserver(
            forName: notificationName,
            object: nil,
            queue: operationQueue,
            using: block
        )

        if isExclusive {
            exclusiveNotificationObserversByName[notificationName] = observer
        } else {
            nonExclusiveNotificationObservers.append(observer)
        }
    }

    func startEvent(
        named name: Event.Name,
        timestamp: Date = Date(),
        overwriteIfExits overwrite: Bool = true,
        cofigure block: ((Event) -> Void
    )? = nil) {
        if activeEventsByName[name] != nil && overwrite == false {
            return
        }
        dispatchQueue.async {
            let event = Event(name: name)
            self.activeEventsByName[name] = event
            block?(event)
        }
    }

    func endEvent(named name: Event.Name) {
        guard let event = activeEventsByName[name] else {
            return
        }

        dispatchQueue.async {
            self.activeEventsByName[name] = nil
            bt_event_finish(event)
        }
    }
}

extension EventMonitor {
    func addExecutableStateObserver(_ execute: @escaping (ExecutableState) -> Void) -> ExecutableStateObserver {
        let observer = ExecutableStateObserver(eventMonitor: self, execute: execute)
        executableStateObservers.append(observer)
        return observer
    }

    func removeObserver(_ observer: ExecutableStateObserver) {
        executableStateObservers = executableStateObservers.filter { other in
            other != observer
        }
    }

    private func notify(executableState: ExecutableState) {
        for observer in executableStateObservers {
            observer.dispatch(executableState)
        }
    }
}

private extension EventMonitor {
    private func subscribeToAppNotifications() {
        observeNotification(named: Application.willTerminateNotification, isExclusive: false) { _ in
        }

        observeNotification(named: Application.didBecomeActiveNotification, isExclusive: false) { [weak self] _ in
            self?.startEvent(named: .activePeriod)
            self?.endEvent(named: .inactivePeriod)
            self?.notify(executableState: .active)
        }

        observeNotification(named: Application.willResignActiveNotification, isExclusive: false) { [weak self] _ in
            self?.startEvent(named: .inactivePeriod)
            self?.endEvent(named: .activePeriod)
            self?.notify(executableState: .inactive)
        }

        #if canImport(UIKit)
        observeNotification(named: UIApplication.willEnterForegroundNotification, isExclusive: false) { _ in
            self.startEvent(named: .foregroundPeriod)
            self.endEvent(named: .backgroundPeriod)
        }

        observeNotification(named: UIApplication.didEnterBackgroundNotification, isExclusive: false) { _ in
            self.startEvent(named: .backgroundPeriod)
            self.endEvent(named: .foregroundPeriod)
        }

        observeNotification(named: UIApplication.didReceiveMemoryWarningNotification, isExclusive: false) { _ in
            bt_event_register(.memoryWarning)
        }
        #endif
    }
}
