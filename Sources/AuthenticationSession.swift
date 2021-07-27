import AuthenticationServices
import SafariServices

protocol AuthenticationSession {
    typealias CompletionHandler = (Result<URL, Error>) -> Void
    @discardableResult func start() -> Bool
    func cancel()
}

extension SFAuthenticationSession: AuthenticationSession {}

@available(iOS 12.0, *)
extension ASWebAuthenticationSession: AuthenticationSession {}

class AuthenticationSessionProvider: NSObject {
    func makeAuthenticationSession(
        url: URL,
        callbackURLSchema: String,
        prefersEphemeralWebBrowserSession: Bool?,
        completionHandler: @escaping AuthenticationSession.CompletionHandler
    ) -> AuthenticationSession {
        let handler: (URL?, Error?) -> Void = { (url: URL?, error: Error?) in
            if let error = error {
                if #available(iOS 12.0, *) {
                    if let asError = error as? ASWebAuthenticationSessionError,
                       asError.code == ASWebAuthenticationSessionError.canceledLogin {
                        return completionHandler(.failure(AuthgearError.cancel))
                    }
                } else {
                    if let sfError = error as? SFAuthenticationError,
                       sfError.code == SFAuthenticationError.canceledLogin {
                        return completionHandler(.failure(AuthgearError.cancel))
                    }
                }
                return completionHandler(.failure(AuthgearError.error(error)))
            }

            if let url = url {
                return completionHandler(.success(url))
            }
        }
        if #available(iOS 12.0, *) {
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackURLSchema,
                completionHandler: handler
            )

            if #available(iOS 13.0, *) {
                session.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession ?? false
                session.presentationContextProvider = self
            }

            return session
        } else {
            let session = SFAuthenticationSession(
                url: url,
                callbackURLScheme: callbackURLSchema,
                completionHandler: handler
            )
            return session
        }
    }
}

extension AuthenticationSessionProvider: ASWebAuthenticationPresentationContextProviding {
    @available(iOS 13.0, *)
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.windows.filter { $0.isKeyWindow }.first!
    }
}
