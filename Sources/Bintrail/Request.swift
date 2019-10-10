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

        if let body = urlRequest.httpBody {
            if let string = String(data: body, encoding: .utf8) {
                print("------------")
                print(string)
                print("!")
            }
        }

        return urlRequest
    }
}
