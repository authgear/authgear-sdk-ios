import Foundation

public struct EmailClient {
    let name: String
    let openURL: String

    public static let mail = EmailClient(
        name: "Mail",
        openURL: "message://"
    )

    public static let gmail = EmailClient(
        name: "Gmail",
        openURL: "googlegmail://"
    )
}
