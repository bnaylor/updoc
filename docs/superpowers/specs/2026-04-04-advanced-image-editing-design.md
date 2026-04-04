# Advanced Image Editing Design

**Goal:** Provide a simple, native way to crop and annotate images directly within updoc.

## Overview
Instead of building a custom image editor, updoc will leverage macOS's built-in **Markup** toolkit (via `QLPreviewPanel`). This allows users to crop, rotate, and add annotations (arrows, text, shapes) to any image asset.

## Architecture & Interaction

### 1. Triggers
- **Double-Click:** In the `EditorView`, double-clicking an image attachment (`RemoteImageAttachment`) triggers the editor.
- **Context Menu:** Right-clicking an image attachment shows an "Edit Image..." menu item.

### 2. Editor Integration
- Use `QLPreviewPanel` to present the image.
- Configure the panel for editing:
  - Provide the local file URL via `QLPreviewPanelDataSource`.
  - Implement `QLPreviewPanelDelegate` to handle saving and refreshing.
  - Set `isEditingAllowed = true` to enable the Markup toolbar.

### 3. Data Flow & Sync
- **Overwrite Mode:** The Markup toolkit directly overwrites the file at the local URL provided by `ImageLibraryManager`.
- **Cache Invalidation:** After the user clicks "Done", `RemoteImageCache` must be invalidated for that specific URL to ensure the `EditorView` refreshes the rendered image.
- **Sync Trigger:** The modification triggers a standard sync cycle. `SyncCoordinator` will detect the file hash change (or simply see the local version is newer than `lastSyncedRevision`) and upload the updated image to Google Drive.

## UI/UX
- The editing experience is a standard macOS overlay window, providing a familiar and high-quality toolset without adding complexity to the updoc codebase.

## Success Criteria
- [ ] Users can open any image in the editor via double-click or right-click.
- [ ] Edits (cropping, arrows, text) are saved back to the local file.
- [ ] The updated image is immediately reflected in the `EditorView`.
- [ ] The updated image is synced to Google Drive on the next sync.
