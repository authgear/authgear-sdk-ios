import UIKit
import WebKit

@available(iOS 13.0, *)
@objc protocol WebViewSessionDelegate: AnyObject {
    func presentationAnchor(for: WebViewSession) -> UIWindow
    @objc optional func webViewSessionWillPresent(_: WebViewSession)
}

enum WebViewSessionError: Error {
    case canceled
    case presentationContextNotProvided
}

@available(iOS 13.0, *)
class WebViewSession: NSObject, WKNavigationDelegate, WebViewViewControllerDelegate {
    typealias CompletionHandler = (URL?, Error?) -> Void

    let url: URL
    let redirectURI: URL
    weak var delegate: WebViewSessionDelegate?

    private var completionHandler: CompletionHandler?
    private var viewController: WebViewViewController?
    private var initialNavigation: WKNavigation?

    init(url: URL, redirectURI: URL, completionHandler: @escaping CompletionHandler) {
        self.url = url
        self.redirectURI = redirectURI
        self.completionHandler = completionHandler
    }

    func start() -> Bool {
        let viewController = WebViewViewController()
        self.viewController = viewController
        viewController.delegate = self
        viewController.webview.navigationDelegate = self
        self.initialNavigation = viewController.webview.load(URLRequest(url: self.url))
        return true
    }

    func cancel() {
        if let viewController = self.viewController {
            viewController.presentingViewController?.dismiss(animated: true)
            self.completionHandler?(nil, WebViewSessionError.canceled)
            self.completionHandler = nil
        }
    }

    private func present() {
        if let delegate = self.delegate, let viewController = self.viewController {
            let window = delegate.presentationAnchor(for: self)
            delegate.webViewSessionWillPresent?(self)
            let navigationController = UINavigationController(rootViewController: viewController)

            // Present the view controller full screen.
            navigationController.modalPresentationStyle = .fullScreen

            // Do not allow iOS to make the navigation bar transparent at scroll edge.
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.white
            navigationController.navigationBar.standardAppearance = appearance
            navigationController.navigationBar.scrollEdgeAppearance = appearance

            window.rootViewController?.present(navigationController, animated: true)
        } else {
            self.completionHandler?(nil, WebViewSessionError.presentationContextNotProvided)
            self.completionHandler = nil
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if navigation == self.initialNavigation {
            self.present()
        } else {
            self.viewController?.navigationDidFinish(navigation)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if navigation == self.initialNavigation {
            self.completionHandler?(nil, error)
            self.completionHandler = nil
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if navigation == self.initialNavigation {
            self.completionHandler?(nil, error)
            self.completionHandler = nil
        }
    }

    // This variant is available from iOS 8. The other variant is available from iOS 13.
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        if let navigationURL = navigationAction.request.url {
            var parts = URLComponents(url: navigationURL, resolvingAgainstBaseURL: false)!
            parts.query = nil
            parts.fragment = nil
            let noQueryNoFragment = parts.url!
            if noQueryNoFragment == self.redirectURI {
                await self.viewController?.presentingViewController?.dismiss(animated: true)
                self.completionHandler?(navigationURL, nil)
                self.completionHandler = nil
                return .cancel
            }
        }

        if #available(iOS 14.5, *) {
            if navigationAction.shouldPerformDownload {
                return .download
            } else {
                return .allow
            }
        } else {
            return .allow
        }
    }

    func webViewViewControllerOnTapCancel(_: WebViewViewController) {
        self.cancel()
    }
}
