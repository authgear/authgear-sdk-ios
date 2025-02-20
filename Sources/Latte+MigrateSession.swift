import Foundation

public struct MigratedSession: Decodable {
    let tokenType: String?
    let accessToken: String?
    let expiresIn: Int?
    let refreshToken: String?
}

public extension Latte {
    func migrateSession(
        accessToken: String,
        handler: @escaping (Result<UserInfo, Error>) -> Void
    ) {
        var migrationEndpoint = self.middlewareEndpoint + "/session_migration"
        var request = URLRequest(url: URL(string: migrationEndpoint)!)
        request.httpMethod = "POST"

        let deviceInfo = getDeviceInfo()
        let deviceInfoJSON = try! JSONEncoder().encode(deviceInfo)
        let xDeviceInfo = deviceInfoJSON.base64urlEncodedString()

        let jsonEncoder = JSONEncoder()
        let body = try! jsonEncoder.encode([
            "client_id": authgear.clientId,
            "access_token": accessToken,
            "device_info": xDeviceInfo
        ])
        request.httpBody = body

        authgearFetch(urlSession: urlSession, request: request) { result in
            switch result {
            case let .failure(error):
                handler(.failure(error))
            case let .success((respData, _)):
                do {
                    let decorder = JSONDecoder()
                    decorder.keyDecodingStrategy = .convertFromSnakeCase
                    let response = try decorder.decode(MigratedSession.self, from: respData!)
                    self.authgear.authenticateWithMigratedSession(migratedSession: response) { result in
                        switch result {
                        case let .failure(error):
                            handler(.failure(error))
                        case let .success(userInfo):
                            handler(.success(userInfo))
                        }
                    }
                } catch {
                    handler(.failure(error))
                }
            }
        }
    }
}
