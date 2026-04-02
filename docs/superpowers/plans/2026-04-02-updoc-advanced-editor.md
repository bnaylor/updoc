# updoc Advanced Editor Features Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enhance the editor with interactive chips (@mentions, dates), fluent checklists, action item promotion, and a local image library.

**Architecture:** Leverages TextKit 2 `NSTextAttachment` for rich elements and a dedicated `AutocompleteManager` to handle triggers. Data is stored locally in `SwiftData` and synced via the `SyncCoordinator`.

**Tech Stack:** Swift 6.0, TextKit 2, SwiftUI, SwiftData.

---

### Task 1: Universal @Autocomplete & Contact Chips

**Files:**
- Create: `src/updoc/MomaService.swift`
- Create: `src/updoc/DateService.swift`
- Create: `src/updoc/AutocompleteManager.swift`
- Modify: `src/updoc/EditorView.swift`

- [ ] **Step 1: Implement MomaService & DateService**

```swift
// MomaService.swift
public struct Person: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String
    public let email: String
}

public actor MomaService {
    public static let shared = MomaService()
    public func searchPeople(query: String) async throws -> [Person] {
        // Mock search
        return [Person(id: "1", name: "Duckie", email: "duckie@google.com")]
    }
}

// DateService.swift
public struct DateService {
    public static func parse(_ query: String) -> Date? {
        if query.lowercased() == "today" { return .now }
        return nil
    }
}
```

- [ ] **Step 2: Implement AutocompleteManager**

```swift
// AutocompleteManager.swift
import Foundation

public enum AutocompleteMatch {
    case person(Person)
    case date(Date)
}

public struct AutocompleteManager {
    public func findMatches(for query: String) async throws -> [AutocompleteMatch] {
        // Search Moma + DateService
        return []
    }
}
```

- [ ] **Step 3: Integrate with EditorView (NSTextAttachment)**

- [ ] **Step 4: Commit**

```bash
git add src/updoc/MomaService.swift src/updoc/DateService.swift src/updoc/AutocompleteManager.swift
git commit -m "feat: add universal autocomplete and contact chip infrastructure"
```

---

### Task 2: Fluent Checklists & √ Shortcut

**Files:**
- Modify: `src/updoc/MarkdownEngine.swift`
- Modify: `src/updoc/EditorView.swift`

- [ ] **Step 1: Update MarkdownEngine to handle √ syntax**

```swift
// MarkdownEngine.swift (Update)
let checklistRegex = try! NSRegularExpression(pattern: "^(\\s*)(\\[[ x]\\]|√)\\s+.*$", options: [.anchorsMatchLines])
```

- [ ] **Step 2: Implement auto-conversion in EditorView**

- [ ] **Step 3: Commit**

```bash
git add src/updoc/MarkdownEngine.swift src/updoc/EditorView.swift
git commit -m "feat: add √ shortcut and enhanced checklist behavior"
```

---

### Task 4: Local Image Library & Drag-and-Drop

**Files:**
- Create: `src/updoc/ImageLibraryManager.swift`
- Modify: `src/updoc/Note.swift`
- Modify: `src/updoc/EditorView.swift`

- [ ] **Step 1: Implement ImageLibraryManager**

```swift
// ImageLibraryManager.swift
import Foundation

public actor ImageLibraryManager {
    public static let shared = ImageLibraryManager()
    
    public func saveImage(_ data: Data) async throws -> String {
        let id = UUID().uuidString
        // TODO: Save to local assets folder
        return id
    }
}
```

- [ ] **Step 2: Add image support to EditorView (Drop delegate)**

- [ ] **Step 3: Commit**

```bash
git add src/updoc/ImageLibraryManager.swift
git commit -m "feat: add local image library and drag-and-drop support"
```
