import Foundation
import UIKit
import WebKit

enum LatteBuiltInEvents: String {
    case openEmailClient
    case openSMSClient
    case tracking
    case ready
    case reauthWithBiometric
}

let initScript = """
    document.addEventListener('latte:event',
        function (e) {
            window.webkit.messageHandlers.latteEvent.postMessage(e.detail);
        }
    )
"""

@available(iOS 13.0, *)
protocol LatteWebViewDelegate: AnyObject {
    func latteWebView(onEvent _: LatteWKWebView, event: LatteWebViewEvent)
}

@available(iOS 13.0, *)
class LatteWKWebView: WKWebView, WKNavigationDelegate {
    let request: LatteWebViewRequest
    var onReady: ((_ webview: LatteWKWebView) -> Void)?
    var onReauthWithBiometric: ((_ webview: LatteWKWebView) -> Void)?
    var completion: ((_ webview: LatteWKWebView, _ result: Result<LatteWebViewResult, Error>) -> Void)?
    weak var viewController: UIViewController?
    weak var delegate: LatteWebViewDelegate?

    override var inputAccessoryView: UIView? {
        // Hide the accessory view
        nil
    }

    private var initialNavigation: WKNavigation?

    init(request: LatteWebViewRequest, isInspectable: Bool) {
        self.request = request

        super.init(frame: .zero, configuration: WKWebViewConfiguration())
        if isInspectable {
            // iOS 16.4 requires Xcode 14.3 to build.
            // Xcode 14.3 requires macOS 13 to install.
            // Compiling against iOS 16.4 requires a lot toolchain updates as of 2023-04-24.
            // if #available(iOS 16.4, *) {
            //     self.isInspectable = true
            // } else {
            //     self.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
            // }
            self.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        }

        self.allowsBackForwardNavigationGestures = true
        self.scrollView.alwaysBounceVertical = false
        self.scrollView.alwaysBounceHorizontal = false
        self.scrollView.contentInsetAdjustmentBehavior = .never

        self.navigationDelegate = self

        let userScript = WKUserScript(source: initScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        self.configuration.userContentController.addUserScript(userScript)
        self.configuration.userContentController.add(MessageHandler(self), name: "latteEvent")
        self.configuration.processPool.perform(Selector(("_setCookieAcceptPolicy:")), with: HTTPCookie.AcceptPolicy.always)

        _ = LatteWKWebView.oneTimeOnlySwizzle
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
            self.completion?(self, .failure(error))
            self.completion = nil
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if navigation == self.initialNavigation {
            self.completion?(self, .failure(error))
            self.completion = nil
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

                self.completion?(self, result)
                self.completion = nil
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
                case LatteBuiltInEvents.openSMSClient.rawValue:
                    parent.delegate?.latteWebView(onEvent: parent, event: .openSMSClient)
                case LatteBuiltInEvents.tracking.rawValue:
                    guard let event_name = body["event_name"] as? String else { return }
                    guard let params = body["params"] as? [String: Any] else { return }
                    let event = LatteTrackingEvent(
                        event_name: event_name, params: params
                    )
                    parent.delegate?.latteWebView(onEvent: parent, event: .trackingEvent(event: event))
                case LatteBuiltInEvents.ready.rawValue:
                    parent.onReady?(parent)
                    parent.onReady = nil
                case LatteBuiltInEvents.reauthWithBiometric.rawValue:
                    parent.onReauthWithBiometric?(parent)
                default:
                    return
                }
            default:
                break
            }
        }
    }
}

// ref: https://github.com/ionic-team/capacitor/blob/89cddcd6497034146e0938ce8c264e22e7baba52/ios/Capacitor/Capacitor/WKWebView%2BCapacitor.swift#L22
@available(iOS 13.0, *)
extension LatteWKWebView {
    typealias FiveArgClosureType = @convention(c) (Any, Selector, UnsafeRawPointer, Bool, Bool, Bool, Any?) -> Void

    static let oneTimeOnlySwizzle: () = swizzleKeyboardMethods()
    private static func swizzleKeyboardMethods() {
        let frameworkName = "WK"
        let className = "ContentView"
        guard let targetClass = NSClassFromString(frameworkName + className) else {
            return
        }

        func findWebView(_ object: Any?) -> WKWebView? {
            var view = object as? UIView
            while view != nil {
                if let webview = view as? WKWebView {
                    return webview
                }
                view = view?.superview
            }
            return nil
        }

        func swizzleFiveArgClosure(_ method: Method, _ selector: Selector) {
            let originalImp: IMP = method_getImplementation(method)
            let original: FiveArgClosureType = unsafeBitCast(originalImp, to: FiveArgClosureType.self)
            let block: @convention(block) (Any, UnsafeRawPointer, Bool, Bool, Bool, Any?) -> Void = { (me, arg0, arg1, arg2, arg3, arg4) in
                if let webView = findWebView(me), webView is LatteWKWebView {
                    original(me, selector, arg0, true, arg2, arg3, arg4)
                } else {
                    original(me, selector, arg0, arg1, arg2, arg3, arg4)
                }
            }
            let imp: IMP = imp_implementationWithBlock(block)
            method_setImplementation(method, imp)
        }

        let selectorMkIV: Selector = sel_getUid("_elementDidFocus:userIsInteracting:blurPreviousNode:activityStateChanges:userObject:")

        if let method = class_getInstanceMethod(targetClass, selectorMkIV) {
            swizzleFiveArgClosure(method, selectorMkIV)
        }
    }
}
