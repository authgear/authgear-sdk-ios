import Foundation
import UIKit

public class WKWebViewUIImplementation: NSObject, UIImplementation, AGWKWebViewControllerPresentationContextProviding {
    public var modalPresentationStyle: UIModalPresentationStyle? = nil
    public var navigationBarBackgroundColor: UIColor? = nil
    public var navigationBarButtonTintColor: UIColor? = nil

    public func openAuthorizationURL(url: URL, redirectURI: URL, shareCookiesWithDeviceBrowser: Bool, completion: @escaping CompletionHandler) {
        let controller = AGWKWebViewController(url: url, redirectURI: redirectURI) { url, error in
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
