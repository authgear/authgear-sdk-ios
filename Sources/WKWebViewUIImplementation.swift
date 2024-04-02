import Foundation
import UIKit

public class WKWebViewUIImplementation: NSObject, UIImplementation, AGWKWebViewControllerPresentationContextProviding {
    public var modalPresentationStyle: UIModalPresentationStyle?
    public var navigationBarBackgroundColor: UIColor?
    public var navigationBarButtonTintColor: UIColor?
    public var isInspectable: Bool

    public init(
        modalPresentationStyle: UIModalPresentationStyle? = nil,
        navigationBarBackgroundColor: UIColor? = nil,
        navigationBarButtonTintColor: UIColor? = nil,
        isInspectable: Bool = false
    ) {
        self.modalPresentationStyle = modalPresentationStyle
        self.navigationBarBackgroundColor = navigationBarBackgroundColor
        self.navigationBarButtonTintColor = navigationBarButtonTintColor
        self.isInspectable = isInspectable
    }

    public func openAuthorizationURL(url: URL, redirectURI: URL, shareCookiesWithDeviceBrowser: Bool, completion: @escaping CompletionHandler) {
        let controller = AGWKWebViewController(url: url, redirectURI: redirectURI, isInspectable: isInspectable) { url, error in
            if let error = error {
                completion(.failure(wrapError(error: error)))
            }
            if let url = url {
                completion(.success(url))
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
