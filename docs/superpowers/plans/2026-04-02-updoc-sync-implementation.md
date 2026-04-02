# Google Docs Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement bidirectional sync between local updoc notes and Google Docs, including OAuth2 authentication and conflict resolution.

**Architecture:** A dedicated `SyncCoordinator` actor manages the sync lifecycle, using `AuthManager` for credentials and specialized service classes for Google Docs and Drive APIs.

**Tech Stack:** Swift 6.0, Google REST APIs, macOS Keychain, SwiftData.

---

### Task 1: OAuth2 & Keychain Manager

**Files:**
- Create: `src/updoc/AuthManager.swift`
- Test: `tests/updocTests/AuthManagerTests.swift`

- [ ] **Step 1: Define the AuthManager actor**

```swift
import Foundation
import AppKit

public actor AuthManager {
    public static let shared = AuthManager()
    private let keychainService = "com.updoc.auth"
    
    public func authorize() async throws -> String {
        // TODO: Implement system browser redirect flow
        return "mock-token"
    }
    
    public func getAccessToken() async throws -> String? {
        // TODO: Retrieve from Keychain
        return nil
    }
    
    public func saveTokens(accessToken: String, refreshToken: String?) {
        // TODO: Save to Keychain
    }
}
```

- [ ] **Step 2: Create a test for token storage**

```swift
// tests/updocTests/AuthManagerTests.swift
import Testing
@testable import updoc

struct AuthManagerTests {
    @Test func canSaveAndRetrieveTokens() async throws {
        let manager = AuthManager.shared
        await manager.saveTokens(accessToken: "test-access", refreshToken: "test-refresh")
        let token = try await manager.getAccessToken()
        #expect(token == "test-access")
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add src/updoc/AuthManager.swift tests/updocTests/AuthManagerTests.swift
git commit -m "feat: add AuthManager for OAuth2 and Keychain storage"
```

---

### Task 2: GDocs & GDrive Service Classes

**Files:**
- Create: `src/updoc/GDocsService.swift`
- Create: `src/updoc/GDriveService.swift`
- Test: `tests/updocTests/ServiceTests.swift`

- [ ] **Step 1: Implement GDriveService for file monitoring**

```swift
// GDriveService.swift
import Foundation

public struct GDriveService {
    public func getFileRevision(fileId: String) async throws -> String {
        // TODO: Call Drive API to get head revision
        return "rev-1"
    }
}
```

- [ ] **Step 2: Implement GDocsService for content sync**

```swift
// GDocsService.swift
import Foundation

public struct GDocsService {
    public func fetchDocContent(docId: String) async throws -> String {
        // TODO: Call Docs API to get content JSON and convert to Markdown
        return "# Remote Content"
    }
    
    public func updateDocContent(docId: String, content: String) async throws {
        // TODO: Convert Markdown to Docs JSON and push batch update
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add src/updoc/GDocsService.swift src/updoc/GDriveService.swift
git commit -m "feat: add GDocs and GDrive service classes"
```

---

### Task 3: SyncCoordinator Actor & 3-Way Merge

**Files:**
- Create: `src/updoc/SyncCoordinator.swift`
- Modify: `src/updoc/Note.swift`
- Test: `tests/updocTests/SyncTests.swift`

- [ ] **Step 1: Update Note model with sync metadata**

```swift
// Note.swift
@Model
class Note {
    var title: String
    var content: String
    var createdAt: Date
    var googleDocId: String?
    var lastSyncedRevision: String?
    // ...
}
```

- [ ] **Step 2: Implement SyncCoordinator logic**

```swift
// SyncCoordinator.swift
import Foundation
import SwiftData

public actor SyncCoordinator {
    private let gDocs = GDocsService()
    private let gDrive = GDriveService()
    
    public func sync(note: Note) async throws {
        guard let docId = note.googleDocId else { return }
        
        let remoteRev = try await gDrive.getFileRevision(fileId: docId)
        if remoteRev != note.lastSyncedRevision {
            // Pull and merge
            let remoteContent = try await gDocs.fetchDocContent(docId: docId)
            note.content = merge(local: note.content, remote: remoteContent)
            note.lastSyncedRevision = remoteRev
        } else {
            // Push local changes
            try await gDocs.updateDocContent(docId: docId, content: note.content)
        }
    }
    
    private func merge(local: String, remote: String) -> String {
        // TODO: Implement 3-way merge or simple resolution
        return local // Placeholder
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add src/updoc/SyncCoordinator.swift src/updoc/Note.swift
git commit -m "feat: implement SyncCoordinator and update Note model"
```

---

### Task 4: UI Integration (Open in Browser & Sync UI)

**Files:**
- Modify: `src/updoc/ContentView.swift`
- Modify: `src/updoc/EditorView.swift`

- [ ] **Step 1: Add "Open in Browser" button to EditorView header**

```swift
// EditorView.swift (Update UI)
HStack {
    Text(note.title)
    Spacer()
    if let docId = note.googleDocId {
        Button("Open in Google Docs") {
            let url = URL(string: "https://docs.google.com/document/d/\(docId)")!
            NSWorkspace.shared.open(url)
        }
    }
}
```

- [ ] **Step 2: Trigger sync on save or periodially**

- [ ] **Step 3: Commit**

```bash
git add src/updoc/ContentView.swift src/updoc/EditorView.swift
git commit -m "feat: integrate sync UI and Open in Browser function"
```
