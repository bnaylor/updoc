import SwiftUI

struct ConflictResolutionView: View {
    let local: String
    let remote: String
    let onResolve: (String) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Conflict Detected")
                .font(.title)
                .padding()
            
            Text("This note has been modified both locally and on Google Docs since the last sync. Please choose which version to keep.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Local Version (Your Changes)").font(.headline)
                    ScrollView {
                        Text(local)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    
                    Button(action: { onResolve(local) }) {
                        Text("Use Local Version")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                
                VStack(alignment: .leading) {
                    Text("Google Docs Version").font(.headline)
                    ScrollView {
                        Text(remote)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    
                    Button(action: { onResolve(remote) }) {
                        Text("Use Remote Version")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding()
            
            HStack {
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()
        }
        .padding()
        .frame(minWidth: 800, minHeight: 600)
    }
}

#Preview {
    ConflictResolutionView(
        local: "Line 1: Local change\nLine 2: Shared context",
        remote: "Line 1: Remote change\nLine 2: Shared context",
        onResolve: { _ in },
        onCancel: { }
    )
}
