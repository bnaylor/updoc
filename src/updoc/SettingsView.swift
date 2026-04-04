import SwiftUI

struct SettingsView: View {
    @AppStorage("googleClientID") private var clientID = ""
    @AppStorage("googleClientSecret") private var clientSecret = ""
    @AppStorage("googleRedirectURI") private var redirectURI = ""
    
    var body: some View {
        Form {
            Section("Google API Credentials") {
                TextField("Client ID", text: $clientID)
                TextField("Client Secret", text: $clientSecret)
                TextField("Redirect URI", text: $redirectURI)
            }
        }
        .padding(20)
        .frame(width: 450)
    }
}
