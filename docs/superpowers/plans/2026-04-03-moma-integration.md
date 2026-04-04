# Moma/Directory Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace mock `MomaService` data with real REST API calls to the internal directory for @mentions.

**Architecture:** `MomaService` (Actor) performs `URLSession` calls. `AutocompleteManager` debounces these calls and caches results. `EditorView` triggers lookups on "@".

**Tech Stack:** SwiftUI, URLSession, Codable.

---

### Task 1: Environment & Config Update

**Files:**
- Modify: `src/updoc/Config.swift`
- Modify: `.env.template`

- [ ] **Step 1: Add Moma API keys to Config.swift**

```swift
// Config.swift
public static let momaAPIURL = ProcessInfo.processInfo.environment["MOMA_API_URL"] ?? ""
public static let momaAPIKey = ProcessInfo.processInfo.environment["MOMA_API_KEY"] ?? ""
```

- [ ] **Step 2: Update .env.template**
- [ ] **Step 3: Commit**

```bash
git add src/updoc/Config.swift .env.template
git commit -m "chore: add Moma API configuration placeholders"
```

---

### Task 2: Real MomaService Implementation

**Files:**
- Modify: `src/updoc/MomaService.swift`
- Test: `tests/updocTests/MomaServiceTests.swift`

- [ ] **Step 1: Implement searchPeople using URLSession**

```swift
public func searchPeople(query: String) async throws -> [Person] {
    let url = URL(string: "\(Config.momaAPIURL)/search?q=\(query)")!
    var request = URLRequest(url: url)
    request.setValue(Config.momaAPIKey, forHTTPHeaderField: "X-API-Key")
    
    let (data, _) = try await URLSession.shared.data(for: request)
    return try JSONDecoder().decode([Person].self, from: data)
}
```

- [ ] **Step 2: Write tests verifying API call structure**
- [ ] **Step 3: Commit**

```bash
git add src/updoc/MomaService.swift tests/updocTests/MomaServiceTests.swift
git commit -m "feat: implement real MomaService REST calls"
```

---

### Task 3: Debouncing & Caching in AutocompleteManager

**Files:**
- Modify: `src/updoc/AutocompleteManager.swift`
- Test: `tests/updocTests/AutocompleteTests.swift`

- [ ] **Step 1: Add debouncing logic to AutocompleteManager**
- [ ] **Step 2: Implement simple in-memory cache for Person results**
- [ ] **Step 3: Commit**

```bash
git add src/updoc/AutocompleteManager.swift
git commit -m "feat: add debouncing and caching to AutocompleteManager"
```

---

### Task 4: UI Refinement & Error Handling

**Files:**
- Modify: `src/updoc/EditorView.swift`

- [ ] **Step 1: Handle network errors gracefully in the autocomplete menu**
- [ ] **Step 2: Add "Searching..." indicator if possible**
- [ ] **Step 3: Commit**

```bash
git add src/updoc/EditorView.swift
git commit -m "feat: refine autocomplete UI for real-world network latency"
```
