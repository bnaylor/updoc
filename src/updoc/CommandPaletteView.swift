import SwiftUI

public struct CommandPaletteView: View {
    @Binding var isPresented: Bool
    @State private var query = ""
    @State private var results: [Command] = []
    @State private var selectedIndex = 0
    @FocusState private var isFocused: Bool
    
    let commands: [Command]
    let notes: [Note]
    let onNoteSelect: @Sendable (Note) -> Void
    private let engine = CommandEngine()
    
    public init(isPresented: Binding<Bool>, commands: [Command], notes: [Note], onNoteSelect: @escaping @Sendable (Note) -> Void) {
        self._isPresented = isPresented
        self.commands = commands
        self.notes = notes
        self.onNoteSelect = onNoteSelect
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Type a command or search notes...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title2)
                    .focused($isFocused)
                    .onAppear {
                        isFocused = true
                    }
                    .onChange(of: query) { _, newValue in
                        results = engine.search(query: newValue, commands: commands, notes: notes, onNoteSelect: onNoteSelect)
                        selectedIndex = 0
                    }
                    .onSubmit {
                        executeSelection()
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
                ScrollViewReader { proxy in
                    List(Array(results.enumerated()), id: \.element.id) { index, command in
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
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(selectedIndex == index ? Color.accentColor.opacity(0.1) : Color.clear)
                        .cornerRadius(6)
                        .id(index)
                    }
                    .listStyle(.plain)
                    .frame(maxHeight: 400)
                    .onChange(of: selectedIndex) { _, newIndex in
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
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
        .onExitCommand {
            isPresented = false
        }
        .onKeyPress(.downArrow) {
            if !results.isEmpty {
                selectedIndex = (selectedIndex + 1) % results.count
            }
            return .handled
        }
        .onKeyPress(.upArrow) {
            if !results.isEmpty {
                selectedIndex = (selectedIndex - 1 + results.count) % results.count
            }
            return .handled
        }
    }
    
    private func executeSelection() {
        guard !results.isEmpty, selectedIndex < results.count else { return }
        results[selectedIndex].action()
        isPresented = false
    }
}
