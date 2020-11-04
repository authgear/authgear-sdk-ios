import Authgear
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    let container = Authgear(clientId: "portal", endpoint: "http://accounts.portal.local:3000")

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        window = UIWindow()
        container.configure()
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let vc = storyboard.instantiateViewController(withIdentifier: "Main")
            as? ViewController else {
            fatalError("Failed to load ViewController from storyboard.")
        }
        vc.configure(container: container)
        window?.rootViewController = vc
        window?.makeKeyAndVisible()
        return true
    }
}
