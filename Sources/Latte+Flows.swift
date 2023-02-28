import Foundation
import UIKit

@available(iOS 13.0, *)
public extension Latte {
    struct Handle<T> {
        let isPresented: Bool
        let viewController: UIViewController?
        public let result: Result<T, Error>

        public func dismiss(animated: Bool) {
            if self.isPresented {
                self.viewController?.dismiss(animated: animated)
            } else {
                var viewControllers = self.viewController?.navigationController?.viewControllers ?? []
                viewControllers.removeAll(where: { $0 == self.viewController })
                self.viewController?.navigationController?.setViewControllers(viewControllers, animated: animated)
            }
        }
    }

    typealias ResultHandler<T> = (Handle<T>) -> Void

    func authenticate(
        context: UINavigationController,
        redirectURI: String,
        state: String? = nil,
        prompt: [PromptOption]? = nil,
        loginHint: String? = nil,
        uiLocales: [String]? = nil,
        colorScheme: ColorScheme? = nil,
        wechatRedirectURI: String? = nil,
        page: AuthenticationPage? = nil,
        customUIQuery: String? = nil,
        handler: @escaping ResultHandler<UserInfo>
    ) {
        Task { await run() }

        @Sendable @MainActor
        func run() async {
            var viewController: LatteViewController?
            do {
                let request = try authgear.experimental.createAuthenticateRequest(
                    redirectURI: redirectURI,
                    state: state,
                    prompt: prompt,
                    loginHint: loginHint,
                    uiLocales: uiLocales,
                    colorScheme: colorScheme,
                    wechatRedirectURI: wechatRedirectURI,
                    page: page,
                    customUIQuery: customUIQuery
                ).get()

                let webViewRequest = LatteWebViewRequest(request: request)
                let latteVC = LatteViewController(context: context, request: webViewRequest)
                viewController = latteVC

                let result: LatteWebViewResult = try await withCheckedThrowingContinuation { next in
                    latteVC.handler = { next.resume(with: $0) }
                    context.pushViewController(latteVC, animated: true)
                }

                let userInfo: UserInfo = try await withCheckedThrowingContinuation { resume in
                    authgear.experimental.finishAuthentication(finishURL: result.finishURL, request: request) { resume.resume(with: $0)
                    }
                }
                handler(Handle(isPresented: false, viewController: viewController, result: .success(userInfo)))
            } catch {
                handler(Handle(isPresented: false, viewController: viewController, result: .failure(error)))
            }
        }
    }

    func verifyEmail(
        context: UINavigationController,
        email: String,
        handler: @escaping ResultHandler<UserInfo>
    ) {
        Task { await run() }

        @Sendable @MainActor
        func run() async {
            var viewController: LatteViewController?
            do {
                let entryURL = customUIEndpoint + "/verify/email"
                let redirectURI = customUIEndpoint + "/verify/email/completed"

                let urlQueryAllowed = CharacterSet.urlQueryAllowed.subtracting(["+"])
                let query = [
                    "email=\(email.addingPercentEncoding(withAllowedCharacters: urlQueryAllowed)!)",
                    "redirect_uri=\(redirectURI.addingPercentEncoding(withAllowedCharacters: urlQueryAllowed)!)"
                ].joined(separator: "&")
                let verifyEmailURL = "\(entryURL)?\(query)"

                let url: URL = try await withCheckedThrowingContinuation { resume in
                    authgear.experimental.generateURL(redirectURI: verifyEmailURL) {
                        resume.resume(with: $0)
                    }
                }

                let webViewRequest = LatteWebViewRequest(url: url, redirectURI: redirectURI)
                let latteVC = LatteViewController(context: context, request: webViewRequest)
                viewController = latteVC

                let result: LatteWebViewResult = try await withCheckedThrowingContinuation { next in
                    latteVC.handler = { next.resume(with: $0) }
                    context.pushViewController(latteVC, animated: true)
                }

                let components = URLComponents(url: result.finishURL, resolvingAgainstBaseURL: false)!
                if let urlError = components.queryItems?.first(where: { $0.name == "error" })?.value {
                    let error: AuthgearError
                    if urlError == "cancel" {
                        error = .cancel
                    } else {
                        error = .oauthError(OAuthError(error: urlError, errorDescription: nil, errorUri: nil))
                    }
                    handler(Handle(isPresented: false, viewController: viewController, result: .failure(error)))
                    return
                }

                let userInfo: UserInfo = try await withCheckedThrowingContinuation { resume in
                    authgear.experimental.authgear.fetchUserInfo() { resume.resume(with: $0) }
                }
                handler(Handle(isPresented: false, viewController: viewController, result: .success(userInfo)))
            } catch {
                handler(Handle(isPresented: false, viewController: viewController, result: .failure(error)))
            }
        }
    }

