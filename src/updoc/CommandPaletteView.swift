import SwiftUI

public struct CommandPaletteView: View {
    @Binding var isPresented: Bool
    @State private var query = ""
    @State private var results: [Command] = []
    
    let commands: [Command]
    let notes: [Note]
    private let engine = CommandEngine()
    
    public init(isPresented: Binding<Bool>, commands: [Command], notes: [Note]) {
        self._isPresented = isPresented
        self.commands = commands
        self.notes = notes
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Type a command or search notes...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title2)
                    .onChange(of: query) { _, newValue in
                        results = engine.search(query: newValue, commands: commands, notes: notes)
                    }
                Button("Esc") {
                    isPresented = false
                }
                .keyboardShortcut(.escape, modifiers: [])
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding()
            
            Divider()
            
            if !results.isEmpty {
                List(results) { command in
                    Button {
                        command.action()
                        isPresented = false
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(command.title)
                                    .font(.headline)
                                if let subtitle = command.subtitle {
                                    Text(subtitle)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            if let shortcut = command.shortcut {
                                Text(shortcut)
                                    .font(.caption2)
                                    .padding(4)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
                .frame(maxHeight: 400)
            } else if !query.isEmpty {
                Text("No results found.")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 20)
        .frame(width: 600)
        .padding()
    }
}
