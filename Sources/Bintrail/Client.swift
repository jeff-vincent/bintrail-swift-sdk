internal extension URL {
    static let bintrailBaseUrl = URL(string: "http://localhost:5000")!
}

public enum ClientError: Error {

    case appCredentialsMising
    case appCredentialsEncodingFailed

    case requestBodyEncodingFailed

    case urlSessionTaskError(Error)

    case invalidURLResponse
    case unexpectedResponseBody

    case unexpectedResponseStatus(Int)

    case `internal`(Error)

    case unexpected

    case uninitializedExecutableInfo
    case uninitializedDeviceInfo
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
    }

    internal struct Credentials {
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

    internal var credentials: Credentials?

    private let dispatchQueue = DispatchQueue(label: "com.bintrail.client")

    private let urlSession = URLSession(configuration: .default)

    internal let baseUrl: URL

    internal init(baseUrl: URL) {

        self.baseUrl = baseUrl
    }
}

internal extension Client {

    struct EmptyHttpBody: Codable {}

    func send<T, U>(
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
                        completion(.failure(.internal(error)))
                    }
                }
            } catch {
                completion(.failure(.internal(error)))
            }
        }
    }

    private func send(
        endpoint: Endpoint,
        body: Data?,
        completion: @escaping (Result<(HTTPURLResponse, Data), ClientError>) -> Void
    ) {
        dispatchQueue.async {

            do {
                var urlRequest = URLRequest(url: endpoint.url(withBaseUrl: self.baseUrl))
                urlRequest.httpMethod = endpoint.method

                for (key, value) in endpoint.headers {
                    urlRequest.setValue(value, forHTTPHeaderField: key)
                }

                guard let credentials = self.credentials else {
                    throw ClientError.appCredentialsMising
                }

                guard let base64EncodedAppCredentials = credentials.base64EncodedString else {
                    throw ClientError.appCredentialsEncodingFailed
                }

                urlRequest.setValue(base64EncodedAppCredentials, forHTTPHeaderField: "Bintrail-Ingest-Token")
                urlRequest.httpBody = body

                self.send(urlRequest: urlRequest, completion: completion)

            } catch let error as ClientError {
                completion(.failure(error))
            } catch {
                completion(.failure(.internal(error)))
            }
        }
    }

    private func send(
        urlRequest: URLRequest,
        completion: @escaping (Result<(HTTPURLResponse, Data), ClientError>) -> Void
    ) {

        bt_debug("Sending URLRequest", urlRequest)

        urlSession.dataTask(with: urlRequest) { data, urlResponse, error in
            do {
                if let error = error {
                    throw ClientError.urlSessionTaskError(error)
                }

                guard let httpUrlResponse = urlResponse as? HTTPURLResponse else {
                    throw ClientError.invalidURLResponse
                }

                guard (200 ..< 300).contains(httpUrlResponse.statusCode) else {
                    // TODO: Remove me
                    if let data = data, let string = String(data: data, encoding: .utf8) {
                        print(string)
                    }

                    throw ClientError.unexpectedResponseStatus(httpUrlResponse.statusCode)
                }

                completion(.success((httpUrlResponse, data ?? Data())))

            } catch let error as ClientError {
                completion(.failure(error))
            } catch {
                completion(.failure(.internal(error)))
            }
        }.resume()
    }
}
