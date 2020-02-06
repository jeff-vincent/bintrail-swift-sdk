import Dispatch
import Foundation

internal extension URL {
    static let bintrailBaseUrl = URL(
        string: ProcessInfo.processInfo.environment["BINTRAIL_URL"] ?? "https://data.bintrail.com"
    )!
}

public enum ClientError: Error {
    case ingestKeyPairMising
    case ingestKeyPairEncodingFailed

    case urlSessionTaskError(Error)

    case invalidURLResponse

    case unexpectedResponseStatus(Int)

    case underlying(Error)
}

internal class Client {
    internal struct Endpoint {
        let method: String
        let path: String
        let headers: [String: String]

        func url(withBaseUrl baseUrl: URL) -> URL {
            return baseUrl.appendingPathComponent(path)
        }

        static let sessionInit = Endpoint(
            method: "POST",
            path: "session/init",
            headers: [
                "Accept": "application/json",
                "Content-Type": "application/json"
            ]
        )

        static let putSessionEntries = Endpoint(
            method: "POST",
            path: "session/entries",
            headers: [
                "Accept": "application/json",
                "Content-Type": "application/json"
            ]
        )
    }

    internal struct IngestKeyPair {
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

    internal var ingestKeyPair: IngestKeyPair?

    private let dispatchQueue = DispatchQueue(label: "com.bintrail.client")

    private let urlSession = URLSession(configuration: .default)

    internal let baseUrl: URL

    internal init(baseUrl: URL) {
        self.baseUrl = baseUrl
    }
}

internal struct PutSessionEntriesRequest: Encodable {
    let logs: [Log]

    let events: [Event]

    let sessionId: String

    init<T: Sequence>(sessionId: String, entries: T) where T.Element == Session.Entry {
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

        self.sessionId = sessionId

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
    func upload(
        sessionMetadata: Session.Metadata,
        completion: @escaping (Result<InitializeSessionResponse, ClientError>) -> Void
    ) {
        send(
            endpoint: .sessionInit,
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
                    PutSessionEntriesRequest(
                        sessionId: remoteIdentifier,
                        entries: entries
                    )
                )

                self.send(endpoint: .putSessionEntries, body: data) { result in
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
            var urlRequest = URLRequest(url: endpoint.url(withBaseUrl: self.baseUrl))
            urlRequest.httpMethod = endpoint.method

            for (key, value) in endpoint.headers {
                urlRequest.setValue(value, forHTTPHeaderField: key)
            }

            guard let credentials = self.ingestKeyPair else {
                return completion(.failure(ClientError.ingestKeyPairMising))
            }

            guard let base64EncodedAppCredentials = credentials.base64EncodedString else {
                return completion(.failure(ClientError.ingestKeyPairEncodingFailed))
            }

            urlRequest.setValue(base64EncodedAppCredentials, forHTTPHeaderField: "Bintrail-Ingest-Token")
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
