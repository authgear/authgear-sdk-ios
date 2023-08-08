import Foundation

public struct App2AppOptions {
    /**
     * If true, new sessions will be prepared for participating in app2app authentication
    */
    public let isEnabled: Bool
    
    public init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }
}
