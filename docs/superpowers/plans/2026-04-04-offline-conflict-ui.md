# Offline Conflict UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace silent conflict merging with a side-by-side resolution UI.

**Architecture:** 
Update `SyncCoordinator` to throw a specific `SyncError.conflict` containing both local and remote state. `ContentView` will catch this error, store the conflict state, and present a `ConflictResolutionView` sheet. The resolution view will provide clear actions to resolve the conflict and update the model.

**Tech Stack:** Swift, SwiftUI, SwiftData.

---

### Task 1: Update SyncCoordinator for Explicit Conflicts

**Files:**
- Modify: `src/updoc/SyncCoordinator.swift`

- [ ] **Step 1: Define SyncError and SyncConflict**

Add these to `SyncCoordinator.swift` (or a new file if preferred):
```swift
public enum SyncError: Error, LocalizedError {
    case conflict(local: String, remote: String, remoteRevision: String)
    case notAuthenticated
    
    public var errorDescription: String? {
        switch self {
        case .conflict: return "Conflict detected"
        case .notAuthenticated: return "Authentication required"
        }
    }
}
```

- [ ] **Step 2: Update sync() to throw conflict**

Modify the version check logic:
```swift
// Replace automatic merge with:
if remoteRev != lastRevision {
    let remoteContent = try await gDocs.fetchDocContent(docId: docId)
    // ONLY throw if content is actually different
    if localContent != remoteContent {
        throw SyncError.conflict(local: localContent, remote: remoteContent, remoteRevision: remoteRev)
    } else {
        // Content is identical, just update revision
        note.lastSyncedRevision = remoteRev
        try context.save()
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add src/updoc/SyncCoordinator.swift
git commit -m "feat: update SyncCoordinator to throw explicit conflict errors"
```

### Task 2: Create ConflictResolutionView

**Files:**
- Create: `src/updoc/ConflictResolutionView.swift`

- [ ] **Step 1: Implement side-by-side UI**

Create a SwiftUI view that shows two scrollable text areas with "Use Mine" and "Use Remote" buttons.

```swift
struct ConflictResolutionView: View {
    let local: String
    let remote: String
    let onResolve: (String) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack {
            Text("Conflict Detected").font(.title)
            HStack {
                VStack {
                    Text("Local Version").font(.headline)
                    ScrollView { Text(local).frame(maxWidth: .infinity, alignment: .leading) }
                    Button("Use Local") { onResolve(local) }
                }
                Divider()
                VStack {
                    Text("Remote Version").font(.headline)
                    ScrollView { Text(remote).frame(maxWidth: .infinity, alignment: .leading) }
                    Button("Use Remote") { onResolve(remote) }
                }
            }
            Button("Cancel") { onCancel() }.padding()
        }.padding().frame(minWidth: 600, minHeight: 400)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add src/updoc/ConflictResolutionView.swift
git commit -m "feat: add ConflictResolutionView for side-by-side comparison"
```

### Task 3: Integrate Conflict Handling in ContentView

**Files:**
- Modify: `src/updoc/ContentView.swift`

- [ ] **Step 1: Add conflict state**

```swift
struct ConflictInfo: Identifiable {
    let id = UUID()
    let noteId: PersistentIdentifier
    let local: String
    let remote: String
    let remoteRevision: String
}

@State private var activeConflict: ConflictInfo?
```

- [ ] **Step 2: Update triggerSync to catch conflict**

```swift
catch let error as SyncError {
    if case let .conflict(local, remote, rev) = error {
        activeConflict = ConflictInfo(noteId: noteId, local: local, remote: remote, remoteRevision: rev)
    }
}
```

- [ ] **Step 3: Add .sheet for resolution**

```swift
.sheet(item: $activeConflict) { info in
    ConflictResolutionView(local: info.local, remote: info.remote) { resolvedContent in
        resolveConflict(info, with: resolvedContent)
    } onCancel: {
        activeConflict = nil
    }
}
```

- [ ] **Step 4: Implement resolveConflict**

```swift
private func resolveConflict(_ info: ConflictInfo, with content: String) {
    guard let note = modelContext.model(for: info.noteId) as? Note else { return }
    note.content = content
    note.lastSyncedRevision = info.remoteRevision
    try? modelContext.save()
    activeConflict = nil
    // Optional: triggerSync(for: note) to push the resolution immediately
}
```

- [ ] **Step 5: Commit**

```bash
git add src/updoc/ContentView.swift
git commit -m "feat: integrate conflict resolution UI into ContentView"
```

### Task 4: Verification

- [ ] **Step 1: Verify the feature**
  - Modify a note locally.
  - Modify the same note in Google Docs (manually in browser).
  - Sync in updoc.
  - Verify the resolution sheet appears.
  - Verify "Use Local" preserves your changes.
  - Verify "Use Remote" overwrites with Google Docs version.

- [ ] **Step 2: Commit**

```bash
git commit --allow-empty -m "test: verify offline conflict resolution flow"
```
