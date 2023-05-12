import Foundation
import UIKit

public protocol LatteDelegate: AnyObject {
    func latte(_: Latte, onTrackingEvent: LatteTrackingEvent)
}

public class Latte: LatteWebViewDelegate {
    let authgear: Authgear
    let customUIEndpoint: String
    let urlSession: URLSession
    let webviewIsInspectable: Bool
    public weak var delegate: LatteDelegate?

    public init(authgear: Authgear, customUIEndpoint: String, webviewIsInspectable: Bool = false) {
        self.authgear = authgear
        self.customUIEndpoint = customUIEndpoint
        self.webviewIsInspectable = webviewIsInspectable
        self.urlSession = URLSession(configuration: .default)
    }

    @available(iOS 13.0, *)
    func latteWebView(onEvent webView: LatteWKWebView, event: LatteWebViewEvent) {
        switch event {
        case let .trackingEvent(event: event):
            self.delegate?.latte(_: self, onTrackingEvent: event)
        case .openEmailClient:
            // FIXME: This should be handled by the SDK user.
            let items = [
                Latte.EmailClient.mail,
                Latte.EmailClient.gmail
            ]
            let alert = Latte.makeChooseEmailClientAlertController(
                title: "Open mail app",
                message: "Which app would you like to open?",
                cancelLabel: "Cancel",
                items: items
            )
            webView.viewController?.present(alert, animated: true)
        }
    }
}

public struct LatteWebViewRequest {
    public let url: URL
    public let redirectURI: String

    public init(url: URL, redirectURI: String) {
        self.url = url
        self.redirectURI = redirectURI
    }
}

public extension LatteWebViewRequest {
    init(request: AuthgearExperimental.AuthenticationRequest) {
        self.url = request.url
        self.redirectURI = request.redirectURI
    }
}

internal struct LatteWebViewResult {
    private let finishURL: URL

    init(finishURL: URL) {
        self.finishURL = finishURL
    }

    func unwrap() throws -> URL {
        let query = URLComponents(url: self.finishURL, resolvingAgainstBaseURL: false)!.queryParams

        if let oauthError = query["error"] {
            if oauthError == "cancel" {
                throw AuthgearError.cancel
            }

            if let latteError = query["x_latte_error"],
               let json = Data(base64Encoded: base64urlToBase64(base64url: latteError)) {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                if let error = try? decoder.decode(ServerError.self, from: json) {
                    throw AuthgearError.serverError(error)
                }
            }

            throw AuthgearError.oauthError(
                OAuthError(
                    error: oauthError,
                    errorDescription: query["error_description"],
                    errorUri: query["error_uri"]
                )
            )
        }

        return finishURL
    }
}

public struct LatteTrackingEvent {
    public let event_name: String
    public let params: [String: Any]
}

enum LatteWebViewEvent {
    case openEmailClient
    case trackingEvent(event: LatteTrackingEvent)
}
