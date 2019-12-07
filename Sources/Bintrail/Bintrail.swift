import Dispatch
import Foundation

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

public class Bintrail {
    public struct EventMonitoringOptions: OptionSet {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let verboseApplicationEvents = EventMonitoringOptions(rawValue: 1 << 0)

        #if os(iOS) || os(tvOS)
        public static let viewControllerLifecycle = EventMonitoringOptions(rawValue: 2 << 0)
        #endif
    }

    public static let shared = Bintrail()

    private let dispatchQueue = DispatchQueue(label: "com.bintrail")

    private var notificationObservers: [NSObjectProtocol] = []

    private let operationQueue = OperationQueue()

    private var applicationStateObserver: EventMonitor.Observer?

    private var timer: DispatchSourceTimer?

    internal let client: Client

    private var isSending = false

    internal private(set) var currentSession: Session

    private init() {
        client = Client(baseUrl: .bintrailBaseUrl)
        currentSession = Session(fileManager: .default)
        operationQueue.underlyingQueue = dispatchQueue
    }

    var isConfigured: Bool {
        return client.ingestKeyPair != nil
    }

    public func configure(keyId: String, secret: String, eventOptions: EventMonitoringOptions = []) throws {
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

        client.ingestKeyPair = Client.IngestKeyPair(keyId: keyId, secret: secret)

        bt_log("Bintrail SDK configured", type: .trace)

        applicationStateObserver = EventMonitor.addObserver { [weak self] state in
            var shouldWriteEnqueuedEntries = false

            switch state {
            case .applicationState(let applicationState):
                if case .inactive = applicationState {
                    shouldWriteEnqueuedEntries = true
                }
            case .termination:
                shouldWriteEnqueuedEntries = true
            }

            if shouldWriteEnqueuedEntries {
                do {
                    try self?.currentSession.writeEnqueuedEntriesToFile()
                } catch {
                    bt_log_internal("Failed to write enqueued entries to file when resigning active:", error)
                }
            }
        }

        EventMonitor.monitorApplicationEvents(verbose: eventOptions.contains(.verboseApplicationEvents))

        #if os(iOS) || os(tvOS)
        if eventOptions.contains(.viewControllerLifecycle) {
            Swizzling.applyToViewControllers()
        }
        #endif

        send(continuous: true)
    }

    private func scheduleSend(continuous: Bool) {
        // If a timer already exists, it means that one has already been scheduled to happen earlier
        // than the oner we're currently tasked with creating. Might as well use that one.
        if let timer = timer {
            timer.resume()
            return
        }

        let timer = DispatchSource.makeTimerSource(queue: dispatchQueue)
        timer.schedule(deadline: .now() + .seconds(5))
        timer.setEventHandler { [weak self] in
            // Trigger the send
            self?.send(continuous: true)

            // Pre-emptively destroy the timer
            self?.timer = nil
        }
        timer.resume()

        self.timer = timer
    }

    /// Processes current and saved sessions for sending
    func send(continuous: Bool) {
        dispatchQueue.async {
            let completion: ([Error?]) -> Void = { errors in
                // We're no longer sending
                self.isSending = false

                if !errors.isEmpty {
                    bt_log_internal("Errors occurred while sending sessions:", errors)
                }

                if continuous {
                    self.scheduleSend(continuous: continuous)
                }
            }

            // Cancel current timer if exists
            self.timer?.cancel()
            self.timer = nil

            // If we're flagged for sending, abort, and schedule a new send.
            guard !self.isSending else {
                self.scheduleSend(continuous: continuous)
                return
            }

            // Flag for sending
            self.isSending = true

            do {
                // Load all sessions. The current session will have its metadata saved via `configure()`
                var sessions = try Session.loadSaved(using: .default)

                // Make the current session write its enqueued entries to file
                try? self.currentSession.writeEnqueuedEntriesToFile()

                var errors: [Error] = []

                for session in sessions {
                    self.send(session: session) { error in
                        // Remove session from above created list of loaded sessions
                        // indicating thet the currently iterated session is done processing.
                        sessions.removeAll { other in
                            other == session
                        }

                        if let error = error {
                            errors.append(error)
                        }

                        // Above list of sessions is now empty. We're done.
                        if sessions.isEmpty {
                            completion(errors)
                        }
                    }
                }
            } catch {
                completion([error])
            }
        }
    }

    func send(session: Session, completion: @escaping (Error?) -> Void) {
        // Send session
        session.send(using: self.client) { error in
            self.dispatchQueue.async {
                if let error = error {
                    completion(error)
                    return
                }

                guard session != self.currentSession else {
                    completion(nil)
                    return
                }

                do {
                    try session.deleteSavedData()
                    bt_log_internal("Deleted saved data for session (\(session.localIdentifier))")
                    completion(nil)
                } catch {
                    completion(error)
                }
            }
        }
    }
}
