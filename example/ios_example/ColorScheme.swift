import enum Authgear.ColorScheme
import SwiftUI

extension SwiftUI.ColorScheme {
    var authgear: Authgear.ColorScheme? {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        default:
            return nil
        }
    }
}
