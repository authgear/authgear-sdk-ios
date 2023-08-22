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
public class LatteShortLinkExpander: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    let url: URL
    lazy var session: URLSession = .init(configuration: .default, delegate: self, delegateQueue: nil)

    let universalLinkOrigin: URL
    let rewriteUniversalLinkOrigin: URL?

    init(
        url: URL,
        universalLinkOrigin: URL,
        rewriteUniversalLinkOrigin: URL?
    ) {
        self.url = url
        self.universalLinkOrigin = universalLinkOrigin
        self.rewriteUniversalLinkOrigin = rewriteUniversalLinkOrigin
        super.init()
    }

    public func expand(_ handler: @escaping (Result<LatteLinkHandler?, Error>) -> Void) {
        func mainQueueHandler(_ result: Result<LatteLinkHandler?, Error>) {
            DispatchQueue.main.async {
                handler(result)
            }
        }
        let task = session.dataTask(with: url) { _, response, error in
            if let error = error {
                return mainQueueHandler(.failure(wrapError(error: error)))
            }
            guard let response = response as? HTTPURLResponse,
                  response.statusCode == 302,
                  let location = response.allHeaderFields["Location"] as? String,
                  let locationURL = URL(string: location)
            else {
                return mainQueueHandler(.failure(LatteError.invalidShortLink))
            }
            mainQueueHandler(.success(Latte.getUniversalLinkHandler(
                incomingURL: locationURL,
                universalLinkOrigin: self.universalLinkOrigin,
                rewriteUniversalLinkOrigin: self.rewriteUniversalLinkOrigin
            )))
        }
        task.resume()
    }

    public func urlSession(_: URLSession, task _: URLSessionTask, willPerformHTTPRedirection _: HTTPURLResponse, newRequest _: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        // Stop redirection
        completionHandler(nil)
    }
}

@available(iOS 13.0, *)
public extension Latte {
    internal static func getUniversalLinkHandler(
        incomingURL: URL,
        universalLinkOrigin: URL,
        rewriteUniversalLinkOrigin: URL? = nil
    ) -> LatteLinkHandler? {
        guard incomingURL.origin == universalLinkOrigin.origin,
              let components = NSURLComponents(url: incomingURL, resolvingAgainstBaseURL: true) else {
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

    static func getUniversalLinkHandler(
        userActivity: NSUserActivity,
        universalLinkOrigin: URL,
        rewriteUniversalLinkOrigin: URL? = nil
    ) -> LatteLinkHandler? {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let incomingURL = userActivity.webpageURL else {
            return nil
        }

        return getUniversalLinkHandler(
            incomingURL: incomingURL,
            universalLinkOrigin: universalLinkOrigin,
            rewriteUniversalLinkOrigin: rewriteUniversalLinkOrigin
        )
    }

    static func getShortLinkExpander(
        userActivity: NSUserActivity,
        shortLinkOrigin: URL,
        universalLinkOrigin: URL,
        rewriteUniversalLinkOrigin: URL? = nil
    ) -> LatteShortLinkExpander? {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb else {
            return nil
        }
        guard let incomingURL = userActivity.webpageURL else {
            return nil
        }
        guard incomingURL.origin == shortLinkOrigin.origin,
              incomingURL.path.starts(with: "/s") else {
            return nil
        }
        return LatteShortLinkExpander(
            url: incomingURL,
            universalLinkOrigin: universalLinkOrigin,
            rewriteUniversalLinkOrigin: rewriteUniversalLinkOrigin
        )
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
        let thatComponents = URLComponents(url: origin, resolvingAgainstBaseURL: true)!
        selfComponents.scheme = thatComponents.scheme
        selfComponents.host = thatComponents.host
        selfComponents.port = thatComponents.port
        return selfComponents.url!
    }
}
