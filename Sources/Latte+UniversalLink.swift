import Foundation
import UIKit

@available(iOS 13.0, *)
public protocol LatteLinkHandler {
    func handle(
        context: UINavigationController,
        authgear: Authgear,
        handler: @escaping Latte.ResultHandler<Void>
    )
}

@available(iOS 13.0, *)
public extension Latte {
    struct ResetLinkHandler: LatteLinkHandler {
        let customUIEndpoint: String
        let query: [URLQueryItem]?

        public func handle(
            context: UINavigationController,
            authgear: Authgear,
            handler: @escaping Latte.ResultHandler<Void>
        ) {
            Task { await run() }
            @Sendable @MainActor
            func run() async {
                var viewController: LatteViewController?
                do {
                    var entryURLComponents = URLComponents(string: customUIEndpoint + "/recovery/reset")!
                    entryURLComponents.queryItems = query
                    let entryURL = entryURLComponents.url!
                    let redirectURI = customUIEndpoint + "/recovery/reset/complete"
                    let webViewRequest = LatteWebViewRequest(url: entryURL, redirectURI: redirectURI)
                    let latteVC = LatteViewController(context: context, request: webViewRequest)
                    viewController = latteVC
                    let _ = try await withCheckedThrowingContinuation { next in
                        latteVC.handler = { next.resume(with: $0) }
                        context.pushViewController(latteVC, animated: true)
                    }
                    handler(Handle(isPresented: false, viewController: viewController, result: .success(())))
                } catch {
                    handler(Handle(isPresented: false, viewController: viewController, result: .failure(error)))
                }
            }
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
