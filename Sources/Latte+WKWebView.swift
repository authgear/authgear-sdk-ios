import Foundation
import UIKit
import WebKit

public extension Latte {
    @available(iOS 13.0, *)
    static func prepareWebView(
        _ request: LatteWebViewRequest,
        handler: @escaping (Result<LatteWebView, Error>) -> Void
    ) {
        let webView = LatteWKWebView(request)
        webView.prepareCompletionHandler = { result in
            handler(result.map { _ in webView })
        }
        webView.load()
    }
}

enum LatteBuiltInEvents: String {
    case openEmailClient
}

let initScript = """
    document.addEventListener('latte:event',
        function (e) {
            window.webkit.messageHandlers.latteEvent.postMessage(e.detail);
        }
    )
"""

@available(iOS 13.0, *)
class LatteWKWebView: WKWebView, LatteWebView, WKNavigationDelegate, WKScriptMessageHandler {
    let request: LatteWebViewRequest

    weak var delegate: LatteWebViewDelegate? {
        didSet {
            if let result = self.result {
                // Avoid race condition when redirect URI is navigated
                // before initial navigation is completed.
                self.result = nil
                self.delegate?.latteWebView(completed: self, result: result)
            }
        }
    }

    private var initialNavigation: WKNavigation?
    var prepareCompletionHandler: ((Result<LatteWKWebView, Error>) -> Void)?
    private var result: Result<LatteWebViewResult, Error>?

    init(_ request: LatteWebViewRequest) {
        self.request = request

        super.init(frame: .zero, configuration: WKWebViewConfiguration())

        self.allowsBackForwardNavigationGestures = true
        self.scrollView.alwaysBounceVertical = false
        self.scrollView.alwaysBounceHorizontal = false
        self.scrollView.contentInsetAdjustmentBehavior = .never

        self.navigationDelegate = self

        let userScript = WKUserScript(source: initScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        self.configuration.userContentController.addUserScript(userScript)
        self.configuration.userContentController.add(self, name: "latteEvent")
        self.configuration.processPool.perform(Selector(("_setCookieAcceptPolicy:")), with: HTTPCookie.AcceptPolicy.always)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func load() {
        self.initialNavigation = self.load(URLRequest(url: self.request.url))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if navigation == self.initialNavigation {
            self.prepareCompletionHandler?(.success(self))
            self.prepareCompletionHandler = nil
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if navigation == self.initialNavigation {
            self.prepareCompletionHandler?(.failure(error))
            self.prepareCompletionHandler = nil
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if navigation == self.initialNavigation {
            self.prepareCompletionHandler?(.failure(error))
            self.prepareCompletionHandler = nil
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        if let navigationURL = navigationAction.request.url {
            var parts = URLComponents(url: navigationURL, resolvingAgainstBaseURL: false)!
            parts.query = nil
            parts.fragment = nil
            if parts.string == self.request.redirectURI {
                let result = Result<LatteWebViewResult, Error>.success(
                    LatteWebViewResult(finishURL: navigationURL)
                )

                self.delegate?.latteWebView(completed: self, result: result)
                self.result = result
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

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "latteEvent":
            guard let body = message.body as? [String: Any] else { return }
            guard let type = body["type"] as? String else { return }

            switch type {
            case LatteBuiltInEvents.openEmailClient.rawValue:
                self.delegate?.latteWebView(onEvent: self, event: .openEmailClient)
            default:
                return
            }
        default:
            break
        }
    }
}
