import SwiftUI

struct UserInfo {
    var userID: String
    var isAnonymous: Bool
    var isVerified: Bool
}

class AppState: ObservableObject {
    @Published var user: UserInfo?
}
