import Foundation
import UIKit

@available(iOS 13.0, *)
public extension Latte {
    static func handleUniversalLink(
        context: UINavigationController,
        authgear: Authgear,
        customUIEndpoint: String,
        userActivity: NSUserActivity
    ) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let incomingURL = userActivity.webpageURL,
              let components = NSURLComponents(url: incomingURL, resolvingAgainstBaseURL: true) else {
            return false
        }
        guard let path = components.path,
              let params = components.queryItems else {
            return false
        }
        switch path {
        case _ where path.hasSuffix("/reset_link"):
            Latte.handleResetLink(
                context: context,
                authgear: authgear,
                customUIEndpoint: customUIEndpoint,
                query: params
            )
            return true
        default:
            return false
        }
    }

    private static func handleResetLink(
        context: UINavigationController,
        authgear: Authgear,
        customUIEndpoint: String,
        query: [URLQueryItem]?
    ) {
        Task { await run() }
        @Sendable @MainActor
        func run() async {
            do {
                var entryURLComponents = URLComponents(string: customUIEndpoint + "/recovery/reset")!
                entryURLComponents.queryItems = query
                let entryURL = entryURLComponents.url!
                let redirectURI = customUIEndpoint + "/recovery/reset/complete"
                let webViewRequest = LatteWebViewRequest(url: entryURL, redirectURI: redirectURI)
                let latteVC = LatteViewController(context: context, request: webViewRequest)
                let _ = try await withCheckedThrowingContinuation { next in
                    latteVC.handler = { next.resume(with: $0) }
                    context.pushViewController(latteVC, animated: true)
                }
            } catch {
                print(error)
            }
        }
    }
}
