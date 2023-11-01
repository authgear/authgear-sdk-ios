import Foundation

public struct App2AppOptions {
    /**
      * If true, new sessions will be prepared for participating in app2app authentication
     */
    public let isEnabled: Bool

    /**
      * If isEnabled is true, your app will listen for app2app authentication requests sent to this universal link.
     */
    public let authorizationEndpoint: String?

    public init(isEnabled: Bool, authorizationEndpoint: String?) {
        self.isEnabled = isEnabled
        self.authorizationEndpoint = authorizationEndpoint
    }
}
