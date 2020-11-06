import Authgear
import SwiftUI

class MainViewModel {
    func configure(clientId: String, endpoint: String) throws {
        guard clientId != "", endpoint != "" else {
            throw AppError.AuthgearConfigureFieldEmpty
        }
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        appDelegate!.configureAuthgear(clientId: clientId, endpoint: endpoint)
    }

    func login(container: Authgear?) {
        container?.authorize(
            redirectURI: App.redirectURI,
            prompt: "login"
        ) { result in
            print(result)
        }
    }

    func loginWithoutSession(container: Authgear?) {
        container?.authorize(
            redirectURI: App.redirectURI,
            prompt: "login",
            prefersSFSafariViewController: true
        ) { result in
            print(result)
        }
    }

    func loginAnonymously(container: Authgear?) {
        container?.authenticateAnonymously { result in
            print(result)
        }
    }

    func openSetting(container: Authgear?) {
        container?.open(page: .settings)
    }

    func promoteAnonymousUser(container: Authgear?) {
        container?.promoteAnonymousUser(
            redirectURI: App.redirectURI
        ) { result in
            print(result)
        }
    }

    func fetchUserInfo(container: Authgear?) {
        container?.fetchUserInfo { userInfo in
            print(userInfo)
        }
    }

    func logout(container: Authgear?) {
        container?.logout { result in
            print(result)
        }
    }
}
