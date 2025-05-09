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

struct TextLabelValue: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 15) {
            Text(label)
                .minimumScaleFactor(0.8)
                .frame(width: 150, height: nil, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Text(value)
                .frame(width: nil, height: nil, alignment: .trailing)
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
    @State private var app2AppEndpoint: String = UserDefaults.standard.string(forKey: "authgear.demo.app2appendpoint") ?? ""
    @Binding var app2appState: String
    @State private var tokenStorage: String = UserDefaults.standard.string(forKey: "authgear.demo.tokenStorage") ?? TokenStorageClassName.PersistentTokenStorage.rawValue
    @State private var isSSOEnabled: Bool = UserDefaults.standard.bool(forKey: "authgear.demo.isSSOEnabled")
    @State private var preAuthenticatedURLEnabled: Bool = UserDefaults.standard.bool(forKey: "authgear.demo.preAuthenticatedURLEnabled")
    @State private var preAuthenticatedURLClientID: String = UserDefaults.standard.string(forKey: "authgear.demo.preAuthenticatedURLClientID") ?? ""
    @State private var preAuthenticatedURLRedirectURI: String = UserDefaults.standard.string(forKey: "authgear.demo.preAuthenticatedURLRedirectURI") ?? ""
    @State private var useWKWebView: Bool = UserDefaults.standard.bool(forKey: "authgear.demo.useWKWebView")
    @State private var authenticationPage: String = ""
    @State private var explicitColorSchemeString: String = ""
    @State private var authenticationFlowGroup: String = ""
    @State private var oauthProviderAlias: String = ""

    private let appName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String

    var body: some View {
        VStack {
            Group {
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
                AuthgearConfigurationInput(
                    label: "App2App Endpoint",
                    input: AuthgearConfigurationTextField(
                        placeHolder: "Enter App2App Endpoint",
                        text: $app2AppEndpoint
                    )
                )
                if (!app2AppEndpoint.isEmpty) {
                    AuthgearConfigurationInput(
                        label: "App2App State",
                        input: AuthgearConfigurationTextField(
                            placeHolder: "Enter App2App State",
                            text: $app2appState
                        )
                    )
                }
                AuthgearConfigurationInput(
                    label: "Pre-select OAuth Provider",
                    input: AuthgearConfigurationTextField(
                        placeHolder: "Enter OAuth Provider Alias",
                        text: $oauthProviderAlias
                    )
                )
                AuthgearConfigurationInput(
                    label: "Authentication flow group",
                    input: AuthgearConfigurationTextField(
                        placeHolder: "Override authentication flow group",
                        text: $authenticationFlowGroup
                    )
                )
            }
            Picker("Authentication Page", selection: $authenticationPage) {
                Text("Unset").tag("")
                Text("Login").tag(AuthenticationPage.login.rawValue)
                Text("Signup").tag(AuthenticationPage.signup.rawValue)
            }.pickerStyle(.segmented)
            Picker("Color Scheme", selection: $explicitColorSchemeString) {
                Text("Use system").tag("")
                Text("Light").tag(ColorScheme.light.rawValue)
                Text("Dark").tag(ColorScheme.dark.rawValue)
            }.pickerStyle(.segmented)
            Picker("Token Storage", selection: $tokenStorage) {
                Text(TokenStorageClassName.TransientTokenStorage.rawValue).tag(TokenStorageClassName.TransientTokenStorage.rawValue)
                Text(TokenStorageClassName.PersistentTokenStorage.rawValue).tag(TokenStorageClassName.PersistentTokenStorage.rawValue)
            }.pickerStyle(.segmented)
            AuthgearConfigurationInput(
                label: "Is SSO Enabled",
                input: Toggle(isOn: $isSSOEnabled) { EmptyView() }
            )
            AuthgearConfigurationInput(
                label: "Use WKWebView",
                input: Toggle(isOn: $useWKWebView) { EmptyView() }
            )
            AuthgearConfigurationInput(
                label: "Is Pre-Authenticated URL Enabled",
                input: Toggle(isOn: $preAuthenticatedURLEnabled) { EmptyView() }
            )
            AuthgearConfigurationInput(
                label: "Pre-Authenticated URL Client ID",
                input: AuthgearConfigurationTextField(
                    placeHolder: "Enter Client ID",
                    text: $preAuthenticatedURLClientID
                )
            )
            AuthgearConfigurationInput(
                label: "Pre-Authenticated URL Redirect URI",
                input: AuthgearConfigurationTextField(
                    placeHolder: "Enter Redirect URI",
                    text: $preAuthenticatedURLRedirectURI
                )
            )
            TextLabelValue(
                label: "SessionState",
                value: app.sessionState.rawValue
            )
            Button(action: {
                self.app.configure(
                    clientId: self.clientID,
                    endpoint: self.endpoint,
                    app2AppEndpoint: self.app2AppEndpoint,
                    authenticationPage: AuthenticationPage(rawValue: self.authenticationPage),
                    authenticationFlowGroup: self.authenticationFlowGroup == "" ? nil : self.authenticationFlowGroup,
                    colorScheme: ColorScheme(rawValue: self.explicitColorSchemeString),
                    tokenStorage: self.tokenStorage,
                    isSSOEnabled: self.isSSOEnabled,
                    preAuthenticatedURLEnabled: self.preAuthenticatedURLEnabled,
                    preAuthenticatedURLClientID: self.preAuthenticatedURLClientID,
                    preAuthenticatedURLRedirectURI: self.preAuthenticatedURLRedirectURI,
                    useWKWebView: self.useWKWebView,
                    oauthProviderAlias: self.oauthProviderAlias == "" ? nil : self.oauthProviderAlias
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

    private var app2appConfigured: Bool {
        !app.app2appEndpoint.isEmpty
    }

    private var preAuthenticatedURLEnabled: Bool {
        app.preAuthenticatedURLEnabled
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
                    self.app.authenticateApp2App()
                }) {
                    ActionButton(text: "Authenticate App2App")
                }.disabled(!configured || loggedIn || !app2appConfigured)

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

                Button(action: {
                    self.app.preAuthenticatedURL()
                }) {
                    ActionButton(text: "Pre-Authenticated URL")
                }.disabled(!configured || !loggedIn || !preAuthenticatedURLEnabled)
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
                    self.app.changePassword()
                }) {
                    ActionButton(text: "Change Password")
                }.disabled(!configured || !loggedIn || isAnonymous)

                Button(action: {
                    self.app.deleteAccount()
                }) {
                    ActionButton(text: "Delete Account")
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

struct App2AppAlertView: View {
    @EnvironmentObject private var app: App

    private var shouldShow: Binding<Bool> { Binding(
        get: { self.app.app2AppConfirmation != nil },
        set: { _ in }
    ) }

    var body: some View {
        VStack {
            EmptyView()
        }
        .alert(isPresented: shouldShow, content: {
            Alert(
                title: Text(self.app.app2AppConfirmation?.message ?? ""),
                primaryButton: .default(Text("OK")) {
                    self.app.app2AppConfirmation?.onConfirm()
                },
                secondaryButton: .cancel(Text("Cancel")) {
                    self.app.app2AppConfirmation?.onReject()
                }
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
                AuthgearConfigurationForm(app2appState: $app.app2AppState)
                    .environmentObject(app)
                AuthgearActionDescription()
                ActionButtonList()
                    .environmentObject(app)
                    .environmentObject(app)
                ErrorAlertView()
                    .environmentObject(app)
                SuccessAlertView()
                    .environmentObject(app)
                App2AppAlertView()
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
