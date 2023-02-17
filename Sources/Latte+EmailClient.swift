import Foundation
import UIKit

public extension Latte {
    struct EmailClient {
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

    func makeChooseEmailClientAlertController(
        title: String,
        message: String,
        cancelLabel: String,
        items: [EmailClient]
    ) -> UIAlertController {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .actionSheet
        )
        let openableItems = items.filter { item in
            guard let url = URL(string: item.openURL) else {
                return false
            }
            return UIApplication.shared.canOpenURL(url)
        }
        for item in openableItems {
            alert.addAction(UIAlertAction(
                title: item.name,
                style: .default,
                handler: { _ in
                    guard let url = URL(string: item.openURL) else {
                        return
                    }
                    UIApplication.shared.open(url)
                }
            ))
        }
        alert.addAction(UIAlertAction(
            title: cancelLabel,
            style: .cancel,
            handler: { _ in
            }
        ))
        return alert
    }
}
