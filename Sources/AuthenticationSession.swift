import AuthenticationServices
import SafariServices

protocol AuthenticationSession {
    typealias OpenEmailClientHandler = (UIViewController) -> Void
    typealias CompletionHandler = (Result<URL, Error>) -> Void
    @discardableResult func start() -> Bool
    func cancel()
}

extension SFAuthenticationSession: AuthenticationSession {}

@available(iOS 12.0, *)
extension ASWebAuthenticationSession: AuthenticationSession {}

@available(iOS 13.0, *)
extension WebViewSession: AuthenticationSession {}

class AuthenticationSessionProvider: NSObject, WebViewSessionDelegate {
    func makeAuthenticationSession(
        url: URL,
        redirectURI: String,
        prefersEphemeralWebBrowserSession: Bool?,
        uiVariant: UIVariant,
        openEmailClientHandler: @escaping AuthenticationSession.OpenEmailClientHandler,
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

        if #available(iOS 13.0, *) {
            if uiVariant == .wkWebView || uiVariant == .wkWebViewFullScreen {
                let session = WebViewSession(
                    url: url,
                    redirectURI: URL(string: redirectURI)!,
                    isFullScreenMode: uiVariant == .wkWebViewFullScreen,
                    openEmailClientHandler: openEmailClientHandler,
                    completionHandler: realCompletionHandler
                )
                session.delegate = self
                return session
            }
        }

        if #available(iOS 12.0, *) {
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
        } else {
            let session = SFAuthenticationSession(
                url: url,
                callbackURLScheme: getURIScheme(uri: redirectURI),
                completionHandler: realCompletionHandler
            )
            return session
        }
    }

    private func getURIScheme(uri: String) -> String {
        if let index = uri.firstIndex(of: ":") {
            return String(uri[..<index])
        }
        return uri
    }

    @available(iOS 13.0, *)
    func presentationAnchor(for: WebViewSession) -> UIWindow {
        UIApplication.shared.windows.filter { $0.isKeyWindow }.first!
    }

    @available(iOS 13.0, *)
    func webViewSessionWillPresent(_: WebViewSession) {}
}

extension AuthenticationSessionProvider: ASWebAuthenticationPresentationContextProviding {
    @available(iOS 13.0, *)
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.windows.filter { $0.isKeyWindow }.first!
    }
}
