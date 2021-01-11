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
    static let weChatUniversalLink = "https://authgear-demo.pandawork.com/wechat/"
    static let weChatRedirectURI = "https://authgear-demo.pandawork.com/authgear/open_wechat_app"
    static let weChatAppID = "wxa2f631873c63add1"
}
