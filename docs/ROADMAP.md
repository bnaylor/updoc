# updoc Roadmap

This document tracks planned features, improvements, and "nice-to-have" ideas for the `updoc` project.

## P0: Core Functionality (Current Focus)
- [x] **WriteControl & Conflict Resolution**: Atomic updates with revision tracking and 3-way merge.
- [x] **Vision-Based Feedback Loop**: Autonomous UI verification using `screencapture` and vision analysis.
- [ ] **Robust Offline Support**: Better handling of sync when connectivity is intermittent.

## P1: Nice to Have / Future Enhancements
- [ ] **Apple Ecosystem Integration (AppIntents)**:
  - Enable deep integration with Siri, Spotlight, and Widgets.
  - Allow users to "Sync all notes" or "Create new note" via Siri Shortcuts.
  - Expose note metadata to Spotlight for system-wide search.
  - Conforming your note model to AppEntity and FileEntity allows the system to treat your Google Docs as native system objects. Gemini can help you write the AppIntent that takes a string and pipes it directly to your backend

## P2: Polish & Scaling
- [ ] **Smart Filtering for Calendar Events**:
  - Automatically filter out non-meeting events (e.g., "Lunch", "Exercise", "Work Location") to reduce sidebar clutter.
  - Allow users to define custom "Ignore" keywords.
- [ ] **Multi-account Support**: Allow syncing with multiple Google Workspace accounts.
- [ ] **Advanced Markdown Support**: Tables, footnotes, and advanced formatting.
