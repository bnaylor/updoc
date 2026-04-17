import SwiftUI
import SwiftData

struct ThemeSettingsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedThemeName: String = AppTheme.modern.rawValue
    @State private var themeToEdit: CustomTheme? = nil
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedThemeName) {
                Section(header: Text("Presets")) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.rawValue)
                            .tag(theme.rawValue)
                    }
                }
                Section(header: Text("Custom")) {
                    ForEach(themeManager.customThemes, id: \.name) { theme in
                        Text(theme.name)
                            .tag(theme.name)
                    }
                }
            }
            .navigationTitle("Themes")
        } detail: {
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
                        
                        Text("This is a preview of the \(selectedThemeName) theme. It shows how text and headers will look in the editor.")
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
                    Text("Settings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
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
            .navigationTitle(selectedThemeName)
        }
        .frame(minWidth: 600, minHeight: 400)
        .sheet(item: $themeToEdit) { theme in
            NavigationStack {
                ThemeEditorView(theme: theme)
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onAppear {
            selectedThemeName = themeManager.currentThemeName
        }
    }
}
