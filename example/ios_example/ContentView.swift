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

    @State private var clientID: String = UserDefaults.standard.string(forKey: "authgear.demo.clientID") ?? ""
    @State private var endpoint: String = UserDefaults.standard.string(forKey: "authgear.demo.endpoint") ?? ""

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
                self.app.mainViewModel.configure(clientId: self.clientID, endpoint: self.endpoint)
            }) {
                ActionButton(text: "Configure")
            }
            .padding(.top, 15)
        }
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
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var mainViewModel: MainViewModel

    private var container: Authgear? {
        app.container
    }

    private var configured: Bool {
        app.container != nil
    }

    private var loggedIn: Bool {
        appState.user != nil
    }

    private var canBePromotedFromAnonymous: Bool {
        configured && loggedIn && appState.user?.isAnonymous == true
    }

    var body: some View {
        VStack(spacing: 30) {
            Button(action: {
                self.mainViewModel.login(container: self.container)
            }) {
                ActionButton(text: "Login")
            }.disabled(!configured || loggedIn)

            Button(action: {
                self.mainViewModel.loginWithoutSession(container: self.container)
            }) {
                ActionButton(text: "Login Without Session")
            }.disabled(!configured || loggedIn)

            Button(action: {
                self.mainViewModel.loginAnonymously(container: self.container)
            }) {
                ActionButton(text: "Login Anonymously")
            }.disabled(!configured || loggedIn)

            Button(action: {
                self.mainViewModel.openSetting(container: self.container)
            }) {
                ActionButton(text: "Open Setting Page")
            }.disabled(!configured)

            Button(action: {
                self.mainViewModel.promoteAnonymousUser(container: self.container)
            }) {
                ActionButton(text: "Promote Anonymous User")
            }.disabled(!canBePromotedFromAnonymous)

            Button(action: {
                self.mainViewModel.fetchUserInfo(container: self.container)
            }) {
                ActionButton(text: "Fetch User Info")
            }.disabled(!configured || !loggedIn)

            Button(action: {
                self.mainViewModel.logout(container: self.container)
            }) {
                ActionButton(text: "Logout")
            }.disabled(!configured || !loggedIn)
        }
    }
}

// TODO: find a better fix
// chaining alert in same VStack does not work on some device
struct ErrorAlertView: View {
    @EnvironmentObject private var mainViewModel: MainViewModel

    private var hasError: Binding<Bool> { Binding(
        get: { self.mainViewModel.authgearActionErrorMessage != nil },
        set: { if !$0 { self.mainViewModel.authgearActionErrorMessage = nil } }
    ) }

    var body: some View {
        VStack {
            EmptyView()
        }
        .alert(isPresented: hasError, content: {
            Alert(
                title: Text("Error"),
                message: Text(mainViewModel.authgearActionErrorMessage ?? "")
            )
        })
    }
}

struct SuccessAlertView: View {
    @EnvironmentObject private var mainViewModel: MainViewModel

    private var shouldShowSuccessDialog: Binding<Bool> { Binding(
        get: { self.mainViewModel.successAlertMessage != nil },
        set: { if !$0 { self.mainViewModel.successAlertMessage = nil } }
    ) }

    var body: some View {
        VStack {
            EmptyView()
        }
        .alert(isPresented: shouldShowSuccessDialog, content: {
            Alert(
                title: Text("Success"),
                message: Text(mainViewModel.successAlertMessage ?? "")
            )
        })
    }
}

struct ContentView: View {
    @EnvironmentObject private var app: App

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                AuthgearConfigurationDescription()
                AuthgearConfigurationForm()
                AuthgearActionDescription()
                ActionButtonList()
                    .environmentObject(app.appState)
                    .environmentObject(app.mainViewModel)
                ErrorAlertView()
                    .environmentObject(app.mainViewModel)
                SuccessAlertView()
                    .environmentObject(app.mainViewModel)
            }.padding(20)
        }
        .padding(.top) // avoid overlap with status bar
        .keyboardAvoider()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environmentObject(App())
    }
}
