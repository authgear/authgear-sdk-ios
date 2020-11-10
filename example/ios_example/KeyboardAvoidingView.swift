// Source: https://github.com/V8tr/KeyboardAvoidanceSwiftUI

import Combine
import SwiftUI

extension Notification {
    // for getting keyboard height from keyboardWillShowNotification
    var keyboardHeight: CGFloat {
        (userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
    }
}

extension Publishers {
    static var keyboardHeight: AnyPublisher<CGFloat, Never> {
        let willShow = NotificationCenter.default.publisher(for: UIApplication.keyboardWillShowNotification)
            .map { $0.keyboardHeight }

        let willHide = NotificationCenter.default.publisher(for: UIApplication.keyboardWillHideNotification)
            .map { _ in CGFloat(0) }

        return MergeMany(willShow, willHide)
            .eraseToAnyPublisher()
    }
}

struct KeyboardAvoider: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardHeight)
            .onReceive(Publishers.keyboardHeight) {
                if #available(iOS 14.0, *) {
                    // views avoid keyboard by default for iOS 14.0 or above
                    self.keyboardHeight = 0
                } else {
                    self.keyboardHeight = $0
                }
            }
    }
}

extension View {
    func keyboardAvoider() -> some View {
        ModifiedContent(content: self, modifier: KeyboardAvoider())
    }
}
