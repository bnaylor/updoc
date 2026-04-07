import SwiftUI

struct SettingsView: View {
    @State private var clientID = ""
    @State private var clientSecret = ""
    @State private var redirectURI = ""
    
    var onDone: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 20) {
            Form {
                Section("Google Account") {
                    if AuthManager.shared.isAuthenticated() {
                        HStack {
                            Text("Signed in as:")
                            Text(AuthManager.shared.userEmail ?? "Unknown")
                                .fontWeight(.bold)
                            Spacer()
                            Button("Sign Out") {
                                AuthManager.shared.signOut()
                            }
                        }
                    } else {
                        Button("Sign In with Google") {
                            login()
                        }
                    }
                }
                
                Section("Google API Credentials") {
                    TextField("Client ID", text: $clientID)
                    TextField("Client Secret", text: $clientSecret)
                    TextField("Redirect URI", text: $redirectURI)
                }
            }
            
            VStack(spacing: 10) {
                if let onDone = onDone {
                    Button("Save & Continue") {
                        save()
                        onDone()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Button("Save") {
                        save()
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Button("Reset & Clear All", role: .destructive) {
                    clearAll()
                }
                .buttonStyle(.link)
            }
        }
        .padding(20)
        .frame(width: 450)
        .onAppear {
            load()
        }
    }
    
    private func load() {
        clientID = Config.clientID
        clientSecret = Config.clientSecret
        redirectURI = Config.redirectURI
    }
    
    private func clearAll() {
        clientID = ""
        clientSecret = ""
        redirectURI = ""
        
        try? KeychainHelper.delete(service: "com.example.updoc.config", account: "googleClientID")
        try? KeychainHelper.delete(service: "com.example.updoc.config", account: "googleClientSecret")
        try? KeychainHelper.delete(service: "com.example.updoc.config", account: "googleRedirectURI")
        
        UserDefaults.standard.removeObject(forKey: "googleClientID")
        UserDefaults.standard.removeObject(forKey: "googleClientSecret")
        UserDefaults.standard.removeObject(forKey: "googleRedirectURI")
        
        AuthManager.shared.signOut()
    }
    
    private func save() {
        do {
            try Config.saveCredentials(clientID: clientID, clientSecret: clientSecret, redirectURI: redirectURI)
        } catch {
            print("Failed to save credentials to Keychain: \(error)")
        }
    }
    
    private func login() {
        guard let window = NSApp.keyWindow else { return }
        Task {
            do {
                try await AuthManager.shared.authorize(in: window)
            } catch {
                print("Settings login failed: \(error)")
            }
        }
    }
}
