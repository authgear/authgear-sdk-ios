import Foundation

public protocol EmailClientInfo {
    var name: String { get }
    var openURL: String { get }
}

public enum EmailClient: EmailClientInfo {
    case gmail
    case mail
    
    public var name: String {
        switch self {
        case .gmail:
            return "Gmail"
        case .mail:
            return "Mail"
        }
    }
    
    public var openURL: String {
        switch self {
        case .gmail:
            return "googlegmail://"
        case .mail:
            return "message://"
        }
    }
}

public struct EmailClientItem {
    let title: String
    let openURL: String

    public init(info: EmailClientInfo) {
        self.openURL = info.openURL
        self.title = info.name
    }
    
    public init(client c: EmailClient) {
        self.init(info: c)
    }
}
