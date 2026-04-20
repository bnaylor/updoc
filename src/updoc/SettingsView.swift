// src/updoc/SettingsView.swift
import SwiftUI
import SwiftData

struct SettingsView: View {
    enum Tab {
        case credentials
        case editor
        case templates
        case themes
    }
    
    @State private var selectedTab: Tab = .credentials
    @Environment(\.modelContext) private var modelContext
    
    var onAddRule: () -> Void
    
    // Credentials State
    @State private var clientID = ""
    @State private var clientSecret = ""
    @State private var redirectURI = ""
    
    // Editor State
    @AppStorage("spellcheckEnabled") private var spellcheckEnabled = true
    @AppStorage("autocorrectEnabled") private var autocorrectEnabled = true
    
    // Themes State
    @Environment(ThemeManager.self) private var themeManager
    @State private var selectedThemeName: String = AppTheme.modern.rawValue
    @State private var themeToEdit: CustomTheme? = nil
    
    var onDone: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Toolbar
            HStack(spacing: 20) {
                ToolbarButton(title: "Credentials", icon: "key.fill", isSelected: selectedTab == .credentials) {
                    selectedTab = .credentials
                }
                ToolbarButton(title: "Editor", icon: "square.and.pencil", isSelected: selectedTab == .editor) {
                    selectedTab = .editor
                }
                ToolbarButton(title: "Templates", icon: "doc.text.magnifyingglass", isSelected: selectedTab == .templates) {
                    selectedTab = .templates
                }
                ToolbarButton(title: "Themes", icon: "paintbrush.fill", isSelected: selectedTab == .themes) {
                    selectedTab = .themes
                }
                Spacer()
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Content
            Group {
                switch selectedTab {
                case .credentials:
                    credentialsPane
                case .editor:
                    editorPane
                case .templates:
                    RuleManagerView(showNavigation: false, onAddRule: onAddRule)
                        .environment(\.modelContext, modelContext)
                case .themes:
                    themesPane
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            
            Divider()
            
            // Footer (Prefs are auto-saved)
            if let onDone = onDone {
                HStack {
                    Spacer()
                    Button("Done") {
                        onDone()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .frame(width: 700, height: 550)
        .onAppear {
            load()
            selectedThemeName = themeManager.currentThemeName
        }
        .sheet(item: $themeToEdit) { theme in
            NavigationStack {
                ThemeEditorView(theme: theme)
            }
        }
    }
    
    // MARK: - Panes
    
    private var credentialsPane: some View {
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
                TextField("Client ID", text: Binding(
                    get: { clientID },
                    set: { clientID = $0; save() }
                ))
                TextField("Client Secret", text: Binding(
                    get: { clientSecret },
                    set: { clientSecret = $0; save() }
                ))
                TextField("Redirect URI", text: Binding(
                    get: { redirectURI },
                    set: { redirectURI = $0; save() }
                ))
            }
            
            Section {
                Button("Reset & Clear All", role: .destructive) {
                    clearAll()
                }
            }
        }
    }
    
    private var editorPane: some View {
        Form {
            Section("Preferences") {
                Toggle("Enable Spellcheck", isOn: $spellcheckEnabled)
                Toggle("Enable Autocorrect", isOn: $autocorrectEnabled)
            }
        }
    }
    
    private var themesPane: some View {
        HStack(spacing: 0) {
            // Sidebar
            List(selection: $selectedThemeName) {
                Section(header: Text("Presets")) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.rawValue).tag(theme.rawValue)
                    }
                }
                Section(header: Text("Custom")) {
                    ForEach(themeManager.customThemes, id: \.name) { theme in
                        Text(theme.name).tag(theme.name)
                    }
                }
            }
            .frame(width: 150)
            
            Divider()
            
            // Detail
            VStack(spacing: 20) {
                // Preview Area
                VStack(alignment: .leading, spacing: 10) {
                    Text("Preview")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Heading 1")
                            .font(.title)
                            .fontWeight(.bold)
                            .font(Font(themeManager.font(for: selectedThemeName)))
                        
                        Text("This is a preview of the \(selectedThemeName) theme.")
                            .font(Font(themeManager.font(for: selectedThemeName)))
                        
                        HStack {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundColor(bulletColor(for: selectedThemeName))
                            Text("List item with **bold** and *italic* text")
                                .font(Font(themeManager.font(for: selectedThemeName)))
                        }
                        
                        HStack {
                            Image(systemName: "checkmark.square.fill")
                                .foregroundColor(.accentColor)
                            Text("Completed task")
                                .font(Font(themeManager.font(for: selectedThemeName)))
                        }
                        
                        (Text("Use `inline code` and ") + 
                         Text("hyperlinks").foregroundColor(linkColor(for: selectedThemeName)) + 
                         Text(" for rich text."))
                            .font(Font(themeManager.font(for: selectedThemeName)))
                        
                        Text("Code block preview")
                            .font(.system(.caption, design: .monospaced))
                            .padding(4)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(themeManager.backgroundColor(for: selectedThemeName)))
                    .foregroundColor(Color(themeManager.textColor(for: selectedThemeName)))
                    .cornerRadius(8)
                    .shadow(radius: 2)
                }
                
                Divider()
                
                // Controls
                VStack(alignment: .leading, spacing: 10) {
                    Button("Apply As Global Theme") {
                        themeManager.currentThemeName = selectedThemeName
                    }
                    .buttonStyle(.borderedProminent)
                    
                    HStack {
                        Button("Create New Theme") {
                            themeToEdit = CustomTheme(
                                name: "New Theme",
                                backgroundColor: "#FFFFFF",
                                textColor: "#000000",
                                headingColor: "#0000FF",
                                blockquoteColor: "#808080",
                                highlightColor: "#FFFF00",
                                linkColor: "#008000"
                            )
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Edit Selected Theme") {
                            themeToEdit = themeManager.getTheme(named: selectedThemeName)
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Delete Theme", role: .destructive) {
                            themeManager.deleteCustomTheme(named: selectedThemeName)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!themeManager.customThemes.contains(where: { $0.name == selectedThemeName }))
                    }
                }
                Spacer()
            }
            .padding()
        }
    }
    
    // MARK: - Helper Views
    
    private struct ToolbarButton: View {
        let title: String
        let icon: String
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                    Text(title)
                        .font(.caption)
                }
                .foregroundColor(isSelected ? .accentColor : .primary)
                .padding(8)
                .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Actions
    
    private func load() {
        clientID = Config.clientID
        clientSecret = Config.clientSecret
        redirectURI = Config.redirectURI
    }
    
    private func save() {
        Config.saveCredentials(clientID: clientID, clientSecret: clientSecret, redirectURI: redirectURI)
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
    
    private func linkColor(for themeName: String) -> Color {
        if let theme = themeManager.getTheme(named: themeName) {
            return Color(NSColor(hex: theme.linkColor) ?? .blue)
        }
        return .blue
    }
    
    private func bulletColor(for themeName: String) -> Color {
        if let theme = themeManager.getTheme(named: themeName),
           let bulletColorHex = theme.bulletColor,
           let nsColor = NSColor(hex: bulletColorHex) {
            return Color(nsColor)
        }
        if let theme = themeManager.getTheme(named: themeName),
           let nsColor = NSColor(hex: theme.textColor) {
            return Color(nsColor)
        }
        return .primary
    }
}
