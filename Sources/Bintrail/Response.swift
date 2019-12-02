internal class Response {

    let request: Request

    let headers: [String: String]

    let statusCode: Int

    let data: Data?

    private let jsonDecoder: JSONDecoder

    init(request: Request, httpUrlResponse: HTTPURLResponse, data: Data?) {
        self.request = request
        self.headers = Dictionary(uniqueKeysWithValues: httpUrlResponse.allHeaderFields.map { key, value in
            (String(describing: key), String(describing: value))
        })
        self.statusCode = httpUrlResponse.statusCode
        self.data = data
    }
}
