# updoc

`updoc` is a less-friction, native macOS note-taking application designed for engineers and managers who live in the Google ecosystem but crave a high-performance, distraction-free local editing experience with organization and integration with Calendar, etc.

![updoc Icon](assets/updoc_icon.png)

## 🎯 Why updoc?

Most Google Docs workflows suffer from "tab fatigue" and latency. `updoc` bridges the gap by providing:
- **Zero-Lag Editing:** A native `TextKit 2` editor that feels as fast as your favorite IDE.
- **Deep Google Integration:** Bidirectional sync with Google Docs, Drive, and Calendar.
- **Task-First Workflow:** A dedicated sidebar that promotes checklist items to tracked tasks.
- **Native macOS Experience:** Built with SwiftUI and SwiftData for performance and system-wide integration (Markup, QuickLook, etc.).

---

## ✨ Major Features

### 🚀 High-Performance Markdown Editor
Write in clean Markdown with real-time, theme-aware styling. Powered by `TextKit 2`, it handles large documents with ease and supports:
- Headings, bold, italic, and code blocks.
- Inline `#hashtags` for automatic indexing and search.
- Interactive checklists with `[ ]` and `√` shortcuts.

### 🔄 Google Sync
Seamlessly bridge your local notes with the cloud:
- **Bidirectional Sync:** Edit locally or on the web; `updoc` handles the rest.
- **Smart Conflict Resolution:** A side-by-side UI for resolving version mismatches when changes occur in both places.
- **Drive Asset Library:** Images are automatically synced to a dedicated `updoc_assets` folder on Google Drive.

### 🗓 Meeting-Aware Organization
Stop hunting for meeting notes:
- **Calendar Integration:** Automatically links notes to Google Calendar events.
- **Smart Folder Trees:** Auto-organizes notes into `/updoc/Meetings` (by date) or `/updoc/General`.
- **Meeting Attribution:** Tracks attendees and event metadata for better context.

### ✅ Integrated Task Sidebar
Turn your notes into action:
- **Global Action Items:** See all tasks across all notes in one unified, grouped view (Overdue, Today, Upcoming).
- **Bidirectional Checkbox Sync:** Toggling a task in the sidebar updates the source Markdown file instantly.
- **Note Navigation:** Click any task to jump directly to the relevant line in the editor.

### 🖼 Advanced Image Handling
- **Native Markup:** Double-click any image to open the macOS Markup toolkit for cropping, rotation, and annotation.
- **Cloud Parity:** Uses image metadata to maintain sync between local files and Google Docs.

---

## 📸 Screenshots

### Main Editor & Navigation
> *[PLACEHOLDER: A screenshot showing the 3-column layout with the note list, the Markdown editor, and the Task Sidebar]*

### Conflict Resolution UI
> *[PLACEHOLDER: A screenshot showing the side-by-side comparison view for resolving sync conflicts]*

### Settings & Google Auth
> *[PLACEHOLDER: A screenshot of the native macOS Settings pane for Google API configuration]*

---

## 🛠 Tech Stack

- **Language:** Swift 6.0 (Strict Concurrency)
- **UI Framework:** SwiftUI & TextKit 2
- **Persistence:** SwiftData
- **Auth:** GTMAppAuth & AuthenticationServices
- **Sync:** REST-based Google Drive/Docs/Calendar APIs

---

## 🚀 Getting Started

### Prerequisites
- macOS 14.0+
- Xcode 15.0+
- A Google Cloud Project with Docs, Drive, and Calendar APIs enabled.

### Building from Source
1. Clone the repository:
   ```bash
   git clone https://github.com/bnaylor/updoc.git
   cd updoc
   ```
2. Run the bundling script to create the `.app` bundle:
   ```bash
   ./scripts/bundle.sh
   ```
3. Open `updoc.app` from the root directory.

### Configuration
On first launch, open **Settings (Cmd+,)** and enter your Google Client ID and Secret to enable synchronization features.

---

## 📝 Development Status
`updoc` is currently in active development (**Phase 9: App Bundling & Persistent Settings Complete**). See [STATUS.md](STATUS.md) for a detailed breakdown of completed features and [ROADMAP.md](docs/ROADMAP.md) for what's coming next.

---

## 🤝 Contributing
Contributions are welcome! Please see [TODOS.md](TODOS.md) for a list of known bugs and planned improvements.

---

## 📄 License
This project is private and for internal use unless otherwise specified.

---
*Co-authored-by: Gemini <gemini-cli@google.com>*
