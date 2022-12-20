import UIKit
import WebKit

protocol WebViewViewControllerDelegate: AnyObject {
    func webViewViewControllerOnTapCancel(_: WebViewViewController)
}

class WebViewViewController: UIViewController {
    let webview: WKWebView

    weak var delegate: WebViewViewControllerDelegate?

    init() {
        self.webview = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        self.webview.translatesAutoresizingMaskIntoConstraints = false
        self.webview.allowsBackForwardNavigationGestures = true
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
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(WebViewViewController.onTapCancel(_:))
        )

        self.webview.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor).isActive = true
        self.webview.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        self.webview.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor).isActive = true
        self.webview.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor).isActive = true
    }

    @objc func onTapCancel(_: AnyObject) {
        self.delegate?.webViewViewControllerOnTapCancel(self)
    }

    func navigationDidFinish(_: WKNavigation) {
        if self.webview.canGoBack {
            let item = UIBarButtonItem()
            item.title = "Back"
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
