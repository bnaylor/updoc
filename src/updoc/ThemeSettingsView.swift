import SwiftUI
import SwiftData

struct ThemeSettingsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTheme: AppTheme = .modern
    
    var body: some View {
        NavigationSplitView {
            List(AppTheme.allCases, selection: $selectedTheme) { theme in
                Text(theme.rawValue)
                    .tag(theme)
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
                            .font(Font(themeManager.font(for: selectedTheme)))
                        
                        Text("This is a preview of the \(selectedTheme.rawValue) theme. It shows how text and headers will look in the editor.")
                            .font(Font(themeManager.font(for: selectedTheme)))
                        
                        Text("Code block preview")
                            .font(.system(.caption, design: .monospaced))
                            .padding(4)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(themeManager.backgroundColor(for: selectedTheme)))
                    .foregroundColor(Color(themeManager.textColor(for: selectedTheme)))
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
                        themeManager.currentTheme = selectedTheme
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle(selectedTheme.rawValue)
        }
        .frame(minWidth: 600, minHeight: 400)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onAppear {
            selectedTheme = themeManager.currentTheme
        }
    }
}
