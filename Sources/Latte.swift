import Foundation
import UIKit

public protocol LatteDelegate: AnyObject {
    func latte(onViewPage _: Latte, event: LatteViewPageEvent)
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
        case let .viewPage(event):
            self.delegate?.latte(onViewPage: self, event: event)
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
}

public struct LatteViewPageEvent {
    public let path: String
}

public enum LatteWebViewEvent {
    case openEmailClient
    case viewPage(event: LatteViewPageEvent)
}

public protocol LatteWebViewDelegate: AnyObject {
    func latteWebView(completed _: LatteWebView, result: Result<LatteWebViewResult, Error>)
    func latteWebView(onEvent _: LatteWebView, event: LatteWebViewEvent)
}

public protocol LatteWebView: UIView {
    var delegate: LatteWebViewDelegate? { get set }
}
