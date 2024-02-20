import AuthenticationServices

public class ASWebAuthenticationSessionUIImplementation: NSObject, UIImplementation, ASWebAuthenticationPresentationContextProviding {
    public func openAuthorizationURL(url: URL, redirectURI: URL, shareCookiesWithDeviceBrowser: Bool, completion: @escaping CompletionHandler) {
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: redirectURI.scheme!) { url, error in
            if let error = error {
                completion(.failure(wrapError(error: error)))
            }
            if let url = url {
                completion(.success(url))
            }
        }
        if #available(iOS 13.0, *) {
            session.prefersEphemeralWebBrowserSession = !shareCookiesWithDeviceBrowser
            session.presentationContextProvider = self
        }
        session.start()
    }

    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.windows.filter { $0.isKeyWindow }.first!
    }
}
