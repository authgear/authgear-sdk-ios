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
        let customUIEndpoint: String
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

    static func getUniversalLinkHandler(
        customUIEndpoint: String,
        linkURLHost: String,
        userActivity: NSUserActivity
    ) -> LatteLinkHandler? {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let incomingURL = userActivity.webpageURL,
              let components = NSURLComponents(url: incomingURL, resolvingAgainstBaseURL: true) else {
            return nil
        }
        guard let path = components.path,
              let host = components.host, host == linkURLHost else {
            return nil
        }
        switch path {
        case _ where path.hasSuffix("/reset_link"):
            return ResetLinkHandler(
                customUIEndpoint: customUIEndpoint,
                query: components.queryItems
            )
        default:
            return nil
        }
    }
}
