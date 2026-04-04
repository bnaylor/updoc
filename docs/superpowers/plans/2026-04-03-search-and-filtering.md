# Search & Filtering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a dedicated Global Search overlay (Cmd+Shift+F) with content snippets and inline hashtag support.

**Architecture:** A standalone `GlobalSearchOverlayView` driven by a `SearchEngine` (for full-text matches and snippets) and a `TagManager` (for extracting and indexing `#tags` from Markdown content).

**Tech Stack:** SwiftUI, SwiftData, Regex.

---

### Task 1: SearchEngine & Snippet Generation

**Files:**
- Create: `src/updoc/SearchEngine.swift`
- Test: `tests/updocTests/SearchEngineTests.swift`

- [ ] **Step 1: Define SearchResult and SearchEngine**

```swift
import Foundation

public struct SearchResult: Identifiable, Sendable {
    public let id = UUID()
    public let note: Note
    public let snippets: [SearchSnippet]
}

public struct SearchSnippet: Identifiable, Sendable {
    public let id = UUID()
    public let text: String
    public let range: NSRange
}

public struct SearchEngine {
    public func search(query: String, in notes: [Note]) -> [SearchResult] {
        // Implementation
    }
}
```

- [ ] **Step 2: Implement snippet extraction logic**
- [ ] **Step 3: Write tests for snippet context (+/- 40 chars)**
- [ ] **Step 4: Commit**

```bash
git add src/updoc/SearchEngine.swift tests/updocTests/SearchEngineTests.swift
git commit -m "feat: implement SearchEngine with snippet generation"
```

---

### Task 2: TagManager & Hashtag Extraction

**Files:**
- Create: `src/updoc/TagManager.swift`
- Test: `tests/updocTests/TagManagerTests.swift`

- [ ] **Step 1: Implement TagManager with Regex parsing**

```swift
import Foundation

public struct TagManager {
    public func extractTags(from content: String) -> Set<String> {
        let regex = try! NSRegularExpression(pattern: "(^|\\s)#([a-zA-Z0-9_\\-\\/]+)")
        // ...
    }
}
```

- [ ] **Step 2: Implement aggregate tag indexing for all notes**
- [ ] **Step 3: Commit**

```bash
git add src/updoc/TagManager.swift tests/updocTests/TagManagerTests.swift
git commit -m "feat: implement TagManager for hashtag extraction"
```

---

### Task 3: GlobalSearchOverlayView UI

**Files:**
- Create: `src/updoc/GlobalSearchOverlayView.swift`

- [ ] **Step 1: Build the modal UI with snippets and groupings**
- [ ] **Step 2: Implement hashtag suggestion popover when typing `#`**
- [ ] **Step 3: Implement keyboard navigation (arrows and Enter)**
- [ ] **Step 4: Commit**

```bash
git add src/updoc/GlobalSearchOverlayView.swift
git commit -m "feat: create GlobalSearchOverlayView UI"
```

---

### Task 4: Integration & Editor Sync

**Files:**
- Modify: `src/updoc/ContentView.swift`
- Modify: `src/updoc/EditorView.swift`

- [ ] **Step 1: Register Cmd+Shift+F shortcut in ContentView**
- [ ] **Step 2: Update EditorView to support jumping to specific text matches**
- [ ] **Step 3: Commit**

```bash
git add src/updoc/ContentView.swift src/updoc/EditorView.swift
git commit -m "feat: integrate Global Search overlay and Editor syncing"
```
