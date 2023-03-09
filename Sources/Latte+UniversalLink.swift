import Foundation
import UIKit

@available(iOS 13.0, *)
public enum LatteLinkHandler {
    case resetPassword(url: URL)
    case login(url: URL)

    public func handle(
        context: UINavigationController,
        latte: Latte,
        handler: @escaping (Result<Void, Error>) -> Void
    ) {
        switch self {
        case let .resetPassword(url):
            latte.resetPassword(
                context: context,
                url: url,
                handler: { handle in
                    handle.dismiss(animated: true)
                    handler(handle.result)
                }
            )
        case let .login(url):
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            authgearFetch(urlSession: latte.urlSession, request: request) { result in
                switch result {
                case let .failure(error):
                    handler(.failure(error))
                case .success:
                    handler(.success(()))
                }
            }
        }
    }
}

@available(iOS 13.0, *)
public extension Latte {
    static func getUniversalLinkHandler(
        userActivity: NSUserActivity,
        universalLinkOrigin: URL,
        rewriteUniversalLinkOrigin: URL? = nil
    ) -> LatteLinkHandler? {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let incomingURL = userActivity.webpageURL,
              let components = NSURLComponents(url: incomingURL, resolvingAgainstBaseURL: true) else {
            return nil
        }

        guard incomingURL.origin == universalLinkOrigin.origin else {
            return nil
        }

        guard let path = components.path else {
            return nil
        }

        switch path {
        case _ where path.hasSuffix("/reset_link"):
            return .resetPassword(url: components.url!)
        case _ where path.hasSuffix("/login_link"):
            let url: URL
            if let rewriteUniversalLinkOrigin = rewriteUniversalLinkOrigin {
                url = incomingURL.rewriteOrigin(origin: rewriteUniversalLinkOrigin)
            } else {
                url = incomingURL
            }
            return .login(url: url)
        default:
            return nil
        }
    }
}

private extension URL {
    var origin: URL {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: true)!
        components.fragment = nil
        components.password = nil
        components.path = ""
        components.query = nil
        components.user = nil
        return components.url!
    }

    func rewriteOrigin(origin: URL) -> URL {
        var selfComponents = URLComponents(url: self, resolvingAgainstBaseURL: true)!
        var thatComponents = URLComponents(url: origin, resolvingAgainstBaseURL: true)!
        selfComponents.scheme = thatComponents.scheme
        selfComponents.host = thatComponents.host
        selfComponents.port = thatComponents.port
        return selfComponents.url!
    }
}
