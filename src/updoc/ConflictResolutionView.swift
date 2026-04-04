import SwiftUI

struct ConflictResolutionView: View {
    @Environment(ThemeManager.self) private var themeManager
    
    let local: String
    let remote: String
    let onResolve: (String) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("Conflict Detected")
                    .font(.title)
                    .accessibilityAddTraits(.isHeader)
                
                Text("This note has been modified both locally and on Google Docs since the last sync. Please choose which version to keep.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .accessibilityElement(children: .combine)
            
            Grid(horizontalSpacing: 20, verticalSpacing: 20) {
                GridRow {
                    conflictColumn(
                        title: "Local Version (Your Changes)",
                        content: local,
                        buttonTitle: "Use Local Version",
                        buttonStyle: .borderedProminent,
                        action: { onResolve(local) }
                    )
                    
                    conflictColumn(
                        title: "Google Docs Version",
                        content: remote,
                        buttonTitle: "Use Remote Version",
                        buttonStyle: .bordered,
                        action: { onResolve(remote) }
                    )
                }
            }
            .padding()
            
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape, modifiers: [])
                    .help("Discard changes and close the resolution view")
            }
            .padding()
        }
        .padding()
        .frame(minWidth: 800, minHeight: 600)
    }
    
    @ViewBuilder
    private func conflictColumn(
        title: String,
        content: String,
        buttonTitle: String,
        buttonStyle: some PrimitiveButtonStyle,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            
            ScrollView {
                Text(content)
                    .font(Font(themeManager.font))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .accessibilityLabel("\(title) content")
            
            Button(action: action) {
                Text(buttonTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(buttonStyle)
            .controlSize(.large)
            .accessibilityLabel(buttonTitle)
        }
    }
}

#Preview {
    ConflictResolutionView(
        local: "Line 1: Local change\nLine 2: Shared context",
        remote: "Line 1: Remote change\nLine 2: Shared context",
        onResolve: { _ in },
        onCancel: { }
    )
    .environment(ThemeManager.shared)
}
