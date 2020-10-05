import Authgear
import UIKit

class ViewController: UIViewController {
    let container = Authgear(clientId: "client_id", endpoint: "http://localhost:3000")

    override func viewDidLoad() {
        super.viewDidLoad()

        container.configure()
    }

    @IBAction func login(_ sender: Any) {
        container.authorize(
            redirectURI: "self.test.myApp://host/path",
            prompt: "login"
        ) { result in
            print(result)
        }
    }

    @IBAction func loginAnonymously(_ sender: Any) {
        container.authenticateAnonymously { result in
            print(result)
        }
    }

    @IBAction func promoteAnonymousUser(_ sender: Any) {
        container.promoteAnonymousUser(
            redirectURI: "self.test.myApp://host/path"
        ) { result in
            print(result)
        }
    }

    @IBAction func logout(_ sender: Any) {
        container.logout { result in
            print(result)
        }
    }
}
