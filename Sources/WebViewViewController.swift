import UIKit
import WebKit

protocol WebViewViewControllerDelegate: AnyObject {
    func webViewViewControllerOnTapCancel(_: WebViewViewController)
}

class WebViewViewController: UIViewController {
    let webview: WKWebView

    let isFullScreenMode: Bool
    weak var delegate: WebViewViewControllerDelegate?

    init(isFullScreenMode: Bool = false) {
        self.isFullScreenMode = isFullScreenMode
        self.webview = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        self.webview.translatesAutoresizingMaskIntoConstraints = false
        self.webview.allowsBackForwardNavigationGestures = true
        self.webview.scrollView.alwaysBounceVertical = false
        self.webview.scrollView.alwaysBounceHorizontal = false
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.webview)
        self.view.backgroundColor = UIColor.white

        self.navigationItem.hidesBackButton = true
        let item = UIBarButtonItem()
        if #available(iOS 13, *) {
            item.image = UIImage(systemName: "xmark")
        } else {
            item.title = "Cancel"
        }
        item.style = .plain
        item.target = self
        item.action = #selector(WebViewViewController.onTapCancel(_:))
        self.navigationItem.rightBarButtonItem = item

        if isFullScreenMode {
            self.webview.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
            self.webview.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
            self.webview.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
            self.webview.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true

            self.webview.scrollView.contentInsetAdjustmentBehavior = .never
        } else {
            self.webview.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor).isActive = true
            self.webview.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor).isActive = true
            self.webview.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor).isActive = true
            self.webview.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor).isActive = true
        }
    }

    @objc func onTapCancel(_: AnyObject) {
        self.delegate?.webViewViewControllerOnTapCancel(self)
    }

    func navigationDidFinish(_: WKNavigation) {
        if self.webview.canGoBack {
            let item = UIBarButtonItem()
            if #available(iOS 13, *) {
                item.image = UIImage(systemName: "arrow.left")
            } else {
                item.title = "Back"
            }
            item.target = self
            item.action = #selector(WebViewViewController.goBack(_:))
            self.navigationItem.setLeftBarButton(item, animated: true)
        } else {
            self.navigationItem.setLeftBarButton(nil, animated: true)
        }
    }

    @objc func goBack(_: AnyObject) {
        self.webview.goBack()
    }
}
