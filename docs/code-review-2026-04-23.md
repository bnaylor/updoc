# updoc — Architecture & Code Review
_Reviewed 2026-04-23_

Overall this is solid, well-structured code. The `@Observable`/SwiftData data layer is correctly set up, the `NSViewRepresentable` editor is the right call for a feature-rich markdown editor, and concurrency patterns are mostly correct. The issues below are real — no nitpicks.

---

## NoteDetailView.swift

**Lines 45, 101, 107, 119, 146, 177: Use `foregroundStyle()` instead of `foregroundColor()`.**

```swift
// Before
Label("Read-Only", systemImage: "lock.fill")
    .foregroundColor(.secondary)

// After
Label("Read-Only", systemImage: "lock.fill")
    .foregroundStyle(.secondary)
```

**Lines 48, 113, 136: Use `clipShape(.rect(cornerRadius:))` instead of `cornerRadius()`.**

```swift
// Before
.background(Color.secondary.opacity(0.15))
.cornerRadius(4)

// After
.background(Color.secondary.opacity(0.15))
.clipShape(.rect(cornerRadius: 4))
```

**Line 93: Use `.scrollIndicators(.hidden)` instead of `showsIndicators: false`.**

```swift
// Before
ScrollView(.horizontal, showsIndicators: false) {

// After
ScrollView(.horizontal) {
    // ...
}
.scrollIndicators(.hidden)
```

**Line 159: Use the two-parameter `onChange` overload, not the zero-parameter one.**

```swift
// Before
.onChange(of: note.id) {
    if note.title == "New Note" ...
}

// After
.onChange(of: note.id) { _, _ in
    if note.title == "New Note" ...
}
```

**Lines 182–185: Avoid `Binding(get:set:)` in body — use a local state variable + `onChange`.**

The theme picker creates an ad-hoc `Binding` to translate between `nil` and `"Default"`:

```swift
// Before
Picker("", selection: Binding(
    get: { note.themeName ?? "Default" },
    set: { note.themeName = $0 == "Default" ? nil : $0 }
)) { ... }

// After
@State private var selectedTheme = "Default"

Picker("", selection: $selectedTheme) { ... }
    .onChange(of: selectedTheme) { _, newValue in
        note.themeName = newValue == "Default" ? nil : newValue
    }
    .onAppear {
        selectedTheme = note.themeName ?? "Default"
    }
```

---

## NoteListView.swift

**Lines 27–29, 35–37: Use `foregroundStyle()` + `clipShape(.rect(cornerRadius:))`.**

Same as above (section headers using `.foregroundColor(.secondary)`, DRAFT badge using `.cornerRadius(4)`).

**Line 207–208: `DateFormatter()` allocated per `meetingGroups` evaluation.**

`meetingGroups` is a computed var called from `body`. Creating a `DateFormatter` inline here is unnecessary — `Calendar` already has `shortMonthSymbols`:

```swift
// Before
let monthName = DateFormatter().shortMonthSymbols[month - 1]

// After
let monthName = Calendar.current.shortMonthSymbols[month - 1]
```

**Lines 93–98, 101–107: Replace `DispatchQueue.main.async` in `onAppear`/`onChange` with direct calls.**

SwiftUI views are already on the main actor. The `DispatchQueue.main.async` wrapping only adds unnecessary indirection:

```swift
// Before
.onAppear {
    DispatchQueue.main.async {
        if let data = expandedFoldersJSON.data(using: .utf8) ...
    }
}

// After
.onAppear {
    if let data = expandedFoldersJSON.data(using: .utf8) ...
}
```

**Lines 192–214: `meetingGroups` is expensive work done in `body`.**

This computed var chains multiple `Dictionary(grouping:)` calls and multiple `.sorted {}` passes on every body evaluation. Cache it:

```swift
// In NoteListView, add:
@State private var meetingGroupsCache: [YearGroup] = []

// Then populate with .onChange(of: notes) { ... } and .onAppear { ... }
```

---

## SidebarView.swift

**Lines 167, 173, 188, 219, 248: Use `foregroundStyle()` instead of `foregroundColor()`.**

**Lines 130–135: Replace `DispatchQueue.main.async` in `onAppear` with `.task`.**

The `onAppear` wraps an async call in `DispatchQueue.main.async`, but `Task { }` is the right pattern here. Using `.task` also cancels automatically if the view disappears:

```swift
// Before
.onAppear {
    DispatchQueue.main.async {
        if AuthManager.shared.isAuthenticated() {
            refreshMeetings()
        }
    }
}

// After
.task {
    if AuthManager.shared.isAuthenticated() {
        refreshMeetings()
    }
}
```

