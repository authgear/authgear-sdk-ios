import AuthenticationServices

protocol AuthenticationSession {
    typealias CompletionHandler = (Result<URL, Error>) -> Void
    @discardableResult func start() -> Bool
    func cancel()
}

extension ASWebAuthenticationSession: AuthenticationSession {}

class AuthenticationSessionProvider: NSObject {
    func makeAuthenticationSession(
        url: URL,
        redirectURI: String,
        prefersEphemeralWebBrowserSession: Bool?,
        completionHandler: @escaping AuthenticationSession.CompletionHandler
    ) -> AuthenticationSession {
        let realCompletionHandler: (URL?, Error?) -> Void = { (url: URL?, error: Error?) in
            if let error = error {
                return completionHandler(.failure(wrapError(error: error)))
            }

            if let url = url {
                return completionHandler(.success(url))
            }
        }

        let session = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: getURIScheme(uri: redirectURI),
            completionHandler: realCompletionHandler
        )

        if #available(iOS 13.0, *) {
            session.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession ?? false
            session.presentationContextProvider = self
        }

        return session
    }

    private func getURIScheme(uri: String) -> String {
        if let index = uri.firstIndex(of: ":") {
            return String(uri[..<index])
        }
        return uri
    }
}

extension AuthenticationSessionProvider: ASWebAuthenticationPresentationContextProviding {
    @available(iOS 13.0, *)
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.windows.filter { $0.isKeyWindow }.first!
    }
}
