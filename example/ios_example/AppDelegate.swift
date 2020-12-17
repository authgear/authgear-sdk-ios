import Authgear
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var appContainer = App()

    func configureAuthgear(clientId: String, endpoint: String, isThirdPartyClient: Bool) {
        appContainer.container = Authgear(clientId: clientId, endpoint: endpoint, isThirdPartyClient: isThirdPartyClient)
        appContainer.container?.configure()
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    // Handle redirection after OAuth completed or failed
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        guard let c = appContainer.container else {
            // not yet configured
            return true
        }
        return c.application(app, open: url, options: options)
    }
}
