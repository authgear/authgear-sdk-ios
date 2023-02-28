import Foundation
import UIKit
import WebKit

enum LatteBuiltInEvents: String {
    case openEmailClient
    case viewPage
}

let initScript = """
    document.addEventListener('latte:event',
        function (e) {
            window.webkit.messageHandlers.latteEvent.postMessage(e.detail);
        }
    )
"""

@available(iOS 13.0, *)
class LatteWKWebView: WKWebView, LatteWebView, WKNavigationDelegate {
    let request: LatteWebViewRequest

    weak var delegate: LatteWebViewDelegate?

    private var initialNavigation: WKNavigation?
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
        self.configuration.userContentController.add(MessageHandler(self), name: "latteEvent")
        self.configuration.processPool.perform(Selector(("_setCookieAcceptPolicy:")), with: HTTPCookie.AcceptPolicy.always)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func load() {
        self.initialNavigation = self.load(URLRequest(url: self.request.url))
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if navigation == self.initialNavigation {
            self.delegate?.latteWebView(completed: self, result: .failure(error))
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if navigation == self.initialNavigation {
            self.delegate?.latteWebView(completed: self, result: .failure(error))
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

    // Avoid reference cycle; ref https://stackoverflow.com/a/26383032
    class MessageHandler: NSObject, WKScriptMessageHandler {
        private weak var parent: LatteWKWebView?
        init(_ parent: LatteWKWebView) {
            self.parent = parent
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let parent = self.parent else { return }

            switch message.name {
            case "latteEvent":
                guard let body = message.body as? [String: Any] else { return }
                guard let type = body["type"] as? String else { return }

                switch type {
                case LatteBuiltInEvents.openEmailClient.rawValue:
                    parent.delegate?.latteWebView(onEvent: parent, event: .openEmailClient)
                case LatteBuiltInEvents.viewPage.rawValue:
                    guard let path = body["path"] as? String else { return }
                    let event = LatteViewPageEvent(path: path)
                    parent.delegate?.latteWebView(onEvent: parent, event: .viewPage(event: event))
                default:
                    return
                }
            default:
                break
            }
        }
    }
}
