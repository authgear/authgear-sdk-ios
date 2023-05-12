import Foundation

extension Latte {
    func tokenize(
        data: Data,
        handler: @escaping (Result<String, Error>) -> Void
    ) {
        var request = URLRequest(url: URL(string: tokenizeEndpoint)!)
        request.httpMethod = "POST"
        request.httpBody = data
        authgearFetch(urlSession: urlSession, request: request) { result in
            switch result {
            case let .failure(error):
                handler(.failure(error))
            case let .success((respData, _)):
                guard let respData = respData,
                      let token = String(data: respData, encoding: String.Encoding.utf8) else {
                    handler(.failure(
                        wrapError(
                            error: LatteError.unexpected(message: "unexpected response from tokenize api"))))
                    return
                }
                handler(.success(token))
            }
        }
    }
}
