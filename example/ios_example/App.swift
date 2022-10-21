import Authgear
import SwiftUI

class App: ObservableObject {
    static let redirectURI = "com.authgear.example://host/path"
    static let wechatUniversalLink = "https://authgear-demo.pandawork.com/wechat/"
    static let wechatRedirectURI = "https://authgear-demo.pandawork.com/authgear/open_wechat_app"
    static let wechatAppID = "wxa2f631873c63add1"

    var systemColorScheme: SwiftUI.ColorScheme? {
        let s = UIApplication.shared.keyWindow?.rootViewController?.traitCollection.userInterfaceStyle
        switch s {
        case .light:
            return .light
        case .dark:
            return .dark
        default:
            return .light
        }
    }

    var colorScheme: AuthgearColorScheme? {
        self.explicitColorScheme ?? self.systemColorScheme?.authgear
    }

    @Published var container: Authgear?
    @Published var sessionState = SessionState.unknown
    @Published var user: UserInfo?
    @Published var authenticationPage: AuthenticationPage?
    @Published var explicitColorScheme: AuthgearColorScheme?
    @Published var authgearActionErrorMessage: String?
    @Published var successAlertMessage: String?
    @Published var biometricEnabled: Bool = false

    func configure(
        clientId: String,
        endpoint: String,
        authenticationPage: AuthenticationPage?,
        colorScheme: AuthgearColorScheme?,
        tokenStorage: String,
        shareSessionWithSystemBrowser: Bool
    ) {
        guard clientId != "", endpoint != "" else {
            authgearActionErrorMessage = "Please input client ID and endpoint"
            return
        }
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            authgearActionErrorMessage = "Failed to configure Authgear"
            return
        }
        UserDefaults.standard.set(clientId, forKey: "authgear.demo.clientID")
        UserDefaults.standard.set(endpoint, forKey: "authgear.demo.endpoint")
        UserDefaults.standard.set(tokenStorage, forKey: "authgear.demo.tokenStorage")
        UserDefaults.standard.set(shareSessionWithSystemBrowser, forKey: "authgear.demo.shareSessionWithSystemBrowser")
        appDelegate.configureAuthgear(clientId: clientId, endpoint: endpoint, tokenStorage: tokenStorage, shareSessionWithSystemBrowser: shareSessionWithSystemBrowser)
        self.authenticationPage = authenticationPage
        self.explicitColorScheme = colorScheme
        self.updateBiometricState()
    }

    private func updateBiometricState() {
        var supported = false
        do {
            try self.container?.checkBiometricSupported()
            supported = true
        } catch {}
        self.biometricEnabled = false
        if supported {
            self.biometricEnabled = (try? self.container?.isBiometricEnabled()) ?? false
        }
    }

    private func handleAuthorizeResult(_ result: Result<UserInfo, Error>) {
        self.updateBiometricState()
        switch result {
        case let .success(userInfo):
            user = userInfo
        case let .failure(error):
            self.setError(error)
        }
    }

    private func setError(_ error: Error) {
        if let authgearError = error as? AuthgearError {
            switch authgearError {
            case .cancel:
                break
            case .biometricPrivateKeyNotFound:
                self.authgearActionErrorMessage = "Your Touch ID or Face ID has changed. For security reason, you have to set up biometric authentication again."
            case .biometricNotSupportedOrPermissionDenied:
                self.authgearActionErrorMessage = "If the developer should performed checking, then it is likely that you have denied the permission of Face ID. Please enable it in Settings"
            case .biometricNoPasscode:
                self.authgearActionErrorMessage = "You device does not have passcode set up. Please set up a passcode"
            case .biometricNoEnrollment:
                self.authgearActionErrorMessage = "You do not have Face ID or Touch ID set up yet. Please set it up first"
            case .biometricLockout:
                self.authgearActionErrorMessage = "The biometric is locked out due to too many failed attempts. The developer should handle this error by using normal authentication as a fallback. So normally you should not see this error"
            default:
                self.authgearActionErrorMessage = "\(error)"
            }
        } else {
            self.authgearActionErrorMessage = "\(error)"
        }
    }

    func login() {
        container?.authenticate(
            redirectURI: App.redirectURI,
            colorScheme: self.colorScheme,
            wechatRedirectURI: App.wechatRedirectURI,
            page: self.authenticationPage,
            handler: self.handleAuthorizeResult
        )
    }

    func reauthenticate() {
        container?.refreshIDToken(handler: { result in
            switch result {
            case .success:
                self.container?.reauthenticate(
                    redirectURI: App.redirectURI,
                    colorScheme: self.colorScheme,
                    localizedReason: "Authenticate with biometric",
                    policy: .deviceOwnerAuthenticationWithBiometrics
                ) { result in
                    self.updateBiometricState()
                    switch result {
                    case let .success(userInfo):
                        self.user = userInfo
                    case let .failure(error):
                        self.setError(error)
                    }
                }
            case let .failure(error):
                self.setError(error)
            }
        })
    }

    func reauthenticateWebOnly() {
        container?.refreshIDToken { result in
            switch result {
            case .success:
                self.container?.reauthenticate(
                    redirectURI: App.redirectURI,
                    colorScheme: self.colorScheme
                ) { result in
                    self.updateBiometricState()
                    switch result {
                    case let .success(userInfo):
                        self.user = userInfo
                    case let .failure(error):
                        self.setError(error)
                    }
                }
            case let .failure(error):
                self.setError(error)
            }
        }
    }

    func enableBiometric() {
        container?.enableBiometric(
            localizedReason: "Enable biometric!",
            constraint: .biometryCurrentSet
        ) { result in
            if case let .failure(error) = result {
                self.setError(error)
            }
            self.updateBiometricState()
        }
    }

    func disableBiometric() {
        do {
            try container?.disableBiometric()
        } catch {
            self.setError(error)
        }
        self.updateBiometricState()
    }

    func loginBiometric() {
        container?.authenticateBiometric(
            localizedReason: "Authenticate with biometric",
            policy: .deviceOwnerAuthenticationWithBiometrics,
            handler: self.handleAuthorizeResult
        )
    }

    func loginAnonymously() {
        container?.authenticateAnonymously(handler: self.handleAuthorizeResult)
    }

    func openSetting() {
        container?.open(
            page: .settings,
            colorScheme: self.colorScheme,
            wechatRedirectURI: App.wechatRedirectURI
        )
    }

    func promoteAnonymousUser() {
        container?.promoteAnonymousUser(
            redirectURI: App.redirectURI,
            colorScheme: self.colorScheme,
            wechatRedirectURI: App.wechatRedirectURI,
            handler: self.handleAuthorizeResult
        )
    }

    func fetchUserInfo() {
        container?.fetchUserInfo { userInfoResult in
            switch userInfoResult {
            case let .success(userInfo):
                self.user = userInfo
                self.successAlertMessage = [
                    "User Info:",
                    "",
                    "User ID: \(userInfo.sub)",
                    "Is Verified: \(userInfo.isVerified)",
                    "Is Anonymous: \(userInfo.isAnonymous)"
                ].joined(separator: "\n")
            case let .failure(error):
                self.setError(error)
            }
        }
    }

    func showAuthTime() {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .long
        if let authTime = container?.authTime {
            self.successAlertMessage = "auth_time: \(f.string(from: authTime))"
        }
    }

    func logout() {
        container?.logout { result in
            switch result {
            case .success():
                self.user = nil
            case let .failure(error):
                self.setError(error)
            }
        }
    }
}
