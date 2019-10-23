import Foundation
import KSCrash

#if canImport(UIKit)
import UIKit
#endif

public enum BintrailError: Error {

    case appCredentialsMising
    case appCredentialsEncodingFailed

    case requestBodyEncodingFailed

    case urlSessionTaskError(Error)

    case invalidURLResponse
    case unexpectedResponseBody

    case unexpectedResponseStatus(accepted: Set<Int>, got: Int)

    case `internal`(Error)

    case unexpected

    case uninitializedExecutableInfo
    case uninitializedDeviceInfo
}

internal struct AppCredentials {
    let keyId: String
    let secret: String

    init(keyId: String, secret: String) {
        self.keyId = keyId
        self.secret = secret
    }

    var base64EncodedString: String? {
        let string = keyId + ":" + secret
        return string.data(using: .utf8)?.base64EncodedString()
    }
}

internal extension URL {
    static let bintrailBaseUrl = URL(string: "https://api.bintrail.com")!
}

public extension Bintrail {
    static let didAuthenticateSessionNotificationName = Notification.Name("BintrailDidAuthenticateSession")
}

public class Bintrail {

    public static let shared = Bintrail()

    @Synchronized private var managedEventsByType: [EventType: Event] = [:]

    private let crashReporter: CrashReporter

    internal private(set) var currentSession = Session()

    @Synchronized private var processingSessions: [Session] = []

    private let urlSession = URLSession(configuration: .default)

    private let dispatchQueue = DispatchQueue(label: "com.bintrail.async")

    private var notificationObservers: [Any] = []

    private let operationQueue = OperationQueue()

    private let jsonEncoder = JSONEncoder()

    private let jsonDecoder = JSONDecoder()

    private var timer: Timer?

    private var credentials: AppCredentials?

    private init() {
        jsonEncoder.dateEncodingStrategy = .millisecondsSince1970

        #if DEBUG
            jsonEncoder.outputFormatting = [.prettyPrinted]
        #endif

        if #available(iOS 11, *) {
            jsonEncoder.outputFormatting.insert(.sortedKeys)
        }

        jsonDecoder.dateDecodingStrategy = .millisecondsSince1970

        crashReporter = CrashReporter(jsonEncoder: jsonEncoder, jsonDecoder: jsonDecoder)