    func changePassword(
        context: UINavigationController,
        handler: @escaping ResultHandler<Void>
    ) {
        Task { await run() }

        @Sendable @MainActor
        func run() async {
            var viewController: LatteViewController?
            do {
                let entryURL = customUIEndpoint + "/settings/change_password"
                let redirectURI = "latte://complete"

                let urlQueryAllowed = CharacterSet.urlQueryAllowed.subtracting(["+"])
                let query = [
                    "redirect_uri=\(redirectURI.addingPercentEncoding(withAllowedCharacters: urlQueryAllowed)!)"
                ].joined(separator: "&")
                let entryURLWithWQuery = "\(entryURL)?\(query)"

                let url: URL = try await withCheckedThrowingContinuation { resume in
                    authgear.experimental.generateURL(redirectURI: entryURLWithWQuery) {
                        resume.resume(with: $0)
                    }
                }

                let webViewRequest = LatteWebViewRequest(url: url, redirectURI: redirectURI)
                let latteVC = LatteViewController(context: context, request: webViewRequest)
                viewController = latteVC

                let result: LatteWebViewResult = try await withCheckedThrowingContinuation { next in
                    latteVC.handler = { next.resume(with: $0) }
                    context.pushViewController(latteVC, animated: true)
                }

                let components = URLComponents(url: result.finishURL, resolvingAgainstBaseURL: false)!
                if let urlError = components.queryItems?.first(where: { $0.name == "error" })?.value {
                    let error: AuthgearError
                    if urlError == "cancel" {
                        error = .cancel
                    } else {
                        error = .oauthError(OAuthError(error: urlError, errorDescription: nil, errorUri: nil))
                    }
                    handler(Handle(isPresented: false, viewController: viewController, result: .failure(error)))
                    return
                }

                handler(Handle(isPresented: false, viewController: viewController, result: .success(())))
            } catch {
                handler(Handle(isPresented: false, viewController: viewController, result: .failure(error)))
            }
        }
    }

    func resetPassword(
        context: UINavigationController,
        extraQuery: [URLQueryItem]?,
        handler: @escaping ResultHandler<Void>
    ) {
        Task { await run() }
        @Sendable @MainActor
        func run() async {
            var viewController: LatteViewController?
            do {
                var entryURLComponents = URLComponents(string: customUIEndpoint + "/recovery/reset")!
                let redirectURI = "latte://reset-complete"
                var urlQuery = extraQuery ?? []
                urlQuery.append(
                    URLQueryItem(name: "redirect_uri", value: redirectURI)
                )
                entryURLComponents.queryItems = urlQuery
                let entryURL = entryURLComponents.url!
                let webViewRequest = LatteWebViewRequest(url: entryURL, redirectURI: redirectURI)
                let latteVC = LatteViewController(context: context, request: webViewRequest)
                viewController = latteVC
                let _: LatteWebViewResult = try await withCheckedThrowingContinuation { next in
                    latteVC.handler = { next.resume(with: $0) }
                    context.pushViewController(latteVC, animated: true)
                }
                latteVC.dismiss(animated: true)
                handler(Handle(isPresented: false, viewController: viewController, result: .success(())))
            } catch {
                handler(Handle(isPresented: false, viewController: viewController, result: .failure(error)))
            }
        }
    }

