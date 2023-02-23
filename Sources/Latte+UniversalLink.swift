import Foundation
import UIKit

@available(iOS 13.0, *)
public protocol LatteLinkHandler {
    func handle(
        context: UINavigationController,
        latte: Latte,
        handler: @escaping (Result<Void, Error>) -> Void
    )
}

@available(iOS 13.0, *)
public extension Latte {
    struct ResetLinkHandler: LatteLinkHandler {
        let query: [URLQueryItem]?

        public func handle(
            context: UINavigationController,
            latte: Latte,
            handler: @escaping (Result<Void, Error>) -> Void
        ) {
            latte.resetPassword(
                context: context,
                extraQuery: query,
                handler: { handle in
                    handle.dismiss(animated: true)
                    handler(handle.result)
                }
            )
        }
    }

    struct LoginLinkHandler: LatteLinkHandler {
        let url: URL

        public func handle(
            context: UINavigationController,
            latte: Latte,
            handler: @escaping (Result<Void, Error>
            ) -> Void
        ) {
            var request = URLRequest(url: self.url)
            request.httpMethod = "POST"
            let task = latte.urlSession.dataTask(with: request) { _, _, error in
                if let error = error {
                    handler(.failure(error))
                    return
                }
                handler(.success(()))
            }
            task.resume()
        }
    }

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
            return ResetLinkHandler(
                query: components.queryItems
            )
        case _ where path.hasSuffix("/login_link"):
            let url: URL
            if let rewriteUniversalLinkOrigin = rewriteUniversalLinkOrigin {
                url = incomingURL.rewriteOrigin(origin: rewriteUniversalLinkOrigin)
            } else {
                url = incomingURL
            }
            return LoginLinkHandler(
                url: url
            )
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
