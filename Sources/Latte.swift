import Foundation
import UIKit

public protocol LatteDelegate: AnyObject {
    func latte(_: Latte, onTrackingEvent: LatteTrackingEvent)
}

public class Latte: LatteViewControllerDelegate {
    let authgear: Authgear
    let customUIEndpoint: String
    let urlSession: URLSession
    public weak var delegate: LatteDelegate?

    public init(authgear: Authgear, customUIEndpoint: String) {
        self.authgear = authgear
        self.customUIEndpoint = customUIEndpoint
        self.urlSession = URLSession(configuration: .default)
    }

    @available(iOS 13.0, *)
    func latteViewController(onEvent _: LatteViewController, event: LatteWebViewEvent) {
        switch event {
        case let .trackingEvent(event: event):
            self.delegate?.latte(_: self, onTrackingEvent: event)
        case .openEmailClient:
            break
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

public struct LatteWebViewResult {
    public let finishURL: URL

    @available(iOS 13.0, *)
    func handle<T>(handler: (URL, @escaping (Result<T, Error>) -> Void) -> Void) async throws -> T {
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

        return try await withCheckedThrowingContinuation { resume in
            handler(finishURL) { resume.resume(with: $0) }
        }
    }
}

public struct LatteTrackingEvent {
    public let event_name: String
    public let params: [String: Any]
}

public enum LatteWebViewEvent {
    case openEmailClient
    case trackingEvent(event: LatteTrackingEvent)
}

public protocol LatteWebViewDelegate: AnyObject {
    func latteWebView(completed _: LatteWebView, result: Result<LatteWebViewResult, Error>)
    func latteWebView(onEvent _: LatteWebView, event: LatteWebViewEvent)
}

public protocol LatteWebView: UIView {
    var delegate: LatteWebViewDelegate? { get set }
}
