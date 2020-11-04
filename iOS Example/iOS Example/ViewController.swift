import Authgear
import UIKit

class ViewController: UIViewController {
    var container: Authgear?

    public func configure(container: Authgear) {
        self.container = container
    }

    @IBAction func login(_ sender: Any) {
        container!.authorize(
            redirectURI: "self.test.myApp://host/path",
            prompt: "login"
        ) { result in
            print(result)
        }
    }

    @IBAction func loginWithoutSession(_ sender: Any) {
        container!.authorize(
            redirectURI: "self.test.myApp://host/path",
            prompt: "login",
            preferSFSafariViewController: true
        ) { result in
            print(result)
        }
    }

    @IBAction func loginAnonymously(_ sender: Any) {
        container!.authenticateAnonymously { result in
            print(result)
        }
    }

    @IBAction func promoteAnonymousUser(_ sender: Any) {
        container!.promoteAnonymousUser(
            redirectURI: "self.test.myApp://host/path"
        ) { result in
            print(result)
        }
    }

    @IBAction func logout(_ sender: Any) {
        container!.logout { result in
            print(result)
        }
    }
}
