# updoc Project Status - 2026-04-03

## 🎯 Current Mission Status: PHASE 7 COMPLETE
We have successfully implemented Draft Mode, providing visual distinction for local notes and structured publishing to Google Drive.

---

## ✅ Completed Features

### 1. Core Native App
- **Native macOS Shell:** SwiftUI-based with a 3-column navigation split view.
- **Local Persistence:** Full `SwiftData` integration for notes and metadata.
- **High-Performance Editor:** `TextKit 2` (NSTextView) wrapper for zero-lag text entry.

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

### 6. Moma/Directory Integration
- **Smart @mentions:** Responsive person lookup triggered by the "@" key, inserting styled user chips.
- **MomaService:** Real internal directory lookups via REST API.

### 7. Bidirectional Image Sync
- **Drive Asset Library:** Automatically uploads local images to a dedicated `updoc_assets` folder on Google Drive.
- **Metadata Tagging:** Uses Google Docs image description metadata (`updoc_asset:{assetId}`) to maintain sync parity.
- **Rich-Media Pull:** Detects images in Google Docs and restores local asset placeholders or renders remote images.
- **Asynchronous Rendering:** `EditorView` now renders both local and remote images using a thread-safe caching layer.

### 8. Draft Mode & Structured Publishing (New!)
- **Local-Only Drafts:** Notes with no `googleDocId` are marked with a `DRAFT` tag in the sidebar.
- **Meeting Attribution:** Tracks the source calendar event via `meetingID` to allow smart folder organization.
- **Auto-Organization:** Automatically publishes drafts into `/updoc/Meetings` or `/updoc/General` on Google Drive.
- **One-Click Promotion:** A prominent "Publish" button replaces sync controls for local-only content.

---

## 🏗 Technical Architecture
- **Language:** Swift 6.0 (Concurrency-safe).
- **Frameworks:** SwiftUI, SwiftData, TextKit 2, AuthenticationServices, GTMAppAuth.
- **Layout:** `NavigationSplitView` with 3 columns (Sidebar, Content, Detail).
- **Sync Logic:** Regex-based Markdown updating for status parity between views.
- **Image Handling:** Multipart Drive uploads with dynamic MIME-type detection (UTType).
- **Folder Resolution:** Recursive `getOrCreateFolder` implementation for structured Drive publishing.

---

## 🚀 Immediate Next Steps
1. **Advanced Image Editing:** Basic cropping/annotation within updoc (using native macOS Markup features).
2. **Offline Conflict UI:** Improved resolution interface for complex sync conflicts.

---

## 📝 Developer Notes
- Task Sidebar visibility is managed via `columnVisibility` in `ContentView`.
- Bidirectional task sync is handled by `Note.updateContent(for:)` using regex.
- Build command: `swift build`
- Test command: `swift test`
