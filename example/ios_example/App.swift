import Authgear
import SwiftUI

struct UserInfo {
    var userID: String
    var isAnonymous: Bool
    var isVerified: Bool
}

class App: ObservableObject {
    static let redirectURI = "com.authgear.example://host/path"
    static let wechatUniversalLink = "https://authgear-demo.pandawork.com/wechat/"
    static let wechatRedirectURI = "https://authgear-demo.pandawork.com/authgear/open_wechat_app"
    static let wechatAppID = "wxa2f631873c63add1"

    @Published var container: Authgear?
    @Published var sessionState = SessionState.unknown
    @Published var user: UserInfo?
    @Published var page: String = ""
    @Published var authgearActionErrorMessage: String?
    @Published var successAlertMessage: String?
    @Published var biometricEnabled: Bool = false

    func configure(clientId: String, endpoint: String, page: String, transientSession: Bool) {
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
        UserDefaults.standard.set(page, forKey: "authgear.demo.page")
        UserDefaults.standard.set(transientSession, forKey: "authgear.demo.transientSession")
        appDelegate.configureAuthgear(clientId: clientId, endpoint: endpoint, transientSession: transientSession)
        successAlertMessage = "Configured Authgear successfully"
        self.page = page
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

    private func handleAuthorizeResult(_ result: Result<AuthorizeResult, Error>) -> Bool {
        self.updateBiometricState()
        switch result {
        case let .success(authResult):
            let userInfo = authResult.userInfo
            user = UserInfo(
                userID: userInfo.sub,
                isAnonymous: userInfo.isAnonymous,
                isVerified: userInfo.isVerified
            )
            return true
        case let .failure(error):
            self.setError(error)
            return false
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
        container?.authorize(
            redirectURI: App.redirectURI,
            wechatRedirectURI: App.wechatRedirectURI,
            page: page
        ) { result in
            let success = self.handleAuthorizeResult(result)
            if success {
                self.successAlertMessage = "Logged in successfully"
            }
        }
    }

    func reauthenticate() {
        container?.reauthenticate(redirectURI: App.redirectURI) { result in
            self.updateBiometricState()
            switch result {
            case let .success(authResult):
                let userInfo = authResult.userInfo
                self.user = UserInfo(
                    userID: userInfo.sub,
                    isAnonymous: userInfo.isAnonymous,
                    isVerified: userInfo.isVerified
                )
                self.successAlertMessage = "Reauthenticated successfully"
            case let .failure(error):
                self.setError(error)
            }
        }
    }

    func reauthenticateWebOnly() {
        container?.reauthenticate(redirectURI: App.redirectURI, skipUsingBiometric: true) { result in
            self.updateBiometricState()
            switch result {
            case let .success(authResult):
                let userInfo = authResult.userInfo
                self.user = UserInfo(
                    userID: userInfo.sub,
                    isAnonymous: userInfo.isAnonymous,
                    isVerified: userInfo.isVerified
                )
                self.successAlertMessage = "Reauthenticated successfully"
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
        container?.authenticateBiometric { result in
            let success = self.handleAuthorizeResult(result)
            if success {
                self.successAlertMessage = "Logged in with biometric"
            }
        }
    }

    func loginAnonymously() {
        container?.authenticateAnonymously { result in
            let success = self.handleAuthorizeResult(result)
            if success {
                self.successAlertMessage = "Logged in anonymously"
            }
        }
    }

    func openSetting() {
        container?.open(
            page: .settings,
            wechatRedirectURI: App.wechatRedirectURI
        )
    }

    func promoteAnonymousUser() {
        container?.promoteAnonymousUser(
            redirectURI: App.redirectURI,
            wechatRedirectURI: App.wechatRedirectURI
        ) { result in
            let success = self.handleAuthorizeResult(result)
            if success {
                self.successAlertMessage = "Successfully promoted to normal authenticated user"
            }
        }
    }

    func fetchUserInfo() {
        container?.fetchUserInfo { userInfoResult in
            switch userInfoResult {
            case let .success(userInfo):
                self.user = UserInfo(
                    userID: userInfo.sub,
                    isAnonymous: userInfo.isAnonymous,
                    isVerified: userInfo.isVerified
                )
                self.successAlertMessage = [
                    "User Info:",
                    "",
                    "User ID: \(userInfo.sub)",
                    "Is Verified: \(userInfo.isVerified)",
                    "Is Anonymous: \(userInfo.isAnonymous)",
                    "ISS: \(userInfo.iss)"
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
                self.successAlertMessage = "Logged out successfully"
            case let .failure(error):
                self.setError(error)
            }
        }
    }
}
