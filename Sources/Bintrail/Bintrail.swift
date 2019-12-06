import Dispatch
import Foundation

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

public class Bintrail {
    public static let shared = Bintrail()

    private let dispatchQueue = DispatchQueue(label: "com.bintrail")

    private var notificationObservers: [NSObjectProtocol] = []

    private let operationQueue = OperationQueue()

    private let eventMonitor = EventMonitor()

    private var executableStateObserver: EventMonitor.ExecutableStateObserver?

    internal let client: Client

    internal private(set) var currentSession: Session

    private var timerWorkItem: DispatchWorkItem?

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

        client.ingestKeyPair = Client.IngestKeyPair(keyId: keyId, secret: secret)

        bt_log("Bintrail SDK configured", type: .trace)

        processNonCurrentSessions { errors in
            if !errors.isEmpty {
                bt_log_internal("Failed processing non-current session(s):", errors)
            }
        }

        executableStateObserver = eventMonitor.addExecutableStateObserver { [weak self] state in
            switch state {
            case .active:
                self?.resume()
            case .inactive:
                self?.suspend()
            }
        }

        resume()
    }

    private func suspend() {
        timerWorkItem?.cancel()
        timerWorkItem = nil

        do {
            try currentSession.writeEnqueuedEntriesToFile()
        } catch {
            bt_log_internal("Failed to write enqueued entries to file when resigning active:", error)
        }
    }

    private func resume() {
        suspend()
        let newWorkItem = DispatchWorkItem { [weak self] in
            guard let weakSelf = self else {
                return
            }

            weakSelf.currentSession.send(using: weakSelf.client) { error in
                if let error = error {
                    bt_log_internal("Failed to send current session:", error)
                }

                weakSelf.resume()
            }
        }

        timerWorkItem = newWorkItem
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
