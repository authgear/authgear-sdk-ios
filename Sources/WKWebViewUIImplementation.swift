import Foundation
import UIKit

public class WKWebViewUIImplementation: NSObject, UIImplementation, AGWKWebViewControllerPresentationContextProviding {
    public var modalPresentationStyle: UIModalPresentationStyle?
    public var navigationBarBackgroundColor: UIColor?
    public var navigationBarButtonTintColor: UIColor?
    public var wechatRedirectURI: URL?
    public var authgearDelegate: AuthgearDelegate?
    public var isInspectable: Bool

    override public init() {
        self.isInspectable = false
        super.init()
    }

    public func openAuthorizationURL(url: URL, redirectURI: URL, shareCookiesWithDeviceBrowser: Bool, completion: @escaping CompletionHandler) {
        let controller = AGWKWebViewController(
            url: url,
            redirectURI: redirectURI,
            isInspectable: self.isInspectable
        )

        controller.completionHandler = { url, error in
            if let error = error {
                completion(.failure(wrapError(error: error)))
            }
            if let url = url {
                completion(.success(url))
            }
        }
        if let wechatRedirectURI = self.wechatRedirectURI {
            controller.wechatRedirectURI = wechatRedirectURI
            controller.wechatRedirectURICallback = { url in
                guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
                let state = components.queryParams["state"] ?? ""
                if state.isEmpty {
                    return
                }
                self.authgearDelegate?.sendWechatAuthRequest(state)
            }
        }

        if let modalPresentationStyle = self.modalPresentationStyle {
            controller.modalPresentationStyle = modalPresentationStyle
        }
        if let navigationBarBackgroundColor = self.navigationBarBackgroundColor {
            controller.navigationBarBackgroundColor = navigationBarBackgroundColor
        }
        if let navigationBarButtonTintColor = self.navigationBarButtonTintColor {
            controller.navigationBarButtonTintColor = navigationBarButtonTintColor
        }
        controller.presentationContextProvider = self
        controller.start()
    }

    func presentationAnchor(for: AGWKWebViewController) -> UIWindow {
        UIApplication.shared.windows.filter { $0.isKeyWindow }.first!
    }
}
