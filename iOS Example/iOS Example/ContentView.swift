import Authgear
import SwiftUI

struct AuthgearConfigurationDescription: View {
    var body: some View {
        Text("Enter Client ID and Endpoint, " +
            "and then click Configure to initialize the SDK")
            .lineLimit(5)
    }
}

struct AuthgearConfigurationInput: View {
    var label: String
    var placeHolder: String
    @Binding var text: String
    var body: some View {
        HStack(spacing: 15) {
            Text(label)
                .minimumScaleFactor(0.8)
                .frame(width: 70, height: nil, alignment: .leading)
            TextField(placeHolder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .alignmentGuide(.trailing) { dimension in
                    dimension[.trailing]
                }
        }
    }
}

struct ActionButton: View {
    var text: String
    var body: some View {
        Text(text)
    }
}

struct AuthgearConfigurationForm: View {
    @EnvironmentObject private var app: App

    @State private var clientID: String = ""
    @State private var endpoint: String = ""
    @State private var hasError: Bool = false
    @State private var errorMessage: String = ""
    var body: some View {
        VStack {
            AuthgearConfigurationInput(
                label: "ClientID",
                placeHolder: "Enter Client ID",
                text: $clientID
            )
            AuthgearConfigurationInput(
                label: "Endpoint",
                placeHolder: "Enter Endpoint",
                text: $endpoint
            )
            Button(action: {
                do {
                    try self.app.mainViewModel.configure(clientId: self.clientID, endpoint: self.endpoint)
                    self.hasError = false
                } catch AppError.AuthgearConfigureFieldEmpty {
                    self.hasError = true
                    self.errorMessage = "Please input client ID and endpoint"
                } catch {
                    self.hasError = true
                    self.errorMessage = "Failed to configure Authgear"
                }
            }) {
                ActionButton(text: "Configure")
            }
            .padding(.top, 15)
        }
        .alert(
            isPresented: $hasError,
            content: { Alert(title: Text("Error"), message: Text(errorMessage)) }
        )
    }
}

struct AuthgearActionDescription: View {
    var body: some View {
        Text("After that, click one of the following buttons " +
            "to try different feature")
            .lineLimit(5)
    }
}

struct ActionButtonList: View {
    @EnvironmentObject private var app: App

    var mainViewModel: MainViewModel {
        app.mainViewModel
    }

    var container: Authgear? {
        app.container
    }

    private var configured: Bool {
        app.container != nil
    }

    var body: some View {
        VStack(spacing: 30) {
            Button(action: {
                self.mainViewModel.login(container: self.container)
            }) {
                ActionButton(text: "Login").disabled(!configured)
            }
            Button(action: {
                self.mainViewModel.loginWithoutSession(container: self.container)
            }) {
                ActionButton(text: "Login Without Session").disabled(!configured)
            }
            Button(action: {
                self.mainViewModel.loginAnonymously(container: self.container)
            }) {
                ActionButton(text: "Login Anonymously").disabled(!configured)
            }
            Button(action: {
                self.mainViewModel.openSetting(container: self.container)
            }) {
                ActionButton(text: "Open Setting Page").disabled(!configured)
            }
            Button(action: {
                self.mainViewModel.promoteAnonymousUser(container: self.container)
            }) {
                ActionButton(text: "Promote Anonymous User").disabled(!configured)
            }
            Button(action: {
                self.mainViewModel.fetchUserInfo(container: self.container)
            }) {
                ActionButton(text: "Fetch User Info").disabled(!configured)
            }
            Button(action: {
                self.mainViewModel.logout(container: self.container)
            }) {
                ActionButton(text: "Logout").disabled(!configured)
            }
        }
    }
}

struct ContentView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                AuthgearConfigurationDescription()
                AuthgearConfigurationForm()
                AuthgearActionDescription()
                ActionButtonList()
            }.padding(20)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
