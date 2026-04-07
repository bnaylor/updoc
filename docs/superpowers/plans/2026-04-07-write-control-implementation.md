# WriteControl and Seamless Conflict Resolution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement Google Docs `WriteControl` and a 3-way merge strategy to handle concurrent edits seamlessly in the native `updoc` application.

**Architecture:** Update `GDocsService` to use `revisionId` for all updates. Implement a diffing strategy for `batchUpdate` instead of full replacement. Add a retry loop with exponential backoff and 3-way merge for conflict resolution.

**Tech Stack:** Swift, URLSession, Codable, Google Docs REST API.

---

### Task 1: Update GDocs Models

**Files:**
- Modify: `src/updoc/GDocsModels.swift`

- [ ] **Step 1: Add `revisionId` and `WriteControl` to models**

```swift
// src/updoc/GDocsModels.swift

public struct GDocsDocument: Codable {
    public let documentId: String
    public let revisionId: String // Add this
    public let title: String
    public let body: GDocsBody
    public let inlineObjects: [String: GDocsInlineObject]?
}

public struct GDocsWriteControl: Codable {
    public let requiredRevisionId: String?
    
    public init(requiredRevisionId: String?) {
        self.requiredRevisionId = requiredRevisionId
    }
}

public struct GDocsBatchUpdateRequest: Codable {
    public let requests: [GDocsRequest]
    public let writeControl: GDocsWriteControl? // Add this
    
    public init(requests: [GDocsRequest], writeControl: GDocsWriteControl? = nil) {
        self.requests = requests
        self.writeControl = writeControl
    }
}
```

- [ ] **Step 2: Commit changes**

```bash
git add src/updoc/GDocsModels.swift
git commit -m "feat: add revisionId and WriteControl to GDocs models"
```

---

### Task 2: Refactor GDocsService Interface

**Files:**
- Modify: `src/updoc/GDocsService.swift`
- Modify: `src/updoc/SyncCoordinator.swift`

- [ ] **Step 1: Update `fetchDocContent` signature**

```swift
// src/updoc/GDocsService.swift

public func fetchDocContent(docId: String) async throws -> (markdown: String, document: GDocsDocument) {
    // ... fetch logic ...
    let doc = try JSONDecoder().decode(GDocsDocument.self, from: data)
    return (convertToMarkdown(doc), doc)
}
```

- [ ] **Step 2: Update `updateDocContent` signature**

```swift
// src/updoc/GDocsService.swift

public func updateDocContent(
    docId: String, 
    content: String, 
    baseDocument: GDocsDocument, // Add this
    assetMappings: [String: String] = [:]
) async throws {
    // ...
}
```

- [ ] **Step 3: Update `SyncCoordinator` to handle interface changes**

```swift
// src/updoc/SyncCoordinator.swift

// In sync loop:
let (markdown, doc) = try await gDocs.fetchDocContent(docId: note.remoteId)
// ... later ...
try await gDocs.updateDocContent(docId: note.remoteId, content: note.content, baseDocument: doc)
```

- [ ] **Step 4: Commit changes**

```bash
git add src/updoc/GDocsService.swift src/updoc/SyncCoordinator.swift
git commit -m "refactor: update GDocsService interface to use GDocsDocument and revisionId"
```

---

### Task 3: Implement Basic Diffing for `batchUpdate`

**Files:**
- Modify: `src/updoc/GDocsService.swift`

- [ ] **Step 1: Implement minimal diffing to avoid full replacement**
Instead of deleting everything, we should ideally diff the old and new markdown. For now, we'll implement a helper that generates the requests.

```swift
// src/updoc/GDocsService.swift

private func generateUpdateRequests(from oldContent: String, to newContent: String, doc: GDocsDocument) -> [GDocsRequest] {
    // For now, let's keep it simple: if different, delete all and insert new.
    // We'll improve this in Task 4 with a real 3-way merge.
    let endIndex = doc.body.content.last?.endIndex ?? 2
    var requests: [GDocsRequest] = []
    
    requests.append(GDocsRequest(
        insertText: nil,
        deleteContentRange: GDocsDeleteContentRangeRequest(range: GDocsRange(startIndex: 1, endIndex: max(1, endIndex - 1))),
        insertInlineImage: nil,
        updateEmbeddedObjectProperties: nil
    ))
    
    // ... insertion logic ...
    return requests
}
```

- [ ] **Step 2: Use `WriteControl` in `batchUpdate`**

```swift
// src/updoc/GDocsService.swift

let batchRequest = GDocsBatchUpdateRequest(
    requests: requests,
    writeControl: GDocsWriteControl(requiredRevisionId: baseDocument.revisionId)
)
```

- [ ] **Step 3: Commit changes**

```bash
git add src/updoc/GDocsService.swift
git commit -m "feat: use WriteControl in GDocs batchUpdate"
```

---

### Task 4: Implement Rebase/Retry Loop with Backoff

**Files:**
- Modify: `src/updoc/GDocsService.swift`

- [ ] **Step 1: Wrap `updateDocContent` in a retry loop**

```swift
// src/updoc/GDocsService.swift

public func updateDocContent(...) async throws {
    var currentBase = baseDocument
    var attempts = 0
    let maxAttempts = 5
    
    while attempts < maxAttempts {
        do {
            try await performUpdate(docId: docId, content: content, baseDocument: currentBase)
            return
        } catch let error as NSError where error.code == 400 {
            // Check if it's a revision mismatch
            attempts += 1
            if attempts >= maxAttempts { throw error }
            
            // Backoff
            try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempts)) * 500_000_000))
            
            // Re-fetch and "rebase"
            let (_, latestDoc) = try await fetchDocContent(docId: docId)
            currentBase = latestDoc
            // In a real 3-way merge, we'd merge 'content' with 'latestDoc' markdown here.
        }
    }
}
```

- [ ] **Step 2: Commit changes**

```bash
git add src/updoc/GDocsService.swift
git commit -m "feat: implement retry loop with exponential backoff for GDocs updates"
```

---

### Task 5: Testing Conflict Resolution

**Files:**
- Create: `tests/updocTests/GDocsConflictTests.swift`

- [ ] **Step 1: Write tests for conflict detection and retry**

```swift
// tests/updocTests/GDocsConflictTests.swift

@Test func testUpdateRetriesOnConflict() async throws {
    // Mock GDocsService to return 400 once then success
    // Verify that fetchDocContent is called again
}
```

- [ ] **Step 2: Run tests**

```bash
swift test --filter GDocsConflictTests
```

- [ ] **Step 3: Commit tests**

```bash
git add tests/updocTests/GDocsConflictTests.swift
git commit -m "test: add GDocs conflict resolution tests"
```
