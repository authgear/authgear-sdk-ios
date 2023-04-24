import Foundation
import UIKit

@available(iOS 13.0, *)
public struct LatteHandle<T> {
    let doWait: (_ completion: @escaping (Result<T, Error>) -> Void) -> Void

    init(_ doWait: @escaping (_ completion: @escaping (Result<T, Error>) -> Void) -> Void) {
        self.doWait = doWait
    }

    public func wait(completion: @escaping (Result<T, Error>) -> Void) {
        doWait(completion)
    }
}

@available(iOS 13.0, *)
public extension Latte {
    typealias Completion<T> = (Result<(UIViewController, LatteHandle<T>), Error>) -> Void

    func authenticate(
        xState: String? = nil,
        prompt: [PromptOption]? = nil,
        loginHint: String? = nil,
        uiLocales: [String]? = nil,
        colorScheme: ColorScheme? = nil,
        wechatRedirectURI: String? = nil,
        page: AuthenticationPage? = nil,
        completion: @escaping Completion<UserInfo>
    ) {
        Task { await run() }

        @Sendable @MainActor
        func run() async {
            do {
                let request = try authgear.experimental.createAuthenticateRequest(
                    redirectURI: "latte://complete",
                    xState: xState,
                    prompt: prompt,
                    loginHint: loginHint,
                    uiLocales: uiLocales,
                    colorScheme: colorScheme,
                    wechatRedirectURI: wechatRedirectURI,
                    page: page
                ).get()

                let webViewRequest = LatteWebViewRequest(request: request)
                let latteVC = LatteViewController(request: webViewRequest, webviewIsInspectable: webviewIsInspectable)
                latteVC.webView.delegate = self
                latteVC.webView.load()

                let _: Void = try await withCheckedThrowingContinuation { next in
                    latteVC.webView.onReady = { _ in
                        next.resume()
                    }
                    latteVC.webView.completion = { (_, result) in
                        next.resume(with: result.map { _ in () })
                    }
                }

                let handle = LatteHandle<UserInfo> { completion in
                    Task { await run() }
                    @Sendable @MainActor
                    func run() async {
                        do {
                            let result: LatteWebViewResult = try await withCheckedThrowingContinuation { next in
                                latteVC.webView.completion = { (_, result) in
                                    next.resume(with: result)
                                }
                            }
                            let userInfo = try await result.handle { _, completion in
                                self.authgear.experimental.finishAuthentication(finishURL: result.finishURL, request: request, handler: completion)
                            }
                            completion(.success(userInfo))
                        } catch {
                            completion(.failure(error))
                        }
                    }
                }
                completion(.success((latteVC, handle)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func verifyEmail(
        email: String,
        xState: String? = nil,
        uiLocales: [String]? = nil,
        completion: @escaping Completion<UserInfo>
    ) {
        Task { await run() }

        @Sendable @MainActor
        func run() async {
            do {
                let entryURL = customUIEndpoint + "/verify/email"
                let redirectURI = "latte://complete"
                var queryList = [
                    "email=\(email.encodeAsQueryComponent()!)",
                    "redirect_uri=\(redirectURI.encodeAsQueryComponent()!)"
                ]
                queryList.append(
                    contentsOf: constructUIParamQuery(
                        xState: xState,
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
                let latteVC = LatteViewController(request: webViewRequest, webviewIsInspectable: webviewIsInspectable)
                latteVC.webView.delegate = self
                latteVC.webView.load()

                let _: Void = try await withCheckedThrowingContinuation { next in
                    latteVC.webView.onReady = { _ in
                        next.resume()
                    }
                    latteVC.webView.completion = { (_, result) in
                        next.resume(with: result.map { _ in () })
                    }
                }

                let handle = LatteHandle<UserInfo> { completion in
                    Task { await run() }
                    @Sendable @MainActor
                    func run() async {
                        do {
                            let result: LatteWebViewResult = try await withCheckedThrowingContinuation { next in
                                latteVC.webView.completion = { (_, result) in
                                    next.resume(with: result)
                                }
                            }
                            let userInfo = try await result.handle { _, completion in
                                self.authgear.fetchUserInfo(handler: completion)
                            }
                            completion(.success(userInfo))
                        } catch {
                            completion(.failure(error))
                        }
                    }
                }
                completion(.success((latteVC, handle)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func changePassword(
        xState: String? = nil,
        uiLocales: [String]? = nil,
        completion: @escaping Completion<Void>
    ) {
        Task { await run() }

        @Sendable @MainActor
        func run() async {
            do {
                let entryURL = customUIEndpoint + "/settings/change_password"
                let redirectURI = "latte://complete"

                var queryList = [
                    "redirect_uri=\(redirectURI.encodeAsQueryComponent()!)"
                ]
                queryList.append(
                    contentsOf: constructUIParamQuery(
                        xState: xState,
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
                let latteVC = LatteViewController(request: webViewRequest, webviewIsInspectable: webviewIsInspectable)
                latteVC.webView.delegate = self
                latteVC.webView.load()

                let _: Void = try await withCheckedThrowingContinuation { next in
                    latteVC.webView.onReady = { _ in
                        next.resume()
                    }
                    latteVC.webView.completion = { (_, result) in
                        next.resume(with: result.map { _ in () })
                    }
                }

                let handle = LatteHandle<Void> { completion in
                    Task { await run() }
                    @Sendable @MainActor
                    func run() async {
                        do {
                            let result: LatteWebViewResult = try await withCheckedThrowingContinuation { next in
                                latteVC.webView.completion = { (_, result) in
                                    next.resume(with: result)
                                }
                            }
                            let _: Void = try await result.handle { _, completion in
                                completion(.success(()))
                            }
                            completion(.success(()))
                        } catch {
                            completion(.failure(error))
                        }
                    }
                }
                completion(.success((latteVC, handle)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func resetPassword(
        url: URL,
        completion: @escaping Completion<Void>
    ) {
        Task { await run() }
        @Sendable @MainActor
        func run() async {
            do {
                var entryURLComponents = URLComponents(string: customUIEndpoint + "/recovery/reset")!
                let redirectURI = "latte://complete"
                var newQueryParams = URLComponents(url: url, resolvingAgainstBaseURL: true)?.queryParams ?? [:]
                newQueryParams["redirect_uri"] = redirectURI
                let newQuery = newQueryParams.encodeAsQuery()
                entryURLComponents.percentEncodedQuery = newQuery
                let entryURL = entryURLComponents.url!.absoluteString
                let webViewRequest = LatteWebViewRequest(url: URL(string: entryURL)!, redirectURI: redirectURI)
                let latteVC = LatteViewController(request: webViewRequest, webviewIsInspectable: webviewIsInspectable)
                latteVC.webView.delegate = self
                latteVC.webView.load()

                let _: Void = try await withCheckedThrowingContinuation { next in
                    latteVC.webView.onReady = { _ in
                        next.resume()
                    }
                    latteVC.webView.completion = { (_, result) in
                        next.resume(with: result.map { _ in () })
                    }
                }

                let handle = LatteHandle<Void> { completion in
                    Task { await run() }
                    @Sendable @MainActor
                    func run() async {
                        do {
                            let result: LatteWebViewResult = try await withCheckedThrowingContinuation { next in
                                latteVC.webView.completion = { (_, result) in
                                    next.resume(with: result)
                                }
                            }
                            let _: Void = try await result.handle { _, completion in
                                completion(.success(()))
                            }
                            completion(.success(()))
                        } catch {
                            completion(.failure(error))
                        }
                    }
                }
                completion(.success((latteVC, handle)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func changeEmail(
        email: String,
        phoneNumber: String,
        xState: String? = nil,
        uiLocales: [String]? = nil,
        completion: @escaping Completion<UserInfo>
    ) {
        Task { await run() }

        @Sendable @MainActor
        func run() async {
            do {
                let entryURL = customUIEndpoint + "/settings/change_email"
                let redirectURI = "latte://complete"

                var queryList = [
                    "email=\(email.encodeAsQueryComponent()!)",
                    "phone=\(phoneNumber.encodeAsQueryComponent()!)",
                    "redirect_uri=\(redirectURI.encodeAsQueryComponent()!)"
                ]
                queryList.append(
                    contentsOf: constructUIParamQuery(
                        xState: xState,
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
                let latteVC = LatteViewController(request: webViewRequest, webviewIsInspectable: webviewIsInspectable)
                latteVC.webView.delegate = self
                latteVC.webView.load()

                let _: Void = try await withCheckedThrowingContinuation { next in
                    latteVC.webView.onReady = { _ in
                        next.resume()
                    }
                    latteVC.webView.completion = { (_, result) in
                        next.resume(with: result.map { _ in () })
                    }
                }

                let handle = LatteHandle<UserInfo> { completion in
                    Task { await run() }
                    @Sendable @MainActor
                    func run() async {
                        do {
                            let result: LatteWebViewResult = try await withCheckedThrowingContinuation { next in
                                latteVC.webView.completion = { (_, result) in
                                    next.resume(with: result)
                                }
                            }
                            let userInfo = try await result.handle { _, completion in
                                self.authgear.fetchUserInfo(handler: completion)
                            }
                            completion(.success(userInfo))
                        } catch {
                            completion(.failure(error))
                        }
                    }
                }
                completion(.success((latteVC, handle)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private func constructUIParamQuery(
        xState: String? = nil,
        uiLocales: [String]? = nil
    ) -> Array<String> {
        var result: Array<String> = []
        if let mustXState = xState {
            result.append("x_state=\(mustXState.encodeAsQueryComponent()!)")
        }
        if let mustUILocales = uiLocales {
            result.append("ui_locales=\(UILocales.stringify(uiLocales: mustUILocales).encodeAsQueryComponent()!)")
        }
        return result
    }
}

@available(iOS 13.0, *)
class LatteViewController: UIViewController {
    let webView: LatteWKWebView

    init(
        request: LatteWebViewRequest,
        webviewIsInspectable: Bool
    ) {
        self.webView = LatteWKWebView(request: request, isInspectable: webviewIsInspectable)
        super.init(nibName: nil, bundle: nil)
        self.webView.viewController = self
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.webView)
        self.webView.translatesAutoresizingMaskIntoConstraints = false
        self.webView.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        self.webView.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        self.webView.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
        self.webView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension Dictionary where Key == String, Value == String {
    func encodeAsQuery() -> String {
        self.keys.map { "\($0)=\(self[$0]!.encodeAsQueryComponent()!)" }
            .joined(separator: "&")
    }
}
