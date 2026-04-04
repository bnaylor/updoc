# Task Sidebar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a collapsible right sidebar providing a global view of all `ActionItems` across all notes, sorted by due date and status.

**Architecture:** Update `ContentView` to use a 3-column `NavigationSplitView`. Create `TaskSidebarView` using `@Query` for data and a shared binding for navigation.

**Tech Stack:** SwiftUI, SwiftData.

---

### Task 1: 3-Column Navigation & Visibility State

**Files:**
- Modify: `src/updoc/ContentView.swift`

- [ ] **Step 1: Add sidebar visibility state**

```swift
@State private var columnVisibility = NavigationSplitViewVisibility.all
```

- [ ] **Step 2: Update NavigationSplitView to 3 columns**

```swift
NavigationSplitView(columnVisibility: $columnVisibility) {
    SidebarView(selectedNote: $selectedNote)
} content: {
    if let note = selectedNote {
        // Editor VStack here
    } else {
        Text("Select a note")
    }
} detail: {
    // New TaskSidebarView placeholder
}
```

- [ ] **Step 3: Add toolbar toggle for Task Sidebar**
- [ ] **Step 4: Commit**

```bash
git add src/updoc/ContentView.swift
git commit -m "feat: implement 3-column layout for task sidebar"
```

---

### Task 2: TaskSidebarView & Data Query

**Files:**
- Create: `src/updoc/TaskSidebarView.swift`

- [ ] **Step 1: Implement basic TaskSidebarView with @Query**

```swift
import SwiftUI
import SwiftData

struct TaskSidebarView: View {
    @Query(sort: \ActionItem.dueDate, order: .forward) private var tasks: [ActionItem]
    @Binding var selectedNote: Note?
    
    var body: some View {
        List {
            // Task list rendering
        }
    }
}
```

- [ ] **Step 2: Build the task item UI (Checkbox, Title, Due Date, Note Link)**
- [ ] **Step 3: Commit**

```bash
git add src/updoc/TaskSidebarView.swift
git commit -m "feat: create TaskSidebarView with action item query"
```

---

### Task 3: Grouping, Sorting & Navigation

**Files:**
- Modify: `src/updoc/TaskSidebarView.swift`

- [ ] **Step 1: Implement grouping logic (Overdue, Today, Upcoming)**
- [ ] **Step 2: Implement "Jump to Note" logic when clicking the note link**
- [ ] **Step 3: Add status filtering (Hide Done toggle)**
- [ ] **Step 4: Commit**

```bash
git add src/updoc/TaskSidebarView.swift
git commit -m "feat: add grouping and navigation to task sidebar"
```

---

### Task 4: Live Editor Sync

**Files:**
- Modify: `src/updoc/TaskSidebarView.swift`
- Modify: `src/updoc/Note.swift` (if needed for helper)

- [ ] **Step 1: Ensure checking a task in sidebar updates the linked Note's Markdown content**
- [ ] **Step 2: Verify bidirectional updates (sidebar <-> editor)**
- [ ] **Step 3: Commit**

```bash
git add src/updoc/TaskSidebarView.swift
git commit -m "feat: implement live sync between task sidebar and editor content"
```
