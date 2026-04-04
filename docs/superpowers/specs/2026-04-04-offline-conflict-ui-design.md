# Offline Conflict UI Design

**Goal:** Provide a clear, side-by-side interface for resolving sync conflicts between local updoc notes and Google Docs.

## Overview
When a note has been modified both locally and on Google Docs since the last sync, updoc currently appends the remote changes to the bottom of the note. This design replaces that automated merge with a user-facing resolution sheet.

## Architecture & Data Flow

### 1. Error Handling
- Define a structured `SyncError` enum:
  ```swift
  enum SyncError: Error {
      case conflict(local: String, remote: String, remoteRevision: String)
      case authRequired
      case networkError(Error)
  }
  ```
- Update `SyncCoordinator.sync` to detect version mismatches and throw `.conflict` instead of performing a silent merge.

### 2. Conflict Resolution State
- `ContentView` will track an `activeConflict` state:
  ```swift
  @State private var activeConflict: SyncConflict?
  ```
- When `triggerSync` catches a `.conflict` error, it populates this state to trigger the UI.

### 3. Resolution Logic
The user will have three primary resolution paths:
- **Keep Local:** Discards remote text changes but adopts the `remoteRevision` ID (marking the local version as the new "latest").
- **Keep Remote:** Overwrites the local `Note.content` with the remote content and updates the revision ID.
- **Manual Merge:** Provides a way to combine both (effectively the current behavior but explicit).

## UI/UX: ConflictResolutionView
- **Presentation:** A modal sheet presented over the main window.
- **Layout:** Side-by-side scrollable text views.
  - **Left Column:** "Your Local Version" with a "Use Mine" button.
  - **Right Column:** "Google Docs Version" with a "Use Remote" button.
- **Styling:** Uses the application's current theme for text rendering.
- **Feedback:** Clear headers indicating the source of each text block.

## Success Criteria
- [ ] Syncing a conflicted note triggers the resolution sheet instead of appending text.
- [ ] Selecting "Use Mine" preserves local changes and allows future syncs to proceed.
- [ ] Selecting "Use Remote" correctly updates the local note with the Google Docs content.
- [ ] The sheet is dismissible/cancelable without data loss (sync is simply aborted).
