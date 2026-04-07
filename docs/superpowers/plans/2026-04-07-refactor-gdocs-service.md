# Refactor GDocsService Interface Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor `GDocsService` to return and accept `GDocsDocument` to avoid redundant API calls and enable better revision management.

**Architecture:** 
- `fetchDocContent` now returns both the converted markdown and the raw `GDocsDocument`.
- `updateDocContent` accepts the `baseDocument` to use its `endIndex` and potentially other metadata, avoiding an extra `GET` request.
- `SyncCoordinator` is updated to orchestrate these changes.

**Tech Stack:** Swift, Foundation, SwiftData, Google Docs API.

---

### Task 1: Update GDocsService.swift

**Files:**
- Modify: `src/updoc/GDocsService.swift`

- [ ] **Step 1: Update `fetchDocContent` signature and implementation**

```swift
    public func fetchDocContent(docId: String) async throws -> (markdown: String, document: GDocsDocument) {
        let token = try await AuthManager.shared.getAccessToken()
        let url = URL(string: "https://docs.googleapis.com/v1/documents/\(docId)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "GDocsService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch doc: \(errorBody)"])
        }
        
        let doc = try JSONDecoder().decode(GDocsDocument.self, from: data)
        return (markdown: convertToMarkdown(doc), document: doc)
    }
```

- [ ] **Step 2: Update `updateDocContent` signature and implementation**

```swift
    public func updateDocContent(docId: String, content: String, baseDocument: GDocsDocument, assetMappings: [String: String] = [:]) async throws {
        let token = try await AuthManager.shared.getAccessToken()
        
        // Use provided baseDocument instead of fetching it
        let doc = baseDocument
        let endIndex = doc.body.content.last?.endIndex ?? 2
        
        // 2. Parse content into segments
        let segments = parseSegments(content: content, assetMappings: assetMappings)
        
        // ... (rest of implementation remains the same)
```

### Task 2: Update SyncCoordinator.swift

**Files:**
- Modify: `src/updoc/SyncCoordinator.swift`

- [ ] **Step 1: Update `sync` method to handle new `fetchDocContent` return type and pass `baseDocument`**

```swift
            if remoteRev != lastRevision {
                // Pull and merge
                let (remoteContent, _) = try await gDocs.fetchDocContent(docId: docId)
                
                // ONLY throw if content is actually different
                if localContent != remoteContent {
                    throw SyncError.conflict(local: localContent, remote: remoteContent, remoteRevision: remoteRev)
                } else {
                    // Content is identical, just update revision
                    note.lastSyncedRevision = remoteRev
                    try context.save()
                }
            } else {
                // Fetch document once to get current state (e.g. endIndex)
                let (_, baseDoc) = try await gDocs.fetchDocContent(docId: docId)
                
                // Push local changes
                let assetIds = extractAssetIds(from: localContent)
                var mappings: [String: String] = [:]
                for id in assetIds {
                    if let driveUrl = ImageLibraryManager.shared.getDriveUrl(for: id, in: context) {
                        mappings[id] = driveUrl
                    }
                }
                try await gDocs.updateDocContent(docId: docId, content: localContent, baseDocument: baseDoc, assetMappings: mappings)
            }
```

### Task 3: Verification

- [ ] **Step 1: Compile the project**

Run: `swift build`
Expected: Success

- [ ] **Step 2: Run existing tests**

Run: `swift test`
Expected: Success (assuming tests cover these services or don't break due to signature changes)

- [ ] **Step 3: Commit changes**

```bash
git add src/updoc/GDocsService.swift src/updoc/SyncCoordinator.swift
git commit -m "refactor: update GDocsService interface to use GDocsDocument and revisionId"
```
