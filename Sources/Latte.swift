import Foundation
import UIKit

public enum Latte {}

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

public enum LatteWebViewEvent {
    case openEmailClient
}

public protocol LatteWebViewDelegate: AnyObject {
    func latteWebView(completed _: LatteWebView, result: Result<LatteWebViewResult, Error>)
    func latteWebView(onEvent _: LatteWebView, event: LatteWebViewEvent)
}

public protocol LatteWebView: UIView {
    var delegate: LatteWebViewDelegate? { get set }
}
