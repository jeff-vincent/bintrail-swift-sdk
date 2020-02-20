import Dispatch
import Foundation

internal extension URL {
    static var bintrailApiBaseUrl: URL {
        URL(
            string: ProcessInfo.processInfo.environment["BINTRAIL_API_URL"] ?? "https://api.bintrail.com"
        )!
    }

    static var bintrailDataApiBaseUrl: URL {
        URL(
            string: ProcessInfo.processInfo.environment["BINTRAIL_DATA_API_URL"] ?? "https://data.bintrail.com"
        )!
    }
}

/// Error type for client
public enum ClientError: Error {
    /// An ingest key pair is missing, and the client cannot authorize sessions
    case ingestKeyPairMising

    /// Encoding of ingest key pair failed
    case ingestKeyPairEncodingFailed

    /// Error forward from URLSession
    case urlSessionTaskError(Error)

    /// The response received was of an unacceptable type
    case invalidURLResponse

    /// The response status received was unexpected
    case unexpectedResponseStatus(Int)

    /// Other underlying errors
    case underlying(Error)
}

internal class Client {
    /// Represents a Bintrail resource endpoint
    internal struct Endpoint {
        /// Base URL of the endpoint
        let baseUrl: URL

        /// HTTP request method to use for this endpoint
        let method: String

        /// Path for the endpoint
        let path: String

        /// Default headers for the endpoint
        let defaultHeaders: [String: String]

        /// Indicates whether the endpoint requires authorization
        let requiresAuthorization: Bool

        var url: URL {
            URL(string: path, relativeTo: baseUrl)!
        }

        /// Session ingestion endpoint
        static let sessionIngest = Endpoint(
            baseUrl: .bintrailDataApiBaseUrl,
            method: "POST",
            path: "ingest/session",
            defaultHeaders: [
                "Accept": "application/json",
                "Content-Type": "application/json"
            ],
            requiresAuthorization: true
        )

        /// Session entry ingest endpoint
        /// - Parameter sessionId: Remote identifier of the session
        static func sessionEntryIngest(sessionId: String) -> Endpoint {
            Endpoint(
                baseUrl: .bintrailDataApiBaseUrl,
                method: "POST",
                path: ["ingest", "session", sessionId, "entries"].joined(separator: "/"),
                defaultHeaders: [
                    "Accept": "application/json",
                    "Content-Type": "application/json"
                ],
                requiresAuthorization: true
            )
        }

        /// Ingest key pair authorization endpoint
        static let authorize = Endpoint(
            baseUrl: .bintrailApiBaseUrl,
            method: "POST",
            path: "authorize/ingest-key-pair",
            defaultHeaders: [
                "Accept": "application/json",
                "Content-Type": "application/json"
            ],
            requiresAuthorization: false
        )
    }

    /// Represents an ingest key pair
    internal struct IngestKeyPair: Encodable {
        /// Ingest key pair key id
        let keyId: String

        /// Ingest key pair secret
        let secret: String

        /// Creates a new ingest key pair
        /// - Parameters:
        ///   - keyId:  Ingest key pair id
        ///   - secret: Ingest key pair secret
        init(keyId: String, secret: String) {
            self.keyId = keyId
            self.secret = secret
        }
    }

    /// JWT access token received in exchange for a valid
    /// ingest key pair
    internal struct AccessToken {
        /// JWT Token
        let token: String
        /// JWT Token expiry date
        let expiresAt: Date
        /// JWT bearer type
        let type: String
    }

    /// Ingest key pair assigned by the implementing executable
    internal var ingestKeyPair: IngestKeyPair?

    /// Access token received from the Bintrail API
    internal var accessToken: AccessToken?

    /// Client dispatch queue
    private let dispatchQueue = DispatchQueue(label: "com.bintrail.client")

    /// Client URL session
    private let urlSession = URLSession(configuration: .default)

    internal typealias AuthorizeCompletionHandler = (Result<Void, ClientError>) -> Void

    private var authorizeCompletionHandler: AuthorizeCompletionHandler?
}

internal struct SessionEntryIngestRequest: Encodable {
    let logs: [Log]

    let events: [Event]

    init<T: Sequence>(entries: T) where T.Element == Session.Entry {
        var logs: [Log] = []
        var events: [Event] = []

        for entry in entries {
            switch entry {
            case .log(let entry):
                logs.append(entry)
            case .event(let entry):
                events.append(entry)
            }
        }

        self.logs = logs
        self.events = events
    }
}

internal struct InitializeSessionRequest: Encodable {
    let executable: Executable?

    let device: Device?

    let startedAt: Date

    init(metadata: Session.Metadata) {
        executable = metadata.executable
        device = metadata.device
        startedAt = metadata.startedAt
    }
}

internal struct InitializeSessionResponse: Decodable {
    enum CodingKeys: String, CodingKey {
        case remoteIdentifier = "sessionId"
    }

    let remoteIdentifier: String
}

