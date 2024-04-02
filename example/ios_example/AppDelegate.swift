import Authgear
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var appContainer = App()

    func configureAuthgear(
        clientId: String,
        endpoint: String,
        tokenStorage: String,
        isSSOEnabled: Bool,
        isApp2AppEnabled: Bool,
        useWKWebView: Bool
    ) {
        let app2AppOptions = App2AppOptions(
            isEnabled: isApp2AppEnabled,
            authorizationEndpoint: App.app2appAuthorizeEndpoint
        )

        let tokenStorageInstance: TokenStorage
        switch tokenStorage {
        case TokenStorageClassName.TransientTokenStorage.rawValue:
            tokenStorageInstance = TransientTokenStorage()
        default:
            tokenStorageInstance = PersistentTokenStorage()
        }

        let uiImplementation: UIImplementation
        if useWKWebView {
            uiImplementation = WKWebViewUIImplementation(isInspectable: true)
        } else {
            uiImplementation = ASWebAuthenticationSessionUIImplementation()
        }

        appContainer.container = Authgear(
            clientId: clientId,
            endpoint: endpoint,
            tokenStorage: tokenStorageInstance,
            uiImplementation: uiImplementation,
            isSSOEnabled: isSSOEnabled,
            app2AppOptions: app2AppOptions
        )
        appContainer.container?.configure() { _ in
            self.appContainer.postConfig()
        }
        appContainer.container?.delegate = self

        // configure WeChat SDK
        WXApi.registerApp(App.wechatAppID, universalLink: App.wechatUniversalLink)
        WXApi.startLog(by: .detail) { log in
            print(#line, "wechat sdk wxapi: " + log)
        }
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        let app2appRequest = appContainer.container?.parseApp2AppAuthenticationRequest(
            userActivity: userActivity)
        if let app2appRequest = app2appRequest {
            appContainer.pendingApp2AppRequest = app2appRequest
            return true
        }
        if let container = appContainer.container,
           container.handleApp2AppAuthenticationResult(
               userActivity: userActivity) == true {
            return true
        }
        return false
    }
}

extension AppDelegate: AuthgearDelegate {
    func sendWechatAuthRequest(_ state: String) {
        print(#line, "sendWechatAuthRequest: \(state)")
        let req = SendAuthReq()
        req.openID = App.wechatAppID
        req.scope = "snsapi_userinfo"
        req.state = state
        WXApi.send(req)
    }

    func authgearSessionStateDidChange(_ container: Authgear, reason: SessionStateChangeReason) {
        appContainer.sessionState = container.sessionState
    }
}

extension AppDelegate: WXApiDelegate {
    func onReq(_ req: BaseReq) {}

    func onResp(_ resp: BaseResp) {
        // Receive code from WeChat, send callback to authgear
        // by calling `authgear.wechatAuthCallback`
        if resp.isKind(of: SendAuthResp.self) {
            if resp.errCode == 0 {
                let _resp = resp as! SendAuthResp
                if let code = _resp.code, let state = _resp.state {
                    appContainer.container?.wechatAuthCallback(code: code, state: state) { result in
                        switch result {
                        case .success():
                            print(#line, "wechat callback received")
                        case let .failure(error):
                            print(#line, error)
                        }
                    }
                }
            } else {
                print(#line, "failed in wechat login: \(resp.errStr)")
            }
        }
    }
}
