import Foundation
import UIKit

public protocol LatteLinkHandler {}

public struct ResetLinkHandler: LatteLinkHandler {
    public let url: URL
}

public struct LoginLinkHandler: LatteLinkHandler {
    public let url: URL

    public func handle(latte: Latte, completion: @escaping (Result<Void, Error>) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        authgearFetch(urlSession: latte.urlSession, request: request) { result in
            switch result {
            case let .failure(error):
                completion(.failure(error))
            case .success:
                completion(.success(()))
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
            return ResetLinkHandler(url: components.url!)
        case _ where path.hasSuffix("/login_link"):
            let url: URL
            if let rewriteUniversalLinkOrigin = rewriteUniversalLinkOrigin {
                url = incomingURL.rewriteOrigin(origin: rewriteUniversalLinkOrigin)
            } else {
                url = incomingURL
            }
            return LoginLinkHandler(url: url)
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
