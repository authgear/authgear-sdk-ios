import Foundation
import LocalAuthentication
import UIKit

@available(iOS 13.0, *)
public struct LatteHandle<T: Sendable> {
    let task: Task<T, Error>

    init(task: Task<T, Error>) {
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
        currentView: UIView,
        xSecrets: [String: String] = [:],
        xState: [String: String] = [:],
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
                    xSecrets: xSecrets
                )
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
                try await latteVC.loadAndSuspendUntilReady(currentView, timeoutMillis: webViewLoadTimeoutMillis)
                
                let handle = LatteHandle<UserInfo>(task: Task { try await run1() })
                @Sendable @MainActor
                func run1() async throws -> UserInfo {
                    let result: LatteWebViewResult = try await withCheckedThrowingContinuation { [
                        weak self
                    ] next in
                        guard let nc = self?.eventNotificationCenter else { return }
                        let observer = nc.addObserver(
                            forName: LatteInternalEvent.resetPasswordCompleted.notificationName,
                            object: nil,
                            queue: nil,
                            using: { _ in
                                Task {
                                    await latteVC.dispatchWebViewSignal(signal: .resetPasswordCompleted)
                                }
                            }
                        )
                        latteVC.webView.completion = { (_, result) in
                            nc.removeObserver(observer)
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

    func reauthenticate(
        currentView: UIView,
        email: String,
        phone: String,
        biometricOptions: LatteBiometricOptions? = nil,
        xState: [String: String] = [:],
        uiLocales: [String]? = nil,
        completion: @escaping Completion<Bool>
    ) {
        Task { await run() }

        @Sendable @MainActor
        func run() async {
            do {
                guard let idTokenHint = self.authgear.idTokenHint else {
                    throw AuthgearError.unauthenticatedUser
                }
                let xSecrets = [
                    "phone": phone,
                    "email": email
                ]

                var laContext: LatteLAContext?
                var reauthXState = xState
                reauthXState["user_initiate"] = "reauth"

                var capabilities: Array<LatteCapability> = []

                if let biometricOptions = biometricOptions {
                    laContext = biometricOptions.laContext
                    let canEvaluate = laContext!.canEvaluatePolicy(biometricOptions.laPolicy)
                    if (canEvaluate) {
                        capabilities.append(.biometric)
                    }
                }

                reauthXState["capabilities"] = capabilities.map { $0.rawValue }.joined(separator: ",")
                let finalXState = try await makeXStateWithSecrets(
                    xState: reauthXState,
                    xSecrets: xSecrets
                )
                let request = try authgear.experimental.createReauthenticateRequest(
                    redirectURI: "latte://complete",
                    idTokenHint: idTokenHint,
                    xState: finalXState.encodeAsQuery(),
                    uiLocales: uiLocales
                ).get()
                let webViewRequest = LatteWebViewRequest(request: request)
                let latteVC = LatteViewController(request: webViewRequest, webviewIsInspectable: webviewIsInspectable)
                latteVC.webView.delegate = self
                
                try await latteVC.loadAndSuspendUntilReady(currentView, timeoutMillis: webViewLoadTimeoutMillis)
                let handle = LatteHandle<Bool>(task: Task { try await run1() })

                @Sendable @MainActor
                func run1() async throws -> Bool {
                    let result: Bool = try await withCheckedThrowingContinuation { [weak self] next in
                        guard let nc = self?.eventNotificationCenter else { return }
                        var isResumed = false
                        func resume(_ result: Result<Bool, Error>) {
                            guard isResumed == false else { return }
                            isResumed = true
                            next.resume(with: result)
                        }
                        let observer = nc.addObserver(
                            forName: LatteInternalEvent.resetPasswordCompleted.notificationName,
                            object: nil,
                            queue: nil,
                            using: { _ in
                                Task {
                                    await latteVC.dispatchWebViewSignal(signal: .resetPasswordCompleted)
                                }
                            }
                        )
                        latteVC.webView.completion = { (_, result) in
                            do {
                                nc.removeObserver(observer)
                                let finishURL = try result.get().unwrap()
                                self?.authgear.experimental.finishReauthentication(finishURL: finishURL, request: request) { r in
                                    resume(r.flatMap { _ in
                                        .success(true)
                                    })
                                }
                            } catch {
                                resume(.failure(wrapError(error: error)))
                            }
                        }
                        if let biometricOptions = biometricOptions, let laContext = laContext {
                            latteVC.webView.onReauthWithBiometric = { _ in
                                laContext.evaluatePolicy(
                                    biometricOptions.laPolicy,
                                    localizedReason: biometricOptions.localizedReason
                                ) { success, error in
                                    if (success) {
                                        resume(.success(true))
                                        return
                                    }
                                    if let error = error {
                                        if let laError = error as? LAError {
                                            switch laError.code {
                                            case .appCancel:
                                                fallthrough
                                            case .userCancel:
                                                fallthrough
                                            case .systemCancel:
                                                return
                                            default:
                                                break
                                            }
                                        }
                                        resume(.failure(error))
                                        return
                                    }
                                    resume(.success(false))
                                }
                            }
                        }
                    }
                    return result
                }
                completion(.success((latteVC, handle)))

            } catch {
                completion(.failure(error))
            }
        }
    }

    func reauthenticateV2(
        currentView: UIView,
        email: String,
        phone: String,
        xState: [String: String] = [:],
        uiLocales: [String]? = nil,
        completion: @escaping Completion<Bool>
    ) {
        Task { await run() }

        @Sendable @MainActor
        func run() async {
            do {
                guard let idTokenHint = self.authgear.idTokenHint else {
                    throw AuthgearError.unauthenticatedUser
                }
                let xSecrets = [
                    "phone": phone,
                    "email": email
                ]
                var reauthXState = xState
                reauthXState["user_initiate"] = "reauthv2"

                let finalXState = try await makeXStateWithSecrets(
                    xState: reauthXState,
                    xSecrets: xSecrets
                )
                let request = try authgear.experimental.createReauthenticateRequest(
                    redirectURI: "latte://complete",
                    idTokenHint: idTokenHint,
                    xState: finalXState.encodeAsQuery(),
                    uiLocales: uiLocales
                ).get()
                let webViewRequest = LatteWebViewRequest(request: request)
                let latteVC = LatteViewController(request: webViewRequest, webviewIsInspectable: webviewIsInspectable)
                latteVC.webView.delegate = self
                
                try await latteVC.loadAndSuspendUntilReady(currentView, timeoutMillis: webViewLoadTimeoutMillis)
                let handle = LatteHandle<Bool>(task: Task { try await run1() })

                @Sendable @MainActor
                func run1() async throws -> Bool {
                    let result: Bool = try await withCheckedThrowingContinuation { [weak self] next in
                        guard let nc = self?.eventNotificationCenter else { return }
                        var isResumed = false
                        func resume(_ result: Result<Bool, Error>) {
                            guard isResumed == false else { return }
                            isResumed = true
                            next.resume(with: result)
                        }
                        let observer = nc.addObserver(
                            forName: LatteInternalEvent.resetPasswordCompleted.notificationName,
                            object: nil,
                            queue: nil,
                            using: { _ in
                                Task {
                                    await latteVC.dispatchWebViewSignal(signal: .resetPasswordCompleted)
                                }
                            }
                        )
                        latteVC.webView.completion = { (_, result) in
                            do {
                                nc.removeObserver(observer)
                                let finishURL = try result.get().unwrap()
                                self?.authgear.experimental.finishReauthentication(finishURL: finishURL, request: request) { r in
                                    resume(r.flatMap { _ in
                                        .success(true)
                                    })
                                }
                            } catch {
                                resume(.failure(wrapError(error: error)))
                            }
                        }
                    }
                    return result
                }
                completion(.success((latteVC, handle)))

            } catch {
                completion(.failure(error))
            }
        }
    }

    func verifyEmail(
        currentView: UIView,
        email: String,
        xState: [String: String] = [:],
        uiLocales: [String]? = nil,
        completion: @escaping Completion<UserInfo>
    ) {
        Task { await run() }

        @Sendable @MainActor
        func run() async {
            do {
                let xSecrets = [
                    "email": email
                ]
                let finalXState = try await makeXStateWithSecrets(
                    xState: xState,
                    xSecrets: xSecrets
                )
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
                
                try await latteVC.loadAndSuspendUntilReady(currentView, timeoutMillis: webViewLoadTimeoutMillis)
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
        currentView: UIView,
        xState: [String: String] = [:],
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
                
                try await latteVC.loadAndSuspendUntilReady(currentView, timeoutMillis: webViewLoadTimeoutMillis)

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
        currentView: UIView,
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
                
                try await latteVC.loadAndSuspendUntilReady(currentView, timeoutMillis: webViewLoadTimeoutMillis)

                let handle = LatteHandle<Void>(task: Task { try await run1() })
                @Sendable @MainActor
                func run1() async throws {
                    let result: LatteWebViewResult = try await withCheckedThrowingContinuation { [weak self] next in
                        latteVC.webView.onResetPasswordCompleted = { _ in
                            self?.eventNotificationCenter.post(
                                name: LatteInternalEvent.resetPasswordCompleted.notificationName,
                                object: nil
                            )
                        }
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
        currentView: UIView,
        email: String,
        phoneNumber: String,
        xState: [String: String] = [:],
        uiLocales: [String]? = nil,
        completion: @escaping Completion<UserInfo>
    ) {
        Task { await run() }

        @Sendable @MainActor
        func run() async {
            do {
                let xSecrets = [
                    "phone": phoneNumber,
                    "email": email
                ]
                let finalXState = try await makeXStateWithSecrets(
                    xState: xState,
                    xSecrets: xSecrets
                )
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
                
                try await latteVC.loadAndSuspendUntilReady(currentView, timeoutMillis: webViewLoadTimeoutMillis)

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
    private var observedViewDidLoad: Bool = false
    private var observedLoadAndSuspendUntilReadyResolved: Bool = false

    init(
        request: LatteWebViewRequest,
        webviewIsInspectable: Bool
    ) {
        self.webView = LatteWKWebView(request: request, isInspectable: webviewIsInspectable)
        super.init(nibName: nil, bundle: nil)
        self.webView.viewController = self
        self.webView.translatesAutoresizingMaskIntoConstraints = false
    }
    
    internal func setLoadAndSuspendUntilReadyResolved() {
        DispatchQueue.main.async {
            self.observedLoadAndSuspendUntilReadyResolved = true
        }
    }
    
    internal func addWebviewToViewIfNeeded() {
        DispatchQueue.main.async {
            if (!self.observedViewDidLoad || !self.observedLoadAndSuspendUntilReadyResolved) {
                return
            }
            self.webView.removeFromSuperview()
            self.webView.removeConstraints(self.webView.constraints)
            self.view.addSubview(self.webView)
            NSLayoutConstraint.activate([
                self.webView.topAnchor.constraint(equalTo: self.view.topAnchor),
                self.webView.leftAnchor.constraint(equalTo: self.view.leftAnchor),
                self.webView.rightAnchor.constraint(equalTo: self.view.rightAnchor),
                self.webView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
            ])
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.observedViewDidLoad = true
        self.addWebviewToViewIfNeeded()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if (self.isBeingDismissed || self.isMovingFromParent) {
            // Cancel the flow if view controller being popped
            self.webView.completion?(self.webView, .failure(AuthgearError.cancel))
            self.webView.completion = nil
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func loadAndSuspendUntilReady(_ currentVisisbleView: UIView, timeoutMillis: Int) async throws {
        // Add the webview to a visible view so that it loads faster
        DispatchQueue.main.async {
            currentVisisbleView.addSubview(self.webView)
            // Set the size to 1x1, move it off screen
            NSLayoutConstraint.activate([
                self.webView.widthAnchor.constraint(equalToConstant: 1),
                self.webView.heightAnchor.constraint(equalToConstant: 1),
                self.webView.leadingAnchor.constraint(equalTo: currentVisisbleView.trailingAnchor, constant: 1000),
                self.webView.topAnchor.constraint(equalTo: currentVisisbleView.topAnchor)
            ])
            self.webView.load()
        }
        defer {
            self.setLoadAndSuspendUntilReadyResolved()
            self.addWebviewToViewIfNeeded()
        }
        await try self.suspendUntilReady(timeoutMillis: timeoutMillis)
    }

    private func suspendUntilReady(timeoutMillis: Int) async throws {
        try await withCheckedThrowingContinuation { (next: CheckedContinuation<Void, any Error>) in
            var isResumed = false
            var timeoutTask: Task<Void, Error>?
            self.webView.onReady = { _ in
                guard isResumed == false else { return }
                timeoutTask?.cancel()
                isResumed = true
                next.resume()
            }
            self.webView.completion = { (_, result) in
                guard isResumed == false else { return }
                timeoutTask?.cancel()
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
            timeoutTask = Task {
                try await Task.sleep(nanoseconds: UInt64(timeoutMillis) * 1_000_000)
                guard isResumed == false else { return }
                timeoutTask = nil
                isResumed = true
                next.resume(throwing: LatteError.timeout)
            }
        }
    }

    func dispatchWebViewSignal(signal: LatteBuiltInSignals) {
        self.webView.dispatchSignal(signal: signal)
    }
}
