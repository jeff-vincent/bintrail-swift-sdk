import Foundation

public enum BintrailError: Error {

    case appCredentialsMising
    case appCredentialsInvalid
    case appCredentialsEncodingFailed

    case requestBodyEncodingFailed

    case urlSessionTaskError(Error)

    case invalidURLResponse
    case unexpectedResponseBody

    case `internal`(Error)

    case unexpected
}

internal struct AppCredentials {
    let keyId: String
    let secret: String

    init(keyId: String, secret: String) {
        self.keyId = keyId
        self.secret = secret
    }

    var base64EncodedString: String? {
        return Data(base64Encoded: keyId + ":" + secret)?.base64EncodedString()
    }
}

internal extension URL {
    static let bintrailBaseUrl = URL(string: "http://localhost:5000")!
}

public class Bintrail {

    public static let shared = Bintrail()

    private var session = Session(timestamp: Date())

    private var processingSessions: [Session] = []

    private let urlSession = URLSession(configuration: .default)

    private var dispatchQueue = DispatchQueue(label: "com.bintrail.client")

    private let jsonEncoder = JSONEncoder()

    private let jsonDecoder = JSONDecoder()

    private var timer: Timer?

    private var credentials: AppCredentials?

    private init() {}

    var isConfigured: Bool {
        return credentials != nil
    }

    public func configure(keyId: String, secret: String) {

        guard isConfigured == false else {
            return
        }

        let credentials = AppCredentials(keyId: keyId, secret: secret)
        self.credentials = credentials

        NSSetUncaughtExceptionHandler { exception in
            if let existing = NSGetUncaughtExceptionHandler() {
                existing(exception)
            }
        }

        async {
            self.flush(session: self.session)
        }
    }

    private func isProcessing(session: Session) -> Bool {
        return processingSessions.contains(session)
    }

    private func beginProcessing(session: Session) -> Bool {
        guard isProcessing(session: session) == false else {
            return false
        }

        processingSessions.append(session)
        return true
    }

    private func endProcessing(session: Session) {
        processingSessions.removeAll { otherSession in
            session == otherSession
        }
    }

    private func flush(session: Session) {

        guard beginProcessing(session: session) else {
            return
        }

        if let existingCredentials = session.credentials {
            guard session.events.isEmpty == false else {
                endProcessing(session: session)
                return
            }

            send(
                request: Request(
                    method: .post,
                    path: "ingest/events",
                    headers: ["Authorization": "Bearer " + existingCredentials.token],
                    body: session.events,
                    encoder: self.jsonEncoder
                )
            ) { result in
                    self.endProcessing(session: session)

                    switch result {
                    case .success:
                        session.events = .empty
                    case .failure(let error):
                        self.print(error)
                    }
            }

        } else {
            authenticate(session: session) { result in
                switch result {
                case .success(let credentials):
                    session.credentials = credentials
                case .failure(let error):
                    self.print(error)
                }

                self.endProcessing(session: session)
                self.flush(session: session)
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
    func print(_ item: Any) {
        Swift.print("[BINTRAIL]", item)
    }
}

private extension Bintrail {

    enum RequestMethod: String {
        case post = "POST"
    }

    struct Request {
        let method: RequestMethod
        let path: String
        let headers: [String: String]
        let body: (() throws -> Data)?

        init(method: RequestMethod, path: String, headers: [String: String] = [:]) {
            self.method = method
            self.path = path
            self.headers = headers
            self.body = nil
        }

        init<U: Encodable>(
            method: RequestMethod,
            path: String,
            headers: [String: String] = [:],
            body: U,
            encoder: JSONEncoder
        ) {

            var headers = headers

            if headers.keys.contains(where: { $0.lowercased() == "content-type" }) == false {
                headers["Content-Type"] = "application/json"
            }

            self.method = method
            self.path = path
            self.headers = headers
            self.body = { try encoder.encode(body) }
        }

        func makeURLRequest() throws -> URLRequest {
            var urlRequest = URLRequest(url: URL.bintrailBaseUrl.appendingPathComponent(path))
            urlRequest.httpMethod = method.rawValue

            urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

            for (key, value) in headers {
                urlRequest.setValue(value, forHTTPHeaderField: key)
            }

            urlRequest.httpBody = try body?()

            return urlRequest
        }
    }
}

private extension Bintrail {

    private func authenticate(
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

            send(
                request: Request(
                    method: .post,
                    path: "auth/app",
                    headers: ["Bintrail-AppCredentials": base64EncodedAppCredentials],
                    body: SessionStartRequest(session),
                    encoder: jsonEncoder
                ),
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
        decodingResponseBodyTo responseBodyType: T.Type,
        completion: @escaping (Result<T, BintrailError>) -> Void
    ) {
        async {
            do {
                self.send(urlRequest: try request.makeURLRequest()) { result in
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
        completion: @escaping (Result<Void, BintrailError>) -> Void
    ) {
        async {
            do {
                self.send(urlRequest: try request.makeURLRequest()) { result in
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
        completion: @escaping (Result<(HTTPURLResponse, Data?), BintrailError>) -> Void
    ) {
        urlSession.dataTask(with: urlRequest) { data, urlResponse, error in
            self.async {
                do {
                    if let error = error {
                        throw BintrailError.urlSessionTaskError(error)
                    }

                    guard let httpUrlResponse = urlResponse as? HTTPURLResponse else {
                        throw BintrailError.invalidURLResponse
                    }

                    guard httpUrlResponse.statusCode != 200 else {
                        switch httpUrlResponse.statusCode {
                        case 401:
                            throw BintrailError.appCredentialsInvalid
                        default:
                            throw BintrailError.unexpected
                        }
                    }

                    completion(.success((httpUrlResponse, data)))

                } catch let error as BintrailError {
                    completion(.failure(error))
                } catch {
                    completion(.failure(.internal(error)))
                }
            }
        }
    }
}
