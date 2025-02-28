import Foundation

public struct ProofOfPhoneNumberVerificationResponse: Decodable {
    let proofOfPhoneNumberVerification: String
}

public extension Latte {
    func getProofOfPhoneNumberVerification(
        handler: @escaping (Result<String, Error>) -> Void
    ) {
        authgear.refreshAccessTokenIfNeeded {(result) in
            if case let .failure(error) = result {
                handler(.failure(error))
            }

            var proofOfNumberVerificationEndpoint = self.middlewareEndpoint + "/proof_of_phone_number_verification"
            var request = URLRequest(url: URL(string: proofOfNumberVerificationEndpoint)!)
            request.httpMethod = "POST"

            let jsonEncoder = JSONEncoder()
            let body = try! jsonEncoder.encode([
                "access_token": self.authgear.accessToken
            ])
            request.httpBody = body

            authgearFetch(urlSession: self.urlSession, request: request) { result in
                switch result {
                case let .failure(error):
                    handler(.failure(error))
                case let .success((respData, _)):
                    do {
                        let decorder = JSONDecoder()
                        decorder.keyDecodingStrategy = .convertFromSnakeCase
                        let response = try decorder.decode(ProofOfPhoneNumberVerificationResponse.self, from: respData!)
                        handler(.success(response.proofOfPhoneNumberVerification))
                    } catch {
                        handler(.failure(error))
                    }
                }
            }
        }
    }
}
