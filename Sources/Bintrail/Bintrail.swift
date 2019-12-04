import Foundation
import KSCrash

#if canImport(UIKit)
import UIKit
#endif

public enum BintrailError: Error {
    case uninitializedDeviceInfo
    case uninitializedExecutableInfo
}

public class Bintrail {

    public static let shared = Bintrail()

    @Synchronized private var managedEventsByType: [EventType: Event] = [:]

    private let operationQueue = OperationQueue()

    private let dispatchQueue = DispatchQueue(label: "com.bintrail")

    internal let crashReporter: CrashReporter

    internal let client: Client

    internal private(set) var currentSession: Session

    private var timerDispatchWorkItem: DispatchWorkItem?

    private var notificationObservers: [Any] = []

    private init() {
        client = Client(baseUrl: .bintrailBaseUrl)
        crashReporter = CrashReporter()
        currentSession = Session(fileManager: .default)

        operationQueue.underlyingQueue = dispatchQueue
    }

    var isConfigured: Bool {
        return client.credentials != nil
    }

    public func configure(keyId: String, secret: String) throws {

        guard isConfigured == false else {
            return
        }

        crashReporter.install()

        guard let device = crashReporter.device else {
            throw BintrailError.uninitializedDeviceInfo
        }

        guard let executable = crashReporter.executable else {
            throw BintrailError.uninitializedExecutableInfo
        }

        try currentSession.saveMetadata(
            metadata: Session.Metadata(
                startedAt: Date(),
                device: device,
                executable: executable
            )
        )

        subscribeToNotifications()

        client.credentials = Client.Credentials(keyId: keyId, secret: secret)

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
        withType type: EventType,
        timestamp: Date = Date(),
        overwriteIfExits overwrite: Bool = true,
        cofigure block: ((Event) -> Void
    )? = nil) {

        if managedEventsByType[type] != nil && overwrite == false {
            return
        }

        let event = Event(type: type)
        managedEventsByType[type] = event
        block?(event)
    }

    private func endManagedEvent(withType type: EventType) {
        guard let event = managedEventsByType[type] else {
            return
        }

        managedEventsByType[type] = nil
        bt_event_finish(event)
    }

    private func subscribeToNotifications() {

        observeNotification(named: UIApplication.willTerminateNotification) { _ in
            kscrash_notifyAppTerminate()
        }

        observeNotification(named: UIApplication.willResignActiveNotification) { _ in
            kscrash_notifyAppActive(false)

            self.startManagedEvent(withType: .inactivePeriod)
            self.endManagedEvent(withType: .activePeriod)

            self.stopTimer()

            do {
                try self.currentSession.writeEnqueuedEntriesToFile()
            } catch {
                bt_log_internal("Failed to write enqueued entries to file when resigning active:", error)
            }
        }

        observeNotification(named: UIApplication.didBecomeActiveNotification) { _ in
            kscrash_notifyAppActive(true)

            self.startManagedEvent(withType: .activePeriod)
            self.endManagedEvent(withType: .inactivePeriod)
            self.startTimer()
        }

        observeNotification(named: UIApplication.willEnterForegroundNotification) { _ in
            kscrash_notifyAppInForeground(true)

            self.startManagedEvent(withType: .foregroundPeriod)
            self.endManagedEvent(withType: .backgroundPeriod)
        }

        observeNotification(named: UIApplication.didEnterBackgroundNotification) { _ in
            kscrash_notifyAppInForeground(false)

            self.startManagedEvent(withType: .backgroundPeriod)
            self.endManagedEvent(withType: .foregroundPeriod)
        }

        observeNotification(named: UIApplication.didReceiveMemoryWarningNotification) { _ in
            bt_event_register(.memoryWarning) { event in

                if let memory = self.crashReporter.device?.memory {
                    event.add(metric: memory.size, for: "size")
                    event.add(metric: memory.free, for: "free")
                    event.add(metric: memory.usable, for: "memory")
                }
            }
        }
    }
}
