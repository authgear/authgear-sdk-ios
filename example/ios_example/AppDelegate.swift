import Authgear
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var appContainer = App()

    func configureAuthgear(clientId: String, endpoint: String, isThirdParty: Bool) {
        appContainer.container = Authgear(clientId: clientId, endpoint: endpoint, isThirdParty: isThirdParty)
        appContainer.container?.configure()
        appContainer.container?.delegate = self

        // configure WeChat SDK
        WXApi.registerApp(App.weChatAppID, universalLink: App.weChatUniversalLink)
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
}

extension AppDelegate: AuthgearDelegate {
    func sendWeChatAuthRequest(_ state: String) {
        print(#line, "sendWeChatAuthRequest: \(state)")
        let req = SendAuthReq()
        req.openID = App.weChatAppID
        req.scope = "snsapi_userinfo"
        req.state = state
        WXApi.send(req)
    }
}

extension AppDelegate: WXApiDelegate {
    func onReq(_ req: BaseReq) {}

    func onResp(_ resp: BaseResp) {
        // Receive code from WeChat, send callback to authgear
        // by calling `authgear.weChatAuthCallback`
        if resp.isKind(of: SendAuthResp.self) {
            if resp.errCode == 0 {
                let _resp = resp as! SendAuthResp
                if let code = _resp.code, let state = _resp.state {
                    appContainer.container?.weChatAuthCallback(code: code, state: state) { result in
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
