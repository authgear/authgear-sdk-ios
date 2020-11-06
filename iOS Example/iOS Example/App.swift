import Authgear
import SwiftUI

class App: ObservableObject {
    @Published var container: Authgear?
    let mainViewModel: MainViewModel

    init() {
        mainViewModel = MainViewModel()
    }

    static let redirectURI = "self.test.myApp://host/path"
}

enum AppError: Error {
    case AuthgearConfigureFieldEmpty
}
