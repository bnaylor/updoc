# updoc App Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement curated typography themes, a central Command Palette (Cmd+K), and comprehensive Menu Bar mirroring.

**Architecture:** A `ThemeManager` observable object manages UI state. A `CommandEngine` indexes notes and actions for the `CommandPaletteView` overlay. Native macOS menu commands are linked to app-wide actions.

**Tech Stack:** Swift 6.0, SwiftUI, TextKit 2, UserDefaults.

---

### Task 1: ThemeManager & Curated Typography

**Files:**
- Create: `src/updoc/ThemeManager.swift`
- Modify: `src/updoc/EditorView.swift`
- Modify: `src/updoc/ContentView.swift`

- [ ] **Step 1: Define ThemeManager and App Themes**

```swift
import SwiftUI

public enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case modern = "Modern"
    case serif = "Serif"
    case mono = "Mono"
    public var id: String { rawValue }
}

@Observable
public class ThemeManager {
    public static let shared = ThemeManager()
    public var currentTheme: AppTheme = .modern
    
    public var fontName: String {
        switch currentTheme {
        case .modern: return "SF Pro"
        case .serif: return "New York"
        case .mono: return "SF Mono"
        }
    }
}
```

- [ ] **Step 2: Inject ThemeManager into App and Views**

- [ ] **Step 3: Update EditorView to use theme-specific fonts**

- [ ] **Step 4: Commit**

```bash
git add src/updoc/ThemeManager.swift src/updoc/EditorView.swift
git commit -m "feat: add ThemeManager and curated typography themes"
```

---

### Task 2: CommandEngine & Palette Infrastructure

**Files:**
- Create: `src/updoc/CommandEngine.swift`
- Create: `src/updoc/CommandPaletteView.swift`
- Test: `tests/updocTests/CommandEngineTests.swift`

- [ ] **Step 1: Define Command and CommandEngine**

```swift
import Foundation

public struct Command: Identifiable {
    public let id = UUID()
    public let title: String
    public let shortcut: String?
    public let action: () -> Void
}

public struct CommandEngine {
    public func search(query: String, notes: [Note]) -> [Command] {
        // TODO: Implement fuzzy search for commands and notes
        return []
    }
}
```

- [ ] **Step 2: Implement CommandPaletteView Overlay**

- [ ] **Step 3: Commit**

```bash
git add src/updoc/CommandEngine.swift src/updoc/CommandPaletteView.swift
git commit -m "feat: add CommandEngine and palette infrastructure"
```

---

### Task 3: Menu Bar Integration & Cmd+K Trigger

**Files:**
- Modify: `src/updoc/updocApp.swift`
- Modify: `src/updoc/ContentView.swift`

- [ ] **Step 1: Define Native Menu Commands**

```swift
// updocApp.swift (Update)
.commands {
    CommandGroup(replacing: .newItem) {
        Button("New Note") { /* trigger */ }.keyboardShortcut("n")
    }
    CommandMenu("Theme") {
        ForEach(AppTheme.allCases) { theme in
            Button(theme.rawValue) { ThemeManager.shared.currentTheme = theme }
        }
    }
}
```

- [ ] **Step 2: Implement Cmd+K global trigger**

- [ ] **Step 3: Commit**

```bash
git add src/updoc/updocApp.swift src/updoc/ContentView.swift
git commit -m "feat: integrate Menu Bar commands and Cmd+K trigger"
```
