import Foundation
import UIKit

public protocol LatteDelegate: AnyObject {
    func latte(_: Latte, onTrackingEvent: LatteTrackingEvent)
    func latte(_: Latte, onOpenEmailClient source: UIViewController)
    func latte(_: Latte, onOpenSMSClient source: UIViewController)
}

// Default implemetations
public extension LatteDelegate {
    func latte(_: Latte, onOpenEmailClient source: UIViewController) {
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
        source.present(alert, animated: true)
    }

    func latte(_: Latte, onOpenSMSClient source: UIViewController) {
        UIApplication.shared.open(URL(string: "messages://")!)
    }
}

public class Latte: LatteWebViewDelegate {
    let authgear: Authgear
    let customUIEndpoint: String
    let tokenizeEndpoint: String
    let urlSession: URLSession
    let webviewIsInspectable: Bool
    public weak var delegate: LatteDelegate?

    public init(
        authgear: Authgear,
        customUIEndpoint: String,
        tokenizeEndpoint: String,
        webviewIsInspectable: Bool = false
    ) {
        self.authgear = authgear
        self.customUIEndpoint = customUIEndpoint
        self.tokenizeEndpoint = tokenizeEndpoint
        self.webviewIsInspectable = webviewIsInspectable
        self.urlSession = URLSession(configuration: .default)
    }

    @available(iOS 13.0, *)
    func latteWebView(onEvent webView: LatteWKWebView, event: LatteWebViewEvent) {
        switch event {
        case let .trackingEvent(event: event):
            self.delegate?.latte(_: self, onTrackingEvent: event)
        case .openEmailClient:
            guard let vc = webView.viewController else { return }
            self.delegate?.latte(_: self, onOpenEmailClient: vc)
        case .openSMSClient:
            guard let vc = webView.viewController else { return }
            self.delegate?.latte(_: self, onOpenSMSClient: vc)
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

struct LatteWebViewResult {
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
    case openSMSClient
    case trackingEvent(event: LatteTrackingEvent)
}
