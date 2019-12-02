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

    internal private(set) var currentSession = Session()

    private var notificationObservers: [Any] = []

    private init() {
        client = Client(baseUrl: .bintrailBaseUrl)
        crashReporter = CrashReporter(jsonEncoder: client.jsonEncoder, jsonDecoder: client.jsonDecoder)
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

        client.credentials = Client.Credentials(keyId: keyId, secret: secret)

        bt_log("Bintrail SDK configured", type: .trace)
    }
}


private extension Bintrail {

    func flushEvents(
        of session: Session,
        withCredentials credentials: Credentials,
        completion: @escaping (Result<Void, BintrailError>) -> Void) {

        let events = session.events

        guard let base64EncodedAppCredentials = credentials.base64EncodedString else {
            completion(.failure(ClientError.appCredentialsEncodingFailed))
            return
        }

        guard events.isEmpty == false else {
            bt_debug("Session has no events. Skipping event flush.")
            completion(.success(()))
            return
        }

        guard let context = session.context else {
            fetchSessionContext(session: session) { result in
                switch result {
                case .success(let context):
                    session.context = context

                    if session === self.currentSession {
                        self.crashReporter.userInfo.sessionId = context.sessionId
                    }

                    self.async {
                        self.flushEvents(of: session, withCredentials: credentials, completion: completion)
                    }

                case .failure(let error):
                    completion(.failure(error))
                }
            }
            return
        }

        bt_debug("Flushing \(events.count) event(s) of session.")

        send(
            request: Request(
                method: .post,
                path: "session/ingest",
                headers: ["Bintrail-Ingest-Token": base64EncodedAppCredentials],
                body: PutSessionEventBatchRequest(
                    appId: context.appId,
                    sessionId: context.sessionId,
                    sessionEvents: session.events
                ),
                encoder: self.jsonEncoder
            ),
            acceptStatusCodes: [202]
        ) { result in

            completion(
                result.map {
                    bt_debug("Successfully flushed \(events.count) event(s) of session.")
                    session.dequeueEvents(count: events.count)
                }
            )
        }
    }

    func fetchSessionContext(
        session: Session,
        completion: @escaping (Result<Session.Context, BintrailError>) -> Void
    ) {
        do {

            guard let executable = crashReporter.executable else {
                throw BintrailError.uninitializedExecutableInfo
            }

            guard let device = crashReporter.device else {
                throw BintrailError.uninitializedDeviceInfo
            }

            client.send(
                endpoint: .sessionInit,
                requestBody: SessionAuthRequest(executable: executable, device: device),
                responseBody: Session.Context.self) { response in

            }

            send(
                request: Request(
                    method: .post,
                    path: "session/init",
                    headers: ["Bintrail-Ingest-Token": base64EncodedAppCredentials],
                    body: SessionAuthRequest(executable: executable, device: device),
                    encoder: jsonEncoder
                ),
                acceptStatusCodes: [200],
                decodingResponseBodyTo: Session.Context.self,
                completion: completion
            )

        } catch let error as ClientError {
            completion(.failure(error))
        } catch {
            completion(.failure(.internal(error)))
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



