import Authgear
import UIKit

class ViewController: UIViewController {
    private static let ClientId = "client_id"
    private static let Endpoint = "http://localhost:3000"
    let container = AuthContainer()

    override func viewDidLoad() {
        super.viewDidLoad()

        container.configure(clientId: ViewController.ClientId, endpoint: ViewController.Endpoint)
        clientId.text = ViewController.ClientId
        endpoint.text = ViewController.Endpoint
    }

    @IBOutlet weak var clientId: UILabel!
    @IBOutlet weak var endpoint: UILabel!
    
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
