# Note Deletion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a comprehensive note deletion system that handles local SwiftData deletion and optional trashing of linked Google Docs with ownership verification.

**Architecture:** A centralized `DeletionManager` will handle the UI state and deletion lifecycle. `GDriveService` will be extended to support file trashing and metadata retrieval. The UI will trigger deletion via keyboard shortcuts, context menus, and the app menu.

**Tech Stack:** SwiftUI, SwiftData, Google Drive API (v3).

---

### File Mapping
- **New:** `src/updoc/DeletionManager.swift`: Manages deletion state and coordination.
- **Modify:** `src/updoc/GDriveService.swift`: Adds `trashFile` and `getFileMetadata`.
- **Modify:** `src/updoc/NoteListView.swift`: Adds context menu for deletion.
- **Modify:** `src/updoc/ContentView.swift`: Implements the confirmation dialog and keyboard shortcut.
- **Modify:** `src/updoc/updocApp.swift`: Adds "Delete Note" to the File menu.

---

### Task 1: Extend GDriveService

**Files:**
- Modify: `src/updoc/GDriveService.swift`

- [ ] **Step 1: Add GDriveFileMetadata struct**

```swift
public struct GDriveFileMetadata: Codable {
    public let id: String
    public let ownedByMe: Bool
}
```

- [ ] **Step 2: Add getFileMetadata method**

```swift
public func getFileMetadata(fileId: String) async throws -> GDriveFileMetadata {
    let token = try await AuthManager.shared.getAccessToken()
    let url = URL(string: "https://www.googleapis.com/drive/v3/files/\(fileId)?fields=id,ownedByMe")!
    var request = URLRequest(url: url)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    
    let (data, response) = try await URLSession.shared.data(for: request)
    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
        throw NSError(domain: "GDriveService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch metadata"])
    }
    return try JSONDecoder().decode(GDriveFileMetadata.self, from: data)
}
```

- [ ] **Step 3: Add trashFile method**

```swift
public func trashFile(fileId: String) async throws {
    let token = try await AuthManager.shared.getAccessToken()
    let url = URL(string: "https://www.googleapis.com/drive/v3/files/\(fileId)")!
    var request = URLRequest(url: url)
    request.httpMethod = "PATCH"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let body = ["trashed": true]
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    
    let (_, response) = try await URLSession.shared.data(for: request)
    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
        throw NSError(domain: "GDriveService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to trash file"])
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add src/updoc/GDriveService.swift
git commit -m "feat: add trash and metadata support to GDriveService"
```

### Task 2: Implement DeletionManager

**Files:**
- Create: `src/updoc/DeletionManager.swift`

- [ ] **Step 1: Create DeletionManager class**

```swift
import SwiftUI
import SwiftData

@Observable
public class DeletionManager {
    public var showDeleteConfirmation = false
    public var pendingNote: Note?
    public var isOwnedByMe = false
    public var isDeleting = false
    
    private let gDrive = GDriveService()
    
    public init() {}
    
    public func prepareDeletion(for note: Note) {
        self.pendingNote = note
        self.isDeleting = true
        
        Task {
            if let docId = note.googleDocId {
                do {
                    let metadata = try await gDrive.getFileMetadata(fileId: docId)
                    await MainActor.run {
                        self.isOwnedByMe = metadata.ownedByMe
                        self.isDeleting = false
                        self.showDeleteConfirmation = true
                    }
                } catch {
                    await MainActor.run {
                        self.isOwnedByMe = false
                        self.isDeleting = false
                        self.showDeleteConfirmation = true
                    }
                }
            } else {
                await MainActor.run {
                    self.isOwnedByMe = false
                    self.isDeleting = false
                    self.showDeleteConfirmation = true
                }
            }
        }
    }
    
    @MainActor
    public func confirmDeletion(alsoTrashRemote: Bool, modelContext: ModelContext) async {
        guard let note = pendingNote else { return }
        
        isDeleting = true
        if alsoTrashRemote, let docId = note.googleDocId {
            try? await gDrive.trashFile(fileId: docId)
        }
        
        modelContext.delete(note)
        try? modelContext.save()
        
        self.pendingNote = nil
        self.showDeleteConfirmation = false
        self.isDeleting = false
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add src/updoc/DeletionManager.swift
git commit -m "feat: implement DeletionManager for coordinated note deletion"
```

### Task 3: Integrate UI Triggers

**Files:**
- Modify: `src/updoc/ContentView.swift`
- Modify: `src/updoc/NoteListView.swift`
- Modify: `src/updoc/updocApp.swift`

- [ ] **Step 1: Add DeletionManager to ContentView**

```swift
// In ContentView.swift
@State private var deletionManager = DeletionManager()

// Add to body's confirmationDialog
.confirmationDialog(
    "Delete Note",
    isPresented: $deletionManager.showDeleteConfirmation,
    presenting: deletionManager.pendingNote
) { note in
    if note.googleDocId != nil && deletionManager.isOwnedByMe {
        Button("Delete Note & Trash Google Doc", role: .destructive) {
            Task { await deletionManager.confirmDeletion(alsoTrashRemote: true, modelContext: modelContext) }
        }
    }
    
    Button("Delete Note Only", role: .destructive) {
        Task { await deletionManager.confirmDeletion(alsoTrashRemote: false, modelContext: modelContext) }
    }
    
    Button("Cancel", role: .cancel) {
        deletionManager.pendingNote = nil
    }
} message: { note in
    if note.googleDocId != nil {
        if deletionManager.isOwnedByMe {
            Text("This note is linked to a Google Doc you own. Do you want to move the Doc to Trash as well?")
        } else {
            Text("This note is linked to a Google Doc you don't own. The Doc will not be affected.")
        }
    } else {
        Text("Are you sure you want to delete '\(note.title)'?")
    }
}
```

- [ ] **Step 2: Add Keyboard Shortcut in ContentView**

```swift
// Add to background or a hidden button in ContentView
Button("") {
    if let note = selectedNote {
        deletionManager.prepareDeletion(for: note)
    }
}
.keyboardShortcut(.delete, modifiers: .command)
.opacity(0)
```

- [ ] **Step 3: Add Context Menu to NoteListView**

```swift
// In NoteListView.swift
// Add an environment or binding to trigger deletion if needed, 
// or use a NotificationCenter post that DeletionManager/ContentView listens to.
```

- [ ] **Step 4: Update App Menu**

```swift
// In updocApp.swift
CommandGroup(after: .newItem) {
    Button("Delete Note") {
        NotificationCenter.default.post(name: .deleteSelectedNote, object: nil)
    }
    .keyboardShortcut(.delete, modifiers: .command)
}
```

- [ ] **Step 5: Commit**

```bash
git add src/updoc/ContentView.swift src/updoc/NoteListView.swift src/updoc/updocApp.swift
git commit -m "feat: add deletion UI triggers and confirmation dialog"
```
