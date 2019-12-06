import Dispatch
import Foundation

#if canImport(UIKit)
import UIKit
#endif

public class Bintrail {
    public static let shared = Bintrail()

    @Synchronized private var managedEventsByName: [Event.Name: Event] = [:]

    private let operationQueue = OperationQueue()

    private let dispatchQueue = DispatchQueue(label: "com.bintrail")

    internal let client: Client

    internal private(set) var currentSession: Session

    private var timerDispatchWorkItem: DispatchWorkItem?

    private var notificationObservers: [Any] = []

    private init() {
        client = Client(baseUrl: .bintrailBaseUrl)
        currentSession = Session(fileManager: .default)

        operationQueue.underlyingQueue = dispatchQueue
    }

    var isConfigured: Bool {
        return client.ingestKeyPair != nil
    }

    public func configure(keyId: String, secret: String) throws {
        guard isConfigured == false else {
            return
        }

        try currentSession.saveMetadata(
            metadata: Session.Metadata(
                startedAt: Date(),
                device: .current,
                executable: .current
            )
        )

        subscribeToNotifications()

        client.ingestKeyPair = Client.IngestKeyPair(keyId: keyId, secret: secret)

        bt_log("Bintrail SDK configured", type: .trace)

        processNonCurrentSessions { errors in
            if !errors.isEmpty {
                bt_log_internal("Failed processing non-current session(s):", errors)
            }
        }
        startTimer()
    }
    private func stopTimer() {
        timerDispatchWorkItem?.cancel()
        timerDispatchWorkItem = nil
    }

    private func startTimer() {
        stopTimer()
        let newWorkItem = DispatchWorkItem { [weak self] in
            guard let weakSelf = self else {
                return
            }

            weakSelf.currentSession.send(using: weakSelf.client) { error in
                if let error = error {
                    bt_log_internal("Failed to send current session:", error)
                }

                weakSelf.startTimer()
            }
        }

        timerDispatchWorkItem = newWorkItem
        dispatchQueue.asyncAfter(deadline: .now() + 30, execute: newWorkItem)
    }

    func processNonCurrentSessions(completion: @escaping ([Error]) -> Void) {
        operationQueue.addOperation {
            do {
                var errors: [Error] = []

                var nonCurrentSessions = try Session.loadSaved(using: .default).filter { session in
                    session != self.currentSession
                }

                if nonCurrentSessions.isEmpty {
                    bt_log_internal("No non-current sessions need sending.")
                    completion(errors)
                    return
                }

                for session in nonCurrentSessions {
                    bt_log_internal("Processing non-current session \(session.localIdentifier)")

                    session.send(using: self.client) { error in
                        nonCurrentSessions = nonCurrentSessions.filter { otherSession in
                            session != otherSession
                        }

                        if let error = error {
                            errors.append(error)
                        } else {
                            try? session.deleteSavedData()
                        }

                        if nonCurrentSessions.isEmpty {
                            completion(errors)
                        }
                    }
                }
            } catch {
                completion([error])
            }
        }
    }
}

extension Bintrail {
    private func observeNotification(
        named notificationName: Notification.Name,
        object: Any? = nil,
        using block: @escaping (Notification) -> Void
    ) {
        let observer = NotificationCenter.default.addObserver(
            forName: notificationName,
            object: nil,
            queue: operationQueue,
            using: block
        )

        notificationObservers.append(observer)
    }

    private func startManagedEvent(
        named name: Event.Name,
        timestamp: Date = Date(),
        overwriteIfExits overwrite: Bool = true,
        cofigure block: ((Event) -> Void
    )? = nil) {
        if managedEventsByName[name] != nil && overwrite == false {
            return
        }

        let event = Event(name: name)
        managedEventsByName[name] = event
        block?(event)
    }

    private func endManagedEvent(named name: Event.Name) {
        guard let event = managedEventsByName[name] else {
            return
        }

        managedEventsByName[name] = nil
        bt_event_finish(event)
    }

    private func subscribeToNotifications() {
        #if canImport(UIKit)

        observeNotification(named: UIApplication.willTerminateNotification) { _ in
        }

        observeNotification(named: UIApplication.willResignActiveNotification) { _ in
            self.startManagedEvent(named: .inactivePeriod)
            self.endManagedEvent(named: .activePeriod)

            self.stopTimer()

            do {
                try self.currentSession.writeEnqueuedEntriesToFile()
            } catch {
                bt_log_internal("Failed to write enqueued entries to file when resigning active:", error)
            }
        }

        observeNotification(named: UIApplication.didBecomeActiveNotification) { _ in
            self.startManagedEvent(named: .activePeriod)
            self.endManagedEvent(named: .inactivePeriod)
            self.startTimer()
        }

        observeNotification(named: UIApplication.willEnterForegroundNotification) { _ in
            self.startManagedEvent(named: .foregroundPeriod)
            self.endManagedEvent(named: .backgroundPeriod)
        }

        observeNotification(named: UIApplication.didEnterBackgroundNotification) { _ in
            self.startManagedEvent(named: .backgroundPeriod)
            self.endManagedEvent(named: .foregroundPeriod)
        }

        observeNotification(named: UIApplication.didReceiveMemoryWarningNotification) { _ in
            bt_event_register(.memoryWarning)
        }

        #endif
    }
}
