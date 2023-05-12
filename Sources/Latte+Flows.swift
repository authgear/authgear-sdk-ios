import Foundation
import UIKit

@available(iOS 13.0, *)
public struct LatteHandle<T: Sendable> {
    let task: Task<T, Error>

    internal init(task: Task<T, Error>) {
        self.task = task
    }

    public func wait(completion: @escaping (Result<T, Error>) -> Void) {
        Task { await run() }
        @Sendable
        func run() async {
            do {
                let value = try await self.task.value
                completion(.success(value))
            } catch {
                completion(.failure(error))
            }
        }
    }
}

@available(iOS 13.0, *)
public extension Latte {
    typealias Completion<T> = (Result<(UIViewController, LatteHandle<T>), Error>) -> Void

    func preload(completion: @escaping (Result<Void, Error>) -> Void) {
        Task { await run() }
        @Sendable @MainActor
        func run() async {
            do {
                let url = URL(string: self.customUIEndpoint + "/preload")!
                let request = LatteWebViewRequest(url: url, redirectURI: "latte://complete")
                let webView = LatteWKWebView(request: request, isInspectable: self.webviewIsInspectable)
                webView.load()
                try await withCheckedThrowingContinuation { next in
                    var isResumed = false
                    webView.onReady = { _ in
                        guard isResumed == false else { return }
                        isResumed = true
                        next.resume()
                    }
                    webView.completion = { (_, result) in
                        guard isResumed == false else { return }
                        switch result {
                        case let .success(r):
                            do {
                                // If there is an error in the result, throw it
                                _ = try r.unwrap()
                                next.resume()
                            } catch {
                                next.resume(throwing: error)
                            }
                        case let .failure(error):
                            next.resume(throwing: error)
                        }
                    }
                }
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func authenticate(
        xSecrets: [String:String] = [:],
        xState: [String:String] = [:],
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
                
                let finalXState = try await makeXStateWithSecrets(
                    xState: xState,
                    xSecrets: xSecrets)
                let request = try authgear.experimental.createAuthenticateRequest(
                    redirectURI: "latte://complete",
                    xState: finalXState.encodeAsQuery(),
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

                try await latteVC.suspendUntilReady()

                let handle = LatteHandle<UserInfo>(task: Task { try await run1() })
                @Sendable @MainActor
                func run1() async throws -> UserInfo {
                    let result: LatteWebViewResult = try await withCheckedThrowingContinuation { next in
                        latteVC.webView.completion = { (_, result) in
                            next.resume(with: result)
                        }
                    }
                    let finishURL = try result.unwrap()
                    let userInfo = try await withCheckedThrowingContinuation { next in
                        self.authgear.experimental.finishAuthentication(finishURL: finishURL, request: request) { next.resume(with: $0) }
                    }
                    return userInfo
                }
                completion(.success((latteVC, handle)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func verifyEmail(
        email: String,
        xState: [String:String] = [:],
        uiLocales: [String]? = nil,
        completion: @escaping Completion<UserInfo>
    ) {
        Task { await run() }

        @Sendable @MainActor
        func run() async {
            do {
                let xSecrets = [
                    "email": email,
                ]
                let finalXState = try await makeXStateWithSecrets(
                    xState: xState,
                    xSecrets: xSecrets)
                let entryURL = customUIEndpoint + "/verify/email"
                let redirectURI = "latte://complete"
                var queryList = [
                    "redirect_uri=\(redirectURI.encodeAsQueryComponent()!)"
                ]
                queryList.append(
                    contentsOf: constructUIParamQuery(
                        xState: finalXState.encodeAsQuery(),
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

                try await latteVC.suspendUntilReady()

                let handle = LatteHandle<UserInfo>(task: Task { try await run1() })
                @Sendable @MainActor
                func run1() async throws -> UserInfo {
                    let result: LatteWebViewResult = try await withCheckedThrowingContinuation { next in
                        latteVC.webView.completion = { (_, result) in
                            next.resume(with: result)
                        }
                    }
                    _ = try result.unwrap()
                    let userInfo = try await withCheckedThrowingContinuation { next in
                        self.authgear.fetchUserInfo { next.resume(with: $0) }
                    }
                    return userInfo
                }
                completion(.success((latteVC, handle)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func changePassword(
        xState: [String:String] = [:],
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
                        xState: xState.encodeAsQuery(),
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

                try await latteVC.suspendUntilReady()

                let handle = LatteHandle<Void>(task: Task { try await run1() })
                @Sendable @MainActor
                func run1() async throws {
                    let result: LatteWebViewResult = try await withCheckedThrowingContinuation { next in
                        latteVC.webView.completion = { (_, result) in
                            next.resume(with: result)
                        }
                    }
                    _ = try result.unwrap()
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

                try await latteVC.suspendUntilReady()

                let handle = LatteHandle<Void>(task: Task { try await run1() })
                @Sendable @MainActor
                func run1() async throws {
                    let result: LatteWebViewResult = try await withCheckedThrowingContinuation { next in
                        latteVC.webView.completion = { (_, result) in
                            next.resume(with: result)
                        }
                    }
                    _ = try result.unwrap()
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
        xState: [String:String] = [:],
        uiLocales: [String]? = nil,
        completion: @escaping Completion<UserInfo>
    ) {
        Task { await run() }

        @Sendable @MainActor
        func run() async {
            do {
                let xSecrets = [
                    "phone": phoneNumber,
                    "email": email,
                ]
                let finalXState = try await makeXStateWithSecrets(
                    xState: xState,
                    xSecrets: xSecrets)
                let entryURL = customUIEndpoint + "/settings/change_email"
                let redirectURI = "latte://complete"

                var queryList = [
                    "redirect_uri=\(redirectURI.encodeAsQueryComponent()!)"
                ]
                queryList.append(
                    contentsOf: constructUIParamQuery(
                        xState: finalXState.encodeAsQuery(),
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

                try await latteVC.suspendUntilReady()

                let handle = LatteHandle<UserInfo>(task: Task { try await run1() })
                @Sendable @MainActor
                func run1() async throws -> UserInfo {
                    let result: LatteWebViewResult = try await withCheckedThrowingContinuation { next in
                        latteVC.webView.completion = { (_, result) in
                            next.resume(with: result)
                        }
                    }
                    _ = try result.unwrap()
                    let userInfo = try await withCheckedThrowingContinuation { next in
                        self.authgear.fetchUserInfo { next.resume(with: $0) }
                    }
                    return userInfo
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
    
    private func makeXStateWithSecrets(
        xState: Dictionary<String, String>,
        xSecrets: Dictionary<String, String>
    ) async throws -> Dictionary<String, String> {
        var finalXState = xState
        if !xSecrets.isEmpty {
            let tokenParamsJson = try JSONSerialization.data(withJSONObject: xSecrets)
            let token = try await withCheckedThrowingContinuation { next in
                self.tokenize(data: tokenParamsJson) { next.resume(with: $0) }
            }
            finalXState["x_secrets_token"] = token
        }
        return finalXState
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

    internal func suspendUntilReady() async throws {
        try await withCheckedThrowingContinuation { next in
            var isResumed = false
            self.webView.onReady = { _ in
                guard isResumed == false else { return }
                isResumed = true
                next.resume()
            }
            self.webView.completion = { (_, result) in
                guard isResumed == false else { return }
                switch result {
                case let .success(r):
                    do {
                        // If there is an error in the result, throw it
                        _ = try r.unwrap()
                        next.resume()
                    } catch {
                        next.resume(throwing: error)
                    }
                case let .failure(error):
                    next.resume(throwing: error)
                }
            }
        }
    }
}

private extension Dictionary where Key == String, Value == String {
    func encodeAsQuery() -> String {
        self.keys.map { "\($0)=\(self[$0]!.encodeAsQueryComponent()!)" }
            .joined(separator: "&")
    }
}
