# updoc Project Status - 2026-04-04

## 🎯 Current Mission Status: PHASE 8 COMPLETE
We have successfully implemented Advanced Image Editing and a dedicated Offline Conflict UI, while also addressing several bug and polish items from initial user feedback.

---

## ✅ Completed Features

### 1. Core Native App
- **Native macOS Shell:** SwiftUI-based with a 3-column navigation split view.
- **Local Persistence:** Full `SwiftData` integration for notes and metadata.
- **High-Performance Editor:** `TextKit 2` (NSTextView) wrapper for zero-lag text entry.
- **Improved Focus:** Editor now captures keyboard input correctly on launch.

### 2. Task Sidebar
- **Global Task List:** A dedicated right-hand column showing all `ActionItems` across all notes.
- **Grouping & Sorting:** Automatic categorization into Overdue, Today, Upcoming, and No Due Date.
- **Bidirectional Sync:** Toggling a checkbox in the sidebar instantly updates the Markdown content in the source note.
- **Navigation:** Clicking any task in the sidebar immediately jumps to the associated note in the editor.

### 3. Markdown & Styling
- **Markdown Engine:** Robust regex-based parser for headings, bold, italic, and code.
- **Live-Preview:** Real-time application of theme-aware styles as you type.
- **Enhanced Syntax:** Support for `[ ]` and `√` (auto-converting shortcut) for checklists.
- **Action Item Promotion:** Right-click any checklist item to "Promote to Action Item," creating a tracked task linked to the note.

### 4. Google Docs Sync (Production Ready)
- **AuthManager:** Production OAuth2 integration using `GTMAppAuth` and `ASWebAuthenticationSession`.
- **SyncCoordinator:** `@MainActor` orchestrator managing bidirectional REST-based sync.
- **Service Layer:** Real implementations for `GDocsService`, `GDriveService`, and `GCalendarService` using native `URLSession` and `Codable`.

### 5. Search & Filtering
- **Global Search (Cmd+Shift+F):** Dedicated overlay for full-text search across all notes with contextual snippets.
- **Inline Hashtags:** Automatic extraction and indexing of `#tags` from Markdown content.
- **Editor Sync:** Selecting a search result automatically opens the note and scrolls to the matched text.

### 6. Bidirectional Image Sync & Editing (New!)
- **Drive Asset Library:** Automatically uploads local images to a dedicated `updoc_assets` folder on Google Drive.
- **Advanced Editing:** Double-click any image to open the native macOS Markup toolkit (crop, rotate, annotate).
- **Metadata Tagging:** Uses Google Docs image description metadata (`updoc_asset:{assetId}`) to maintain sync parity.
- **Asynchronous Rendering:** `EditorView` renders both local and remote images using a thread-safe caching layer.

### 7. Draft Mode & Structured Publishing
- **Local-Only Drafts:** Notes with no `googleDocId` are marked with a `DRAFT` tag in the sidebar.
- **Meeting Attribution:** Tracks the source calendar event via `meetingID` to allow smart folder organization.
- **Auto-Organization:** Automatically publishes drafts into `/updoc/Meetings` or `/updoc/General` on Google Drive.
- **One-Click Promotion:** A prominent "Publish" button replaces sync controls for local-only content.

### 8. Conflict Resolution (New!)
- **Offline Conflict UI:** A clear, side-by-side interface for resolving sync conflicts when changes happen in both local and remote versions.
- **Resolution Choices:** Explicit options to "Use Mine," "Use Remote," or cancel the sync operation.

---

## 🏗 Technical Architecture
- **Language:** Swift 6.0 (Concurrency-safe).
- **Frameworks:** SwiftUI, SwiftData, TextKit 2, AuthenticationServices, GTMAppAuth, QuickLookUI.
- **Layout:** `NavigationSplitView` with 3 columns (Sidebar, Content, Detail) and consistent pane sizing.
- **Sync Logic:** Explicit conflict detection comparing both revision IDs and actual content.

---

## 🚀 Immediate Next Steps
1. **App Bundling & Icons:** Create a proper `.app` bundle with high-quality icons.
2. **Deep Linking:** Support opening updoc via `updoc://` URLs.
3. **Advanced Templating:** More flexible rules for automated note content creation.

---

## 📝 Developer Notes
- Task Sidebar visibility is managed via `columnVisibility` in `ContentView`.
- Image editing uses `QLPreviewPanel` with `isEditingAllowed = true`.
- Build command: `swift build`
- Test command: `swift test`
