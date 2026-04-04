# Design Spec: Bidirectional Image Sync

**Date:** 2026-04-03
**Status:** Approved
**Topic:** Bidirectional image handling between Google Docs and the local Image Library.

## 1. Problem Statement
The current `updoc` implementation supports local image drag-and-drop using `![[assetId]]` placeholders, but these images are lost during synchronization with Google Docs. Conversely, images added to Google Docs via the web UI are not currently pulled down or displayed in the local editor.

## 2. Goals
- **Push:** Automatically upload local images to Google Drive and insert them into the corresponding Google Doc.
- **Pull:** Detect images in Google Docs and represent them in the local Markdown.
- **Offline Persistence:** Keep local images as local assets for speed and offline access.
- **Metadata Sync:** Use image "description" fields in Google Docs to track local `assetId` mapping.

## 3. Architecture

### 3.1. Google Drive Asset Storage
- **Location:** A dedicated folder named `updoc_assets` will be created in the user's root "My Drive".
- **Naming:** Files will be stored as `{assetId}.{ext}` to ensure uniqueness and easy mapping.
- **Persistence:** Before inserting into a GDoc, the `SyncCoordinator` will verify the image exists in this Drive folder.

### 3.2. Mapping Layer
To avoid redundant uploads and facilitate bidirectional sync, we will maintain a mapping between local `assetId` and remote `driveFileId`.
- **Implementation:** A new SwiftData model `ImageMap` or an extension to `ImageLibraryManager`.
- **Properties:** `assetId` (String), `driveFileId` (String), `driveUrl` (String), `lastSyncedRevision` (String).

### 3.3. Metadata Tagging
When inserting an image into a Google Doc:
- **Property:** `description` (within `inlineObject.inlineObjectProperties.embeddedObject`).
- **Value:** `updoc_asset:{assetId}`.
- **Purpose:** Allows `updoc` to recognize its own images and link them back to local files without expensive content hashing.

## 4. Workflows

### 4.1. Push (Local → GDocs)
1. **Extraction:** `GDocsService.updateDocContent` scans Markdown for `![[assetId]]`.
2. **Upload:** For each `assetId`:
   - If not already uploaded (check local mapping), upload the file from `ImageLibraryManager` to the `updoc_assets` Drive folder.
   - Store the resulting `driveFileId`.
3. **Insertion:** Use `batchUpdate` with `insertInlineImage`:
   - `uri`: A direct link to the Drive file (or a temporary publicly readable link if needed).
4. **Tagging:** Follow up with another `batchUpdate` to set the `description` of the newly created `inlineObject` to `updoc_asset:{assetId}`.

### 4.2. Pull (GDocs → Local)
1. **Parsing:** `GDocsService.fetchDocContent` parses `inlineObjects`.
2. **Identification:**
   - Check the `description` field for the `updoc_asset:{assetId}` tag.
   - If found AND `assetId` exists locally, use `![[assetId]]` in the generated Markdown.
   - If NOT found (image added via web UI), use the standard Markdown image syntax `![title](https://...)` with the Google Docs image source URL.
3. **Rendering:** `EditorView` (TextKit 2) will be updated to render remote `![](https://...)` images by fetching them asynchronously.

## 5. Technical Components
- **GDriveService:** Enhanced to handle folder creation, file search, and multipart uploads.
- **GDocsService:** Updated to handle `insertInlineImage` and `updateEmbeddedObject` requests.
- **SyncCoordinator:** Orchestrates the multi-step process (Upload to Drive -> Insert into Doc -> Tag Metadata).

## 6. Constraints & Safety
- **Permissions:** Using an app-specific folder in "My Drive" ensures we always have write access.
- **Conflicts:** If a local image is deleted but remains in the Doc, the "Pull" flow will treat it as a remote image.
- **Auth:** Requires `https://www.googleapis.com/auth/drive.file` scope in addition to existing scopes.
