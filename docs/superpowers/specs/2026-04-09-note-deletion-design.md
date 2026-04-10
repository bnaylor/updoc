# Design Spec: Note Deletion and Google Docs Integration

## Overview
This specification outlines the implementation of a robust note deletion system in `updoc`. The system includes local deletion from SwiftData and optional trashing of linked Google Docs, with safety checks for file ownership and permissions.

## Goals
- Allow users to delete notes via keyboard shortcuts (`Cmd+Backspace`), context menus, and the app menu (`File > Delete Note`).
- Provide an optional "Move to Trash" for linked Google Docs.
- Prevent trashing Google Docs that the user does not own or have permission to delete.
- Maintain a consistent user experience across different deletion triggers.

## Architecture

### 1. `DeletionManager` (New Class)
A centralized manager (Observable) to handle the deletion lifecycle and UI state.
- **Properties:**
  - `showDeleteConfirmation`: Boolean to trigger the confirmation dialog.
  - `pendingNoteToDelete`: The `Note` object currently being considered for deletion.
  - `isDeleting`: Boolean to track the progress of a network-based (Google Drive) deletion.
- **Methods:**
  - `prepareDeletion(for note: Note)`: Sets the `pendingNoteToDelete` and triggers the confirmation UI.
  - `confirmDeletion(alsoTrashRemote: Bool)`: Performs the actual deletion from SwiftData and (optionally) Google Drive.

### 2. `GDriveService` Extensions
- `getFileMetadata(fileId: String)`: Fetches `ownedByMe` and `capabilities/canDelete` fields.
- `trashFile(fileId: String)`: Sends a `PATCH` request with `{ "trashed": true }`.

## UI/UX Design

### 1. Deletion Triggers
- **Keyboard Shortcut:** `Cmd + Backspace` (Standard macOS "Move to Trash" shortcut).
- **Context Menu:** Right-click a note in the `NoteListView` to see "Delete Note...".
- **App Menu:** `File > Delete Note` (Cmd+Backspace). Disabled if no note is selected.

### 2. Confirmation Dialog
A `.confirmationDialog` will appear when a deletion is triggered:
- **Case 1: Local Note (No Google Doc ID)**
  - Title: "Delete '[Title]'?"
  - Message: "This note will be permanently removed from updoc."
  - Action: "Delete Note" (Destructive).
- **Case 2: Linked Note (Owned by User)**
  - Title: "Delete '[Title]'?"
  - Message: "This note is linked to a Google Doc. Do you also want to move the Google Doc to the Trash?"
  - Action: "Delete Note & Trash Google Doc" (Destructive).
  - Action: "Delete Note Only" (Destructive).
- **Case 3: Linked Note (Not Owned by User)**
  - Title: "Delete '[Title]'?"
  - Message: "This note is linked to a Google Doc you don't own. The Google Doc will not be affected."
  - Action: "Delete Note Only" (Destructive).

## Implementation Plan

### Phase 1: Service & Data
1.  Update `GDriveService` with `getFileMetadata` and `trashFile` methods.
2.  Create `DeletionManager` to centralize deletion logic.

### Phase 2: UI Components
1.  Add `.contextMenu` to `NoteListView`.
2.  Add `.keyboardShortcut` and `CommandGroup` to `updocApp`.
3.  Implement the `.confirmationDialog` in `ContentView` (or a dedicated view modifier).

### Phase 3: Logic & Error Handling
1.  Implement the ownership check before showing the dialog.
2.  Handle network errors during `trashFile` gracefully (don't block local deletion if remote fails).

## Testing Strategy
- **Unit Tests:**
  - Verify `DeletionManager` correctly transitions states.
  - Mock `GDriveService` to test "owned" vs "not owned" scenarios.
- **UI Tests:**
  - Trigger deletion via keyboard, menu, and context menu.
  - Verify the confirmation dialog appears with correct options for each note type.
  - Ensure the note is removed from the `NoteListView` after deletion.

## Future Considerations
- **Multi-select Deletion:** The `DeletionManager` can be updated to accept `Set<Note>` instead of a single `Note`.
- **Undo Support:** Implementing an "Undo" feature for local deletions.
