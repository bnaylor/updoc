# updoc Core App & Local Editor Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a functional macOS application shell with a basic SwiftUI sidebar and a TextKit 2-based editor window.

**Architecture:** A native Swift app using SwiftUI for high-level UI and a custom `NSTextView` wrapper for the editor. This follows the "Native First" approach to ensure zero lag.

**Tech Stack:** Swift 6.0, SwiftUI, TextKit 2, SwiftData (for local persistence).

---

### Task 1: Initialize macOS App & Sidebar

**Files:**
- Create: `src/updoc/updocApp.swift`
- Create: `src/updoc/ContentView.swift`
- Create: `src/updoc/SidebarView.swift`

- [ ] **Step 1: Write the App entry point**

```swift
import SwiftUI
import SwiftData

@main
struct updocApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

- [ ] **Step 2: Create the Sidebar and Content View**

```swift
// ContentView.swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            EditorView()
        }
    }
}

// SidebarView.swift
import SwiftUI

struct SidebarView: View {
    var body: some View {
        List {
            Section("MEETINGS") {
                Text("Today (Apr 2)")
                Text("- 1:1 w/ Duckie")
            }
            Section("TOPICS") {
                Text("updoc Project")
                Text("Research")
            }
        }
        .listStyle(.sidebar)
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add src/updoc/*.swift
git commit -m "feat: initialize macOS app shell with sidebar"
```

---

### Task 2: Implement TextKit 2 Editor Wrapper

**Files:**
- Create: `src/updoc/EditorView.swift`

- [ ] **Step 1: Write the NSTextView wrapper for SwiftUI**

```swift
import SwiftUI
import AppKit

struct EditorView: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        textView.delegate = context.coordinator
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isContinuousSpellCheckingEnabled = true
        
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        if textView.string != text {
            textView.string = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditorView

        init(_ parent: EditorView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            self.parent.text = textView.string
        }
    }
}
```

- [ ] **Step 2: Update ContentView to include state for the editor**

```swift
// ContentView.swift (Update)
struct ContentView: View {
    @State private var editorText = "# Welcome to updoc\n\nStart typing your meeting notes here."
    
    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            EditorView(text: $editorText)
        }
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add src/updoc/EditorView.swift src/updoc/ContentView.swift
git commit -m "feat: add TextKit 2 based editor wrapper"
```

---

### Task 3: Basic Local Persistence with SwiftData

**Files:**
- Modify: `src/updoc/updocApp.swift`
- Create: `src/updoc/Note.swift`
- Modify: `src/updoc/ContentView.swift`

- [ ] **Step 1: Define the Note model**

```swift
import Foundation
import SwiftData

@Model
class Note {
    var title: String
    var content: String
    var createdAt: Date
    
    init(title: String, content: String, createdAt: Date = .now) {
        self.title = title
        self.content = content
        self.createdAt = createdAt
    }
}
```

- [ ] **Step 2: Configure SwiftData in the App**

```swift
// updocApp.swift (Update)
@main
struct updocApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Note.self)
    }
}
```

- [ ] **Step 3: Connect Sidebar to SwiftData**

```swift
// SidebarView.swift (Update)
struct SidebarView: View {
    @Query private var notes: [Note]
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        List {
            Section("NOTES") {
                ForEach(notes) { note in
                    Text(note.title)
                }
            }
        }
        .toolbar {
            Button(action: addNote) {
                Label("Add Note", systemImage: "plus")
            }
        }
    }
    
    private func addNote() {
        let newNote = Note(title: "New Note", content: "")
        modelContext.insert(newNote)
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add src/updoc/Note.swift src/updoc/updocApp.swift src/updoc/SidebarView.swift
git commit -m "feat: add basic SwiftData persistence for notes"
```
