import Authgear
import SwiftUI
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private var app: App {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        return appDelegate!.appContainer
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        let contentView = ContentView().environmentObject(app)

        // Use a UIHostingController as window root view controller.
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIHostingController(rootView: contentView)
            self.window = window
            window.makeKeyAndVisible()
        }
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        guard let userActivity = connectionOptions.userActivities.first else {
            return
        }
        let app2appRequest = appDelegate?.appContainer.container?.parseApp2AppAuthenticationRequest(
            userActivity: userActivity)
        if let app2appRequest = app2appRequest {
            appDelegate?.appContainer.pendingApp2AppRequest = app2appRequest
            return
        }
        if let container = appDelegate?.appContainer.container,
           container.handleApp2AppAuthenticationResult(
               userActivity: userActivity) == true {
            return
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        // wechat sdk handle
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        let app2appRequest = appDelegate?.appContainer.container?.parseApp2AppAuthenticationRequest(
            userActivity: userActivity)
        if let app2appRequest = app2appRequest {
            appDelegate?.appContainer.pendingApp2AppRequest = app2appRequest
            return
        }
        if let container = appDelegate?.appContainer.container,
           container.handleApp2AppAuthenticationResult(
               userActivity: userActivity) == true {
            return
        }
        WXApi.handleOpenUniversalLink(userActivity, delegate: appDelegate)

        // authgear sdk handle
        guard let c = app.container else {
            // not yet configured
            return
        }
        c.scene(scene, continue: userActivity)
    }
}
