import SwiftUI
import SwiftData

struct NoteDetailView: View {
    @Bindable var note: Note
    var rules: [TemplateRule]
    
    var isTitleFocused: FocusState<Bool>.Binding
    var isSyncing: Bool
    var liveSyncManager: LiveSyncManager
    var syncError: String?
    @Binding var newTagText: String
    @Binding var selectionRange: NSRange?
    @Binding var showingInspector: Bool
    
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext
    private let templateEngine = SmartTemplateEngine()
    
    var triggerSync: (Note) -> Void
    var openInBrowser: () -> Void
    var publishDraft: (Note) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Note Title", text: $note.title)
                    .font(.headline)
                    .textFieldStyle(.plain)
                    .focused(isTitleFocused)
                    .onSubmit {
                        NotificationCenter.default.post(name: .focusEditor, object: nil)
                    }
                
                if isSyncing {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.leading, 8)
                }
                
                if note.isReadOnly {
                    Label("Read-Only", systemImage: "lock.fill")
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(4)
                }
                
                Spacer()
                
                if let _ = note.googleDocId {
                    Button(action: { openInBrowser() }) {
                        Label("Open in Google Docs", systemImage: "arrow.up.right.square")
                    }
                    .help("Open linked Google Doc in browser")
                    
                    Button(action: { triggerSync(note) }) {
                        Label(
                            title: { Text(liveSyncManager.isFastPolling ? "Receiving Edits..." : "Sync Now") },
                            icon: {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundStyle(liveSyncManager.isFastPolling ? .green : .primary)
                                    .symbolEffect(.pulse, options: .repeating, isActive: liveSyncManager.isFastPolling)
                            }
                        )
                    }
                    .disabled(isSyncing || !AuthManager.shared.isAuthenticated())
                    .keyboardShortcut("s", modifiers: .command)
                    .help("Sync changes with Google Docs (Cmd+S)")
                } else {
                    Button(action: { publishDraft(note) }) {
                        Label("Publish to Google Docs", systemImage: "arrow.up.doc.fill")
                    }
                    .disabled(isSyncing || !AuthManager.shared.isAuthenticated())
                    .buttonStyle(.borderedProminent)
                }
                
                Button {
                    showingInspector.toggle()
                } label: {
                    Image(systemName: "sidebar.right")
                }
                .buttonStyle(.plain)
                .help("Toggle Inspector")
                .padding(.leading, 8)
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Tagging row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(note.categories, id: \.self) { cat in
                        HStack(spacing: 4) {
                            Text("#\(cat)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            Button {
                                note.categories.removeAll { $0 == cat }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(12)
                    }
                    
                    HStack {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        TextField("Add Tag...", text: $newTagText)
                            .textFieldStyle(.plain)
                            .font(.caption)
                            .frame(width: 80)
                            .onSubmit {
                                let cleaned = newTagText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                                if !cleaned.isEmpty && !note.categories.contains(cleaned) {
                                    note.categories.append(cleaned)
                                }
                                newTagText = ""
                            }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
            .background(Color(NSColor.windowBackgroundColor))
            
            if let error = syncError {
                Text("Sync Error: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            
            Divider()
            
            EditorView(text: $note.content, assetIds: $note.assetIds, selectionRange: $selectionRange, theme: themeManager.themeName(for: note), isReadOnly: note.isReadOnly, modelContainer: modelContext.container)
            .onAppear {
                if note.title == "New Note" && note.content.isEmpty {
                    isTitleFocused.wrappedValue = true
                } else {
                    NotificationCenter.default.post(name: .focusEditor, object: nil)
                }
            }
            .onChange(of: note.id) {
                if note.title == "New Note" && note.content.isEmpty {
                    isTitleFocused.wrappedValue = true
                } else {
                    NotificationCenter.default.post(name: .focusEditor, object: nil)
                }
            }
            .onTapGesture {
                NotificationCenter.default.post(name: .focusEditor, object: nil)
            }
        }
        .navigationTitle(note.title)
        .inspector(isPresented: $showingInspector) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Note Settings")
                    .font(.headline)
                    .padding(.bottom, 8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Theme")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: Binding(
                        get: { note.themeName ?? "Default" },
                        set: { note.themeName = $0 == "Default" ? nil : $0 }
                    )) {
                        Text("Default").tag("Default")
                        ForEach(themeManager.allThemeNames, id: \.self) { themeName in
                            Text(themeName).tag(themeName)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Button("Apply Rules") {
                    let input = TemplateInput(
                        title: note.title,
                        attendees: [],
                        date: note.createdAt,
                        location: nil,
                        description: nil
                    )
                    let resolved = templateEngine.resolveTemplate(for: input, rules: rules)
                    
                    if let themeName = resolved.themeName {
                        note.themeName = themeName
                    }
                    
                    if note.content.isEmpty || note.content == "# \(note.title)\n\nDate: \(note.createdAt.formatted())\n\n## Notes\n- " {
                        note.content = resolved.content
                    }
                }
                .buttonStyle(.bordered)
                .help("Apply template rules based on current title")
                
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .inspectorColumnWidth(min: 250, ideal: 280, max: 400)
        }
        .onAppear {
            let manager = liveSyncManager
            if note.googleDocId != nil {
                manager.start(for: note)
            }
        }
    }
}