        operationQueue.underlyingQueue = dispatchQueue
    }

    var isConfigured: Bool {
        return credentials != nil
    }

    public func configure(keyId: String, secret: String) {

        guard isConfigured == false else {
            return
        }

        crashReporter.install()
        subscribeToNotifications()

        let credentials = AppCredentials(keyId: keyId, secret: secret)
        self.credentials = credentials

        async {
            self.flush(session: self.currentSession)
            self.sendCrashReports { result in
                print(result)
            }
        }

        timer = Timer.scheduledTimer(
            timeInterval: 30,
            target: self,
            selector: #selector(timerAction),
            userInfo: nil,
            repeats: true
        )
    }

    @objc
    private func timerAction() {
        async {
            self.flush()
        }
    }

    private func isProcessing(session: Session) -> Bool {
        processingSessions.contains(session)
    }

    private func beginProcessing(session: Session) -> Bool {
        guard isProcessing(session: session) == false else {
            return false
        }

        bt_debug("Begin processing for session.")
        processingSessions.append(session)
        return true
    }

    private func endProcessing(session: Session) {

        bt_debug("End processing for session.")
        processingSessions.removeAll { otherSession in
            session == otherSession
        }
    }

    private func flush() {
        flush(session: currentSession)
    }

    private func flush(session: Session) {

        bt_debug("Flushing session...")

        guard beginProcessing(session: session) else {
            bt_debug("Session is already processing. Skipping.")
            return
        }

        if let existingCredentials = session.credentials {
            bt_debug("Session has credentials previously set.")

            flushEvents(of: session, withCredentials: existingCredentials) { result in

                if case .failure(let error) = result {
                    bt_print("Failed to flush events for session:", error)
                }

                self.endProcessing(session: session)
            }

        } else {

            bt_debug("Session does not have credentials set. Authenticating...")

            authenticate(session: session) { result in
                switch result {
                case .success(let credentials):
                    session.credentials = credentials
                    self.crashReporter.userInfo.sessionId = credentials.sessionIdentifier
                case .failure(let error):
                    bt_print(error)
                }

                self.endProcessing(session: session)
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

private extension Bintrail {
    private func async(_ body: @escaping () -> Void) {
        dispatchQueue.async {
            body()
        }
    }
}

private extension Bintrail {
    func sendCrashReports(completion: @escaping (Result<Void, BintrailError>) -> Void) {

        do {
            guard let credentials = credentials else {
                throw BintrailError.appCredentialsMising
            }

            guard let base64EncodedAppCredentials = credentials.base64EncodedString else {
                throw BintrailError.appCredentialsEncodingFailed
            }

            var crashReports: [CrashReport] = []

            for crashReport in crashReporter {
                switch crashReport {
                case .success(let crashReport):
                    crashReports.append(crashReport)
                case .failure(let error):
                    bt_print("Failed to extract crash report", error)
                }
            }

            guard crashReports.isEmpty == false else {
                bt_print("No crash reports available. Not sending.")
                return
            }

            send(
                request: Request(
                    method: .post,
                    path: "ingest/crashreport/apple",
                    headers: ["Bintrail-Ingest-Token": base64EncodedAppCredentials],
                    body: crashReports.map { crashReport in
                        crashReport.body
                    },
                    encoder: self.jsonEncoder
                ),
                acceptStatusCodes: [202]) { result in
                    completion(result.map { _ in
                        // TODO: Re-enable
                        //self.crashReporter.deleteReports(withIdentifiers: crashReports.map { $0.identifier })
                    })
            }

        } catch let error as BintrailError {
            completion(.failure(error))
        } catch {
            completion(.failure(.internal(error)))
        }
    }
}

private extension Bintrail {

    func flushEvents(
        of session: Session,
        withCredentials credentials: SessionCredentials,
        completion: @escaping (Result<Void, BintrailError>) -> Void) {

        let events = session.events

        guard events.isEmpty == false else {
            bt_debug("Session has no events. Skipping event flush.")
            completion(.success(()))
            return
        }

        bt_debug("Flushing \(events.count) event(s) of session.")

        send(
            request: Request(
                method: .post,
                path: "session/ingest",
                headers: ["Authorization": "Bearer " + credentials.token],
                body: PutSessionEventBatchRequest(session.events),
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

    func authenticate(
        session: Session,
        completion: @escaping (Result<SessionCredentials, BintrailError>) -> Void
    ) {
        do {
            guard let credentials = credentials else {
                throw BintrailError.appCredentialsMising
            }

            guard let base64EncodedAppCredentials = credentials.base64EncodedString else {
                throw BintrailError.appCredentialsEncodingFailed
            }

            let completion: (Result<SessionCredentials, BintrailError>) -> Void = { result in
                NotificationCenter.default.post(name: Bintrail.didAuthenticateSessionNotificationName, object: session)
                completion(result)
            }

            guard let executable = crashReporter.executable else {
                throw BintrailError.uninitializedExecutableInfo
            }

            guard let device = crashReporter.device else {
                throw BintrailError.uninitializedDeviceInfo
            }

            send(
                request: Request(
                    method: .post,
                    path: "session/auth",
                    headers: ["Bintrail-Ingest-Token": base64EncodedAppCredentials],
                    body: SessionAuthRequest(executable: executable, device: device),
                    encoder: jsonEncoder
                ),
                acceptStatusCodes: [200],
                decodingResponseBodyTo: SessionCredentials.self,
                completion: completion
            )

        } catch let error as BintrailError {
            completion(.failure(error))
        } catch {
            completion(.failure(.internal(error)))
        }
    }
}

private extension Bintrail {

    func send<T: Decodable>(
        request: Request,
        acceptStatusCodes acceptedStatusCodes: Set<Int>,
        decodingResponseBodyTo responseBodyType: T.Type,
        completion: @escaping (Result<T, BintrailError>) -> Void
    ) {
        async {
            do {
                self.send(
                    urlRequest: try request.makeURLRequest(),
                    acceptStatusCodes: acceptedStatusCodes
                ) { result in
                    completion(result.flatMap { _, data in
                        do {
                            guard let data = data else {
                                throw BintrailError.unexpectedResponseBody
                            }

                            return .success(try self.jsonDecoder.decode(responseBodyType, from: data))

                        } catch let error as BintrailError {
                            return .failure(error)
                        } catch {
                            return .failure(.internal(error))
                        }
                    })
                }

            } catch {
                completion(.failure(.internal(error)))
            }
        }
    }

    func send(
        request: Request,
        acceptStatusCodes acceptedStatusCodes: Set<Int>,
        completion: @escaping (Result<Void, BintrailError>) -> Void
    ) {
        async {
            do {
                self.send(
                    urlRequest: try request.makeURLRequest(),
                    acceptStatusCodes: acceptedStatusCodes
                ) { result in
                    completion(result.map { _, _ in
                        return
                    })
                }
            } catch {
                completion(.failure(.internal(error)))
            }
        }
    }

    func send(
        urlRequest: URLRequest,
        acceptStatusCodes acceptedStatusCodes: Set<Int>,
        completion: @escaping (Result<(HTTPURLResponse, Data?), BintrailError>) -> Void
    ) {

        bt_debug("Sending URLRequest", urlRequest)

        urlSession.dataTask(with: urlRequest) { data, urlResponse, error in
            self.async {
                do {
                    if let error = error {
                        throw BintrailError.urlSessionTaskError(error)
                    }

                    guard let httpUrlResponse = urlResponse as? HTTPURLResponse else {
                        throw BintrailError.invalidURLResponse
                    }

                    guard acceptedStatusCodes.contains(httpUrlResponse.statusCode) else {

                        if let data = data, let string = String(data: data, encoding: .utf8) {
                            print(string)
                        }

                        throw BintrailError.unexpectedResponseStatus(
                            accepted: acceptedStatusCodes,
                            got: httpUrlResponse.statusCode
                        )
                    }

                    completion(.success((httpUrlResponse, data)))

                } catch let error as BintrailError {
                    completion(.failure(error))
                } catch {
                    completion(.failure(.internal(error)))
                }
            }
        }.resume()
    }
}
