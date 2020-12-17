import Authgear
import SwiftUI

class MainViewModel: ObservableObject {
    let appState: AppState
    @Published var authgearActionErrorMessage: String?
    @Published var successAlertMessage: String?

    init(appState: AppState) {
        self.appState = appState
    }

    func configure(clientId: String, endpoint: String, isThirdPartyClient: Bool) {
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
        UserDefaults.standard.set(!isThirdPartyClient, forKey: "authgear.demo.isFirstPartyClient")
        appDelegate.configureAuthgear(clientId: clientId, endpoint: endpoint, isThirdPartyClient: isThirdPartyClient)
        successAlertMessage = "Configured Authgear successfully"
    }

    private func handleAuthorizeResult(_ result: Result<AuthorizeResult, Error>, errorMessage: String) -> Bool {
        switch result {
        case let .success(authResult):
            let userInfo = authResult.userInfo
            appState.user = UserInfo(
                userID: userInfo.sub,
                isAnonymous: userInfo.isAnonymous,
                isVerified: userInfo.isVerified
            )
            return true
        case let .failure(error):
            print(error)
            authgearActionErrorMessage = errorMessage
            return false
        }
    }

    func login(container: Authgear?) {
        container?.authorize(
            redirectURI: App.redirectURI,
            prompt: "login"
        ) { result in
            let success = self.handleAuthorizeResult(result, errorMessage: "Failed to login")
            if success {
                self.successAlertMessage = "Logged in successfully"
            }
        }
    }

    func loginAnonymously(container: Authgear?) {
        container?.authenticateAnonymously { result in
            let success = self.handleAuthorizeResult(result, errorMessage: "Failed to login anonymously")
            if success {
                self.successAlertMessage = "Logged in anonymously"
            }
        }
    }

    func openSetting(container: Authgear?) {
        container?.open(page: .settings)
    }

    func promoteAnonymousUser(container: Authgear?) {
        container?.promoteAnonymousUser(
            redirectURI: App.redirectURI
        ) { result in
            let success = self.handleAuthorizeResult(result, errorMessage: "Failed to promote anonymous user")
            if success {
                self.successAlertMessage = "Successfully promoted to normal authenticated user"
            }
        }
    }

    func fetchUserInfo(container: Authgear?) {
        container?.fetchUserInfo { userInfoResult in
            switch userInfoResult {
            case let .success(userInfo):
                self.appState.user = UserInfo(
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
                print(error)
                self.authgearActionErrorMessage = "Failed to fetch user info"
            }
        }
    }

    func logout(container: Authgear?) {
        container?.logout { result in
            switch result {
            case .success():
                self.appState.user = nil
                self.successAlertMessage = "Logged out successfully"
            case let .failure(error):
                print(error)
                self.authgearActionErrorMessage = "Failed to logout"
            }
        }
    }
}
