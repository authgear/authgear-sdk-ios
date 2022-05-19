import Authgear
import SwiftUI

struct AuthgearConfigurationDescription: View {
    var body: some View {
        Text("Enter Client ID and Endpoint, " +
            "and then click Configure to initialize the SDK")
            .lineLimit(5)
    }
}

struct AuthgearConfigurationInput<Input: View>: View {
    let label: String
    let input: Input

    var body: some View {
        HStack(spacing: 15) {
            Text(label)
                .minimumScaleFactor(0.8)
                .frame(width: 150, height: nil, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            input
        }
    }
}

struct AuthgearConfigurationTextField: View {
    var placeHolder: String
    @Binding var text: String
    var body: some View {
        TextField(placeHolder, text: $text)
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .alignmentGuide(.trailing) { dimension in
                dimension[.trailing]
            }
    }
}

struct ActionButton: View {
    var text: String
    var body: some View {
        Text(text)
    }
}

enum TokenStorageClassName: String, CaseIterable, Identifiable {
    case TransientTokenStorage
    case PersistentTokenStorage

    var id: String { self.rawValue }
}

struct AuthgearConfigurationForm: View {
    @EnvironmentObject private var app: App

    @State private var clientID: String = UserDefaults.standard.string(forKey: "authgear.demo.clientID") ?? ""
    @State private var endpoint: String = UserDefaults.standard.string(forKey: "authgear.demo.endpoint") ?? ""
    @State private var tokenStorage: String = UserDefaults.standard.string(forKey: "authgear.demo.tokenStorage") ?? TokenStorageClassName.PersistentTokenStorage.rawValue
    @State private var shareSessionWithSystemBrowser: Bool = UserDefaults.standard.bool(forKey: "authgear.demo.shareSessionWithSystemBrowser")
    @State private var authenticationPage: String = ""

    var body: some View {
        VStack {
            AuthgearConfigurationInput(
                label: "ClientID",
                input: AuthgearConfigurationTextField(
                    placeHolder: "Enter Client ID",
                    text: $clientID
                )
            )
            AuthgearConfigurationInput(
                label: "Endpoint",
                input: AuthgearConfigurationTextField(
                    placeHolder: "Enter Endpoint",
                    text: $endpoint
                )
            )
            Picker("Authentication Page", selection: $authenticationPage) {
                Text("Unset").tag("")
                Text("Login").tag(AuthenticationPage.login.rawValue)
                Text("Signup").tag(AuthenticationPage.signup.rawValue)
            }.pickerStyle(.segmented)
            Picker("Token Storage", selection: $tokenStorage) {
                Text(TokenStorageClassName.TransientTokenStorage.rawValue).tag(TokenStorageClassName.TransientTokenStorage.rawValue)
                Text(TokenStorageClassName.PersistentTokenStorage.rawValue).tag(TokenStorageClassName.PersistentTokenStorage.rawValue)
            }.pickerStyle(.segmented)
            AuthgearConfigurationInput(
                label: "Share Session With System Browser",
                input: Toggle(isOn: $shareSessionWithSystemBrowser) { EmptyView() }
            )
            Button(action: {
                self.app.configure(
                    clientId: self.clientID,
                    endpoint: self.endpoint,
                    authenticationPage: AuthenticationPage(rawValue: self.authenticationPage),
                    tokenStorage: self.tokenStorage,
                    shareSessionWithSystemBrowser: self.shareSessionWithSystemBrowser
                )
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

    private var configured: Bool {
        app.container != nil
    }

    private var loggedIn: Bool {
        app.sessionState == SessionState.authenticated
    }

    private var isAnonymous: Bool {
        app.user?.isAnonymous == true
    }

    private var biometricEnabled: Bool {
        app.biometricEnabled
    }

    var body: some View {
        VStack(spacing: 30) {
            // We have to start using Group here because
            // Each block can only have 0 to 10 items.
            // When there are more than 10 items, the compiler will start complaining too many arguments.
            // The suggested way to work around this limitation is to use Group.

            Group {
                Button(action: {
                    self.app.login()
                }) {
                    ActionButton(text: "Authenticate")
                }.disabled(!configured || loggedIn)

                Button(action: {
                    self.app.loginAnonymously()
                }) {
                    ActionButton(text: "Authenticate Anonymously")
                }.disabled(!configured || loggedIn)

                Button(action: {
                    self.app.promoteAnonymousUser()
                }) {
                    ActionButton(text: "Promote Anonymous User")
                }.disabled(!(configured && loggedIn && isAnonymous))

                Button(action: {
                    self.app.loginBiometric()
                }) {
                    ActionButton(text: "Authenticate Biometric")
                }.disabled(!configured || loggedIn || !biometricEnabled)
            }

            Group {
                Button(action: {
                    self.app.reauthenticateWebOnly()
                }) {
                    ActionButton(text: "Reauthenticate (web-only)")
                }.disabled(!configured || !loggedIn || isAnonymous)

                Button(action: {
                    self.app.reauthenticate()
                }) {
                    ActionButton(text: "Reauthenticate (biometric or web)")
                }.disabled(!configured || !loggedIn || isAnonymous)
            }

            Group {
                Button(action: {
                    self.app.enableBiometric()
                }) {
                    ActionButton(text: "Enable Biometric")
                }.disabled(!configured || !loggedIn || isAnonymous || biometricEnabled)

                Button(action: {
                    self.app.disableBiometric()
                }) {
                    ActionButton(text: "Disable Biometric")
                }.disabled(!biometricEnabled)
            }

            Group {
                Button(action: {
                    self.app.fetchUserInfo()
                }) {
                    ActionButton(text: "Get UserInfo")
                }.disabled(!configured || !loggedIn)

                Button(action: {
                    self.app.openSetting()
                }) {
                    ActionButton(text: "Open Setting")
                }.disabled(!configured || !loggedIn || isAnonymous)

                Button(action: {
                    self.app.showAuthTime()
                }) {
                    ActionButton(text: "Show auth_time")
                }.disabled(!configured || !loggedIn)

                Button(action: {
                    self.app.logout()
                }) {
                    ActionButton(text: "Logout")
                }.disabled(!configured || !loggedIn)
            }
        }
    }
}

// TODO: find a better fix
// chaining alert in same VStack does not work on some device
struct ErrorAlertView: View {
    @EnvironmentObject private var app: App

    private var hasError: Binding<Bool> { Binding(
        get: { self.app.authgearActionErrorMessage != nil },
        set: { if !$0 { self.app.authgearActionErrorMessage = nil } }
    ) }

    var body: some View {
        VStack {
            EmptyView()
        }
        .alert(isPresented: hasError, content: {
            Alert(
                title: Text("Error"),
                message: Text(self.app.authgearActionErrorMessage ?? "")
            )
        })
    }
}

struct SuccessAlertView: View {
    @EnvironmentObject private var app: App

    private var shouldShowSuccessDialog: Binding<Bool> { Binding(
        get: { self.app.successAlertMessage != nil },
        set: { if !$0 { self.app.successAlertMessage = nil } }
    ) }

    var body: some View {
        VStack {
            EmptyView()
        }
        .alert(isPresented: shouldShowSuccessDialog, content: {
            Alert(
                title: Text("Success"),
                message: Text(self.app.successAlertMessage ?? "")
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
                AuthgearConfigurationForm().environmentObject(app)
                AuthgearActionDescription()
                ActionButtonList()
                    .environmentObject(app)
                    .environmentObject(app)
                ErrorAlertView()
                    .environmentObject(app)
                SuccessAlertView()
                    .environmentObject(app)
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