    func changeEmail(
        context: UINavigationController,
        email: String,
        handler: @escaping ResultHandler<UserInfo>
    ) {
        Task { await run() }

        @Sendable @MainActor
        func run() async {
            var viewController: LatteViewController?
            do {
                let entryURL = customUIEndpoint + "/settings/change_email"
                let redirectURI = customUIEndpoint + "/verify/email/completed"

                let urlQueryAllowed = CharacterSet.urlQueryAllowed.subtracting(["+"])
                let query = [
                    "email=\(email.addingPercentEncoding(withAllowedCharacters: urlQueryAllowed)!)",
                    "redirect_uri=\(redirectURI.addingPercentEncoding(withAllowedCharacters: urlQueryAllowed)!)"
                ].joined(separator: "&")
                let changeEmailURL = "\(entryURL)?\(query)"

                let url: URL = try await withCheckedThrowingContinuation { resume in
                    authgear.experimental.generateURL(redirectURI: changeEmailURL) {
                        resume.resume(with: $0)
                    }
                }

                let webViewRequest = LatteWebViewRequest(url: url, redirectURI: redirectURI)
                let latteVC = LatteViewController(context: context, request: webViewRequest)
                viewController = latteVC

                let result: LatteWebViewResult = try await withCheckedThrowingContinuation { next in
                    latteVC.handler = { next.resume(with: $0) }
                    context.pushViewController(latteVC, animated: true)
                }

                let components = URLComponents(url: result.finishURL, resolvingAgainstBaseURL: false)!
                if let urlError = components.queryItems?.first(where: { $0.name == "error" })?.value {
                    let error: AuthgearError
                    if urlError == "cancel" {
                        error = .cancel
                    } else {
                        error = .oauthError(OAuthError(error: urlError, errorDescription: nil, errorUri: nil))
                    }
                    handler(Handle(isPresented: false, viewController: viewController, result: .failure(error)))
                    return
                }

                let userInfo: UserInfo = try await withCheckedThrowingContinuation { resume in
                    authgear.experimental.authgear.fetchUserInfo() { resume.resume(with: $0) }
                }
                handler(Handle(isPresented: false, viewController: viewController, result: .success(userInfo)))
            } catch {
                handler(Handle(isPresented: false, viewController: viewController, result: .failure(error)))
            }
        }
    }
}

@available(iOS 13.0, *)
internal class LatteViewController: UIViewController, LatteWebViewDelegate {
    weak var context: UIViewController?
    let webView: LatteWKWebView
    var handler: ((Result<LatteWebViewResult, Error>) -> Void)?

    init(
        context: UIViewController,
        request: LatteWebViewRequest
    ) {
        self.context = context
        self.webView = LatteWKWebView(request)
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.webView)
        self.webView.translatesAutoresizingMaskIntoConstraints = false
        self.webView.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        self.webView.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        self.webView.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
        self.webView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true

        self.webView.delegate = self

        self.webView.load()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func latteWebView(completed _: LatteWebView, result: Result<LatteWebViewResult, Error>) {
        self.handler?(result)
    }

    func latteWebView(onEvent _: LatteWebView, event: LatteWebViewEvent) {
        switch event {
        case .openEmailClient:
            let items = [
                Latte.EmailClient.mail,
                Latte.EmailClient.gmail
            ]
            let alert = Latte.makeChooseEmailClientAlertController(
                title: "Open mail app",
                message: "Which app would you like to open?",
                cancelLabel: "Cancel",
                items: items
            )
            self.context?.present(alert, animated: true)
        }
    }
}
