import Foundation
import KSCrash

#if canImport(UIKit)
import UIKit
#endif

public enum BintrailError: Error {
    case uninitializedDeviceInfo
    case uninitializedExecutableInfo
    case client(ClientError)
}

public class Bintrail {

    public static let shared = Bintrail()

    @Synchronized private var managedEventsByType: [EventType: Event] = [:]

    internal let crashReporter: CrashReporter

    internal let client: Client

    internal private(set) var currentSession: Session

    private var timer: Timer?

    private var notificationObservers: [Any] = []

    private init() {
        client = Client(baseUrl: .bintrailBaseUrl)
        crashReporter = CrashReporter()

        currentSession = Session(fileManager: .default)
    }

    var isConfigured: Bool {
        return client.credentials != nil
    }

    public func configure(keyId: String, secret: String) {

        guard isConfigured == false else {
            return
        }

        crashReporter.install()
        subscribeToNotifications()

        do {
            try currentSession.saveMetadata(
                metadata: Session.Metadata(
                    startedAt: Date(),
                    device: crashReporter.device,
                    executable: crashReporter.executable
                )
            )
        } catch {
            bt_log_internal("Failed to save session metadata", error)
        }

        client.credentials = Client.Credentials(keyId: keyId, secret: secret)

        bt_log("Bintrail SDK configured", type: .trace)
        startTimer()
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(
            timeInterval: 30,
            target: self,
            selector: #selector(timerAction(sender:)),
            userInfo: nil,
            repeats: true
        )
    }

    @objc
    private func timerAction(sender: Timer) {
        do {
            try dump()
        } catch {
            bt_print("Failed to load sessions")
        }
    }

    func dump() throws {
        for session in try Session.loadSaved(using: .default) {
            session.send(using: client) { error in
                if session != self.currentSession {
                    do {
                        try session.deleteSavedData()
                    } catch {
                        bt_log_internal("Failed to delete session data", error)
                    }
                }
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
            queue: nil, // TODO: Operation queue
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
        }

        observeNotification(named: UIApplication.didBecomeActiveNotification) { _ in
            kscrash_notifyAppActive(true)

            self.startManagedEvent(withType: .activePeriod)
            self.endManagedEvent(withType: .inactivePeriod)
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