**Duplicated `extractDocId` — `SidebarView` and `FolderTreeItem` both define their own version.** They don't even use the same implementation (one uses `String.range(of:)`, the other uses `NSRegularExpression`). Extract once to a free function or a `String` extension.

---

## ContentView.swift

**Line 39: `private static let syncCoordinator` is static state on a view type.**

SwiftUI owns view values and recreates them — a `static let` here means this is global mutable singleton state attached to a view, bypassing SwiftUI's lifecycle. This should be `@State` (like `deletionManager` and `liveSyncManager` already are) or owned at the app level:

```swift
// Before
private static let syncCoordinator = SyncCoordinator()

// After (in ContentView)
@State private var syncCoordinator = SyncCoordinator()
```

**Lines 126–130: 500ms `Task.sleep` before `checkConfig()` is fragile.**

This is checking for empty OAuth credentials, which doesn't need any view hierarchy to be ready. A `Task.sleep` here is a timing assumption that can break. Trigger this from `onAppear` or use `.task(id: someStableID)` to ensure it runs once.

---

## EditorView.swift

**Lines 189–208: `NotificationCenter` observer added in `makeNSView` is never removed.**

`makeNSView` is called once, which is fine, but the observer closure captures `textView` strongly. If the note changes and the coordinator is torn down without deregistering this observer, it will still fire. Store the returned token and remove it in the coordinator's deinit or a `dismantle` callback:

```swift
// In makeNSView, capture the token:
let token = NotificationCenter.default.addObserver(...)
context.coordinator.focusObserverToken = token

// In Coordinator:
var focusObserverToken: NSObjectProtocol?
deinit {
    if let token = focusObserverToken {
        NotificationCenter.default.removeObserver(token)
    }
}
```

**Line 113: `private let engine = MarkdownEngine()` on the `NSViewRepresentable` struct.**

The struct is recreated on every update cycle. The `engine` is re-allocated each time, even though it's accessed via `parent.engine` inside the long-lived `Coordinator`. Move it to the `Coordinator` where it will only be created once:

```swift
// In Coordinator:
private let engine = MarkdownEngine()

// In applyStyles, replace parent.engine with self.engine
```

---

## updocApp.swift

**Lines 96–118: Hardcoded template logic duplicated in both `Settings` and the sheet in `ContentViewSheets`.**

The `onAddRule` closure that creates `TemplateRule(attribute: .title, pattern: "1:1", ...)` is identical in both places. This belongs in `SettingsView` itself or a dedicated creation function, not duplicated across call sites.

---

## Note.swift

**Line 47: `@unchecked Sendable` on a mutable `@Model` class.**

`Note` is a SwiftData model class — it's mutable and its mutations are not synchronized. The `@unchecked Sendable` conformance silences compiler warnings rather than solving the underlying issue. Treat `Note` as `@MainActor`-only and pass `PersistentIdentifier` across actor boundaries (which `SyncCoordinator.sync(noteId:in:)` already does correctly). The conformance can be removed if you ensure `Note` is never accessed off-MainActor.

---

## Architecture Notes (Cross-Cutting)

**NotificationCenter as primary inter-view communication.**

The app has 22 `Notification.Name` constants and `onReceive` listeners spread across multiple views and modifiers. This makes the control flow hard to follow and test. Since you're already on `@Observable` + SwiftData, the notifications that pass data (`.syncNote`, `.publishNote`, `.deleteSelectedNote`, `.openAddContactDialog`, etc.) could be replaced with method calls or observable state on a coordinator object. The zero-data notifications (`.treeNeedsRefresh`, `.focusEditor`) are harder to eliminate but are a smaller concern.

This is a larger refactor, not a bug — but it's worth knowing about as the app grows.

---

## Prioritized Summary

1. **API deprecations (high):** `foregroundColor()` → `foregroundStyle()` and `cornerRadius()` → `clipShape(.rect(cornerRadius:))` appear in every view file. Quick find-and-replace.
2. **`static let syncCoordinator` on a view (high):** Subtle correctness issue — move to `@State`.
3. **NotificationCenter observer leak in `EditorView` (high):** The `focusEditor` observer is never removed.
4. **`Binding(get:set:)` in inspector (medium):** Fragile pattern, breaks undo.
5. **`meetingGroups` expensive body work (medium):** Causes unnecessary recomputation on every note list update.
6. **`MarkdownEngine` on struct (medium):** Reallocated on every SwiftUI update cycle; move to coordinator.
7. **`DateFormatter()` inline (medium):** Use `Calendar.current.shortMonthSymbols` instead.
8. **Duplicated `extractDocId` (low):** Two different implementations doing the same job.
9. **`DispatchQueue.main.async` in `onAppear` (low):** Unnecessary; remove the wrapping.
10. **`@unchecked Sendable` on `Note` (low):** Informational — document the constraint, don't suppress it.
