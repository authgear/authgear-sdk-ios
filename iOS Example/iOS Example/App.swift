import Authgear
import SwiftUI

class App: ObservableObject {
    @Published var container: Authgear?
    let appState: AppState
    let mainViewModel: MainViewModel

    init() {
        appState = AppState()
        mainViewModel = MainViewModel(appState: appState)
    }

    static let redirectURI = "com.authgear.example://host/path"
}
