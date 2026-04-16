# updoc Roadmap

This document tracks planned features, improvements, and "nice-to-have" ideas for the `updoc` project.

## P0: Core Functionality (Current Focus)
- [x] **WriteControl & Conflict Resolution**: Atomic updates with revision tracking and 3-way merge.
- [x] **Vision-Based Feedback Loop**: Autonomous UI verification using `screencapture` and vision analysis.
- [ ] **Robust Offline Support**: Better handling of sync when connectivity is intermittent.
- [ ] **Remove Action Items Code**: Eliminate the concept of special "Action Items" in the code, treating all lists as standard markdown lists.
- [ ] **Clean Default Inspector**: Hide the inspector pane by default, preserving it for future extensions (templates, categories, Gemini).
- [ ] **Note Naming**: Support setting custom titles for newly created, non-meeting general notes.

## P1: Nice to Have / Future Enhancements
- [ ] **Apple Ecosystem Integration (AppIntents)**:
  - Enable deep integration with Siri, Spotlight, and Widgets.
  - Allow users to "Sync all notes" or "Create new note" via Siri Shortcuts.
  - Expose note metadata to Spotlight for system-wide search.
- [ ] **Weekly Journal / Snippets**: A top-level or pinned quick-access view for a rotating weekly log to track team snippets.
- [ ] **Hierarchical Organization**: 
  - Full drag-and-drop file/folder nesting for General notes mirroring the UI to the filesystem and Google Drive.
  - Self-organizing `YYYY-MM-DD` tree structure for Meeting Notes.
- [ ] **Smart Templates**: First-class UI for managing and automatically applying structure (e.g. distinct 1:1 meeting formats).
- [ ] **Category Tags**: Interactive tagging to cleanly slice documents.
- [ ] **Sharpei Linkage**: Right click integration to instantly pipe actionable items to a Sharpei task.

## P2: Polish & Scaling
- [ ] **Smart Filtering for Calendar Events**:
  - Automatically filter out non-meeting events (e.g., "Lunch", "Exercise", "Work Location") to reduce sidebar clutter.
  - Allow users to define custom "Ignore" keywords.
- [ ] **Multi-account Support**: Allow syncing with multiple Google Workspace accounts.
- [ ] **Advanced Markdown Support**: Tables, footnotes, and advanced formatting.
- [ ] **External Doc Aliasing**: Link external complex web docs inline, potentially rendering as a simple pointer or iframe.
- [ ] **Embedded Gemini Assist**: Integrate direct AI summarization tools.
