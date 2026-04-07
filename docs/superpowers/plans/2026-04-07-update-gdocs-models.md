# Update GDocs Models Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `revisionId` to `GDocsDocument` and implement `GDocsWriteControl` for `GDocsBatchUpdateRequest` to support optimistic concurrency in Google Docs API calls.

**Architecture:** Update existing Swift models in `GDocsModels.swift` to include new fields and types required by the Google Docs API.

**Tech Stack:** Swift, Foundation.

---

### Task 1: Update GDocsDocument and add GDocsWriteControl

**Files:**
- Modify: `src/updoc/GDocsModels.swift`

- [ ] **Step 1: Add `revisionId` to `GDocsDocument`**

```swift
public struct GDocsDocument: Codable {
    public let documentId: String
    public let revisionId: String? // Added this line
    public let title: String
    public let body: GDocsBody
    public let inlineObjects: [String: GDocsInlineObject]?
}
```

- [ ] **Step 2: Add `GDocsWriteControl` struct**

```swift
public struct GDocsWriteControl: Codable {
    public let requiredRevisionId: String?
    
    public init(requiredRevisionId: String?) {
        self.requiredRevisionId = requiredRevisionId
    }
}
```

- [ ] **Step 3: Update `GDocsBatchUpdateRequest`**

```swift
public struct GDocsBatchUpdateRequest: Codable {
    public let requests: [GDocsRequest]
    public let writeControl: GDocsWriteControl? // Added this line

    public init(requests: [GDocsRequest], writeControl: GDocsWriteControl? = nil) { // Added initializer
        self.requests = requests
        self.writeControl = writeControl
    }
}
```

### Task 2: Verification

- [ ] **Step 1: Run compilation check**

Run: `swift build`
Expected: PASS

- [ ] **Step 2: Clean up temporary test file**

Run: `rm tests/updocTests/GDocsModelsCompilationTest.swift`

### Task 3: Commit Changes

- [ ] **Step 1: Commit the changes**

```bash
git add src/updoc/GDocsModels.swift
git commit -m "feat: add revisionId and WriteControl to GDocs models"
```