internal extension Client {
    func authorize(
        ingestKeyPair: IngestKeyPair,
        completion: @escaping AuthorizeCompletionHandler
    ) {
        guard let authorizeCompletionHandler = authorizeCompletionHandler else {
            self.authorizeCompletionHandler = completion

            send(endpoint: .authorize, requestBody: ingestKeyPair, responseBody: AccessToken.self) { result in
                self.authorizeCompletionHandler?(result.map { result in
                    let (_, accessToken) = result
                    self.accessToken = accessToken
                    self.authorizeCompletionHandler = nil
                })
            }
            return
        }

        self.authorizeCompletionHandler = { result in
            authorizeCompletionHandler(result)
            completion(result)
        }
    }

    func upload(
        sessionMetadata: Session.Metadata,
        completion: @escaping (Result<InitializeSessionResponse, ClientError>) -> Void
    ) {
        send(
            endpoint: .sessionIngest,
            requestBody: InitializeSessionRequest(metadata: sessionMetadata),
            responseBody: InitializeSessionResponse.self
        ) { result in
            completion(
                result.map { _, body in
                    body
                }
            )
        }
    }

    func upload<T>(
        entries: T,
        forSessionWithRemoteIdentifier remoteIdentifier: String,
        completion: @escaping (Result<Void, ClientError>) -> Void
    ) where T: Sequence, T.Element == Session.Entry {
        dispatchQueue.async {
            do {
                let data = try JSONEncoder.bintrailDefault.encode(
                    SessionEntryIngestRequest(
                        entries: entries
                    )
                )

                self.send(endpoint: .sessionEntryIngest(sessionId: remoteIdentifier), body: data) { result in
                    switch result {
                    case .success:
                        completion(.success(()))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            } catch {
                completion(.failure(.underlying(error)))
            }
        }
    }

    private func send<T, U>(
        endpoint: Endpoint,
        requestBody: T,
        responseBody: U.Type,
        completion: @escaping (Result<(HTTPURLResponse, U), ClientError>) -> Void
    ) where T: Encodable, U: Decodable {
        dispatchQueue.async {
            do {
                self.send(endpoint: endpoint, body: try JSONEncoder.bintrailDefault.encode(requestBody)) { result in
                    do {
                        let (response, data) = try result.get()
                        completion(
                            .success((response, try JSONDecoder.bintrailDefault.decode(responseBody, from: data)))
                        )
                    } catch let error as ClientError {
                        completion(.failure(error))
                    } catch {
                        completion(.failure(.underlying(error)))
                    }
                }
            } catch {
                completion(.failure(.underlying(error)))
            }
        }
    }

    private func send(
        endpoint: Endpoint,
        body: Data?,
        completion: @escaping (Result<(HTTPURLResponse, Data), ClientError>) -> Void
    ) {
        dispatchQueue.async {
            var urlRequest = URLRequest(url: endpoint.url)
            urlRequest.httpMethod = endpoint.method

            for (key, value) in endpoint.defaultHeaders {
                urlRequest.setValue(value, forHTTPHeaderField: key)
            }

            if endpoint.requiresAuthorization {
                guard let accessToken = self.accessToken, accessToken.expiresAt.timeIntervalSinceNow > 0 else {
                    guard let ingestKeyPair = self.ingestKeyPair else {
                        return completion(.failure(ClientError.ingestKeyPairMising))
                    }

                    self.authorize(ingestKeyPair: ingestKeyPair) { result in
                        switch result {
                        case .failure(let error):
                            completion(.failure(error))
                        case .success:
                            self.send(endpoint: endpoint, body: body, completion: completion)
                        }
                    }
                    return
                }

                urlRequest.setValue("Bearer " + accessToken.token, forHTTPHeaderField: "Authorization")
            }

            urlRequest.httpBody = body

            self.send(urlRequest: urlRequest, completion: completion)
        }
    }

    private func send(
        urlRequest: URLRequest,
        completion: @escaping (Result<(HTTPURLResponse, Data), ClientError>) -> Void
    ) {
        bt_log_internal("Sending URLRequest \(urlRequest)")

        urlSession.dataTask(with: urlRequest) { data, urlResponse, error in
            if let error = error {
                return completion(.failure(ClientError.urlSessionTaskError(error)))
            }

            guard let httpUrlResponse = urlResponse as? HTTPURLResponse else {
                return completion(.failure(ClientError.invalidURLResponse))
            }

            guard (200 ..< 300).contains(httpUrlResponse.statusCode) else {
                return completion(.failure(ClientError.unexpectedResponseStatus(httpUrlResponse.statusCode)))
            }

            completion(.success((httpUrlResponse, data ?? Data())))
        }.resume()
    }
}

extension Client.AccessToken: Decodable {
    public enum CodingKeys: String, CodingKey {
        case token
        case expiresIn
        case type = "tokenType"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        token = try container.decode(String.self, forKey: .token)
        expiresAt = Date().addingTimeInterval(try container.decode(TimeInterval.self, forKey: .expiresIn))
        type = try container.decode(String.self, forKey: .type)
    }
}
