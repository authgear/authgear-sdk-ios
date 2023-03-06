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
                    page: page
                ).get()

                let webViewRequest = LatteWebViewRequest(request: request)
                let latteVC = LatteViewController(context: context, request: webViewRequest)
                latteVC.delegate = self
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
        state: String? = nil,
        uiLocales: [String]? = nil,
        handler: @escaping ResultHandler<UserInfo>
    ) {
        Task { await run() }

        @Sendable @MainActor
        func run() async {
            var viewController: LatteViewController?
            do {
                let entryURL = customUIEndpoint + "/verify/email"
                let redirectURI = customUIEndpoint + "/verify/email/completed"
                var queryList = [
                    "email=\(email.encodeAsQueryComponent()!)",
                    "redirect_uri=\(redirectURI.encodeAsQueryComponent()!)"
                ]
                queryList.append(
                    contentsOf: constructUIParamQuery(
                        state: state,
                        uiLocales: uiLocales
                    ))
                let query = queryList.joined(separator: "&")
                let verifyEmailURL = "\(entryURL)?\(query)"

                let url: URL = try await withCheckedThrowingContinuation { resume in
                    authgear.experimental.generateURL(redirectURI: verifyEmailURL) {
                        resume.resume(with: $0)
                    }
                }

                let webViewRequest = LatteWebViewRequest(url: url, redirectURI: redirectURI)
                let latteVC = LatteViewController(context: context, request: webViewRequest)
                latteVC.delegate = self
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
        state: String? = nil,
        uiLocales: [String]? = nil,
        handler: @escaping ResultHandler<Void>
    ) {
        Task { await run() }

        @Sendable @MainActor
        func run() async {
            var viewController: LatteViewController?
            do {
                let entryURL = customUIEndpoint + "/settings/change_password"
                let redirectURI = "latte://complete"

                var queryList = [
                    "redirect_uri=\(redirectURI.encodeAsQueryComponent()!)"
                ]
                queryList.append(
                    contentsOf: constructUIParamQuery(
                        state: state,
                        uiLocales: uiLocales
                    ))
                let query = queryList.joined(separator: "&")
                let entryURLWithWQuery = "\(entryURL)?\(query)"

                let url: URL = try await withCheckedThrowingContinuation { resume in
                    authgear.experimental.generateURL(redirectURI: entryURLWithWQuery) {
                        resume.resume(with: $0)
                    }
                }

                let webViewRequest = LatteWebViewRequest(url: url, redirectURI: redirectURI)
                let latteVC = LatteViewController(context: context, request: webViewRequest)
                latteVC.delegate = self
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
        url: URL,
        handler: @escaping ResultHandler<Void>
    ) {
        Task { await run() }
        @Sendable @MainActor
        func run() async {
            var viewController: LatteViewController?
            do {
                var entryURLComponents = URLComponents(string: customUIEndpoint + "/recovery/reset")!
                let redirectURI = "latte://reset-complete"
                var newQueryParams = URLComponents(url: url, resolvingAgainstBaseURL: true)?.queryParams ?? [:]
                newQueryParams["redirect_uri"] = redirectURI
                let newQuery = newQueryParams.encodeAsQuery()
                entryURLComponents.percentEncodedQuery = newQuery
                let entryURL = entryURLComponents.url!.absoluteString
                let webViewRequest = LatteWebViewRequest(url: URL(string: entryURL)!, redirectURI: redirectURI)
                let latteVC = LatteViewController(context: context, request: webViewRequest)
                latteVC.delegate = self
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
        phoneNumber: String,
        state: String? = nil,
        uiLocales: [String]? = nil,
        handler: @escaping ResultHandler<UserInfo>
    ) {
        Task { await run() }

        @Sendable @MainActor
        func run() async {
            var viewController: LatteViewController?
            do {
                let entryURL = customUIEndpoint + "/settings/change_email"
                let redirectURI = customUIEndpoint + "/verify/email/completed"

                var queryList = [
                    "email=\(email.encodeAsQueryComponent()!)",
                    "phone=\(phoneNumber.encodeAsQueryComponent()!)",
                    "redirect_uri=\(redirectURI.encodeAsQueryComponent()!)"
                ]
                queryList.append(
                    contentsOf: constructUIParamQuery(
                        state: state,
                        uiLocales: uiLocales
                    ))
                let query = queryList.joined(separator: "&")
                let changeEmailURL = "\(entryURL)?\(query)"

                let url: URL = try await withCheckedThrowingContinuation { resume in
                    authgear.experimental.generateURL(redirectURI: changeEmailURL) {
                        resume.resume(with: $0)
                    }
                }

                let webViewRequest = LatteWebViewRequest(url: url, redirectURI: redirectURI)
                let latteVC = LatteViewController(context: context, request: webViewRequest)
                latteVC.delegate = self
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

    private func constructUIParamQuery(
        state: String? = nil,
        uiLocales: [String]? = nil
    ) -> Array<String> {
        var result: Array<String> = []
        if let mustState = state {
            result.append("state=\(mustState.encodeAsQueryComponent()!)")
        }
        if let mustUILocales = uiLocales {
            result.append("ui_locales=\(UILocales.stringify(uiLocales: mustUILocales).encodeAsQueryComponent()!)")
        }
        return result
    }
}

@available(iOS 13.0, *)
internal protocol LatteViewControllerDelegate: AnyObject {
    func latteViewController(onEvent _: LatteViewController, event: LatteWebViewEvent)
}

@available(iOS 13.0, *)
internal class LatteViewController: UIViewController, LatteWebViewDelegate {
    weak var context: UIViewController?
    let webView: LatteWKWebView
    var handler: ((Result<LatteWebViewResult, Error>) -> Void)?
    weak var delegate: LatteViewControllerDelegate?

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
        self.delegate?.latteViewController(onEvent: self, event: event)

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
        case .viewPage(event: _):
            break
        }
    }
}

private extension Dictionary where Key == String, Value == String {
    func encodeAsQuery() -> String {
        self.keys.map { "\($0)=\(self[$0]!.encodeAsQueryComponent()!)" }
            .joined(separator: "&")
    }
}
