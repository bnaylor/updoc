# Bidirectional Image Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement bidirectional image synchronization between the local `updoc` editor and Google Docs, using Google Drive as the asset host.

**Architecture:** We use a dedicated `updoc_assets` folder in Google Drive to store images. Local `![[assetId]]` tags are mapped to Drive File IDs via a local `ImageMap` SwiftData model. When pushing to Google Docs, images are inserted and tagged with metadata in the "description" field for easy identification during the pull phase.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, Google Drive API, Google Docs API.

---

### Task 1: GDriveService Enhancement

**Files:**
- Modify: `src/updoc/GDriveService.swift`
- Test: `tests/updocTests/GDriveServiceTests.swift`

- [ ] **Step 1: Add folder creation and file upload methods to GDriveService**
- [ ] **Step 2: Run build to verify types**
- [ ] **Step 3: Commit**

---

### Task 2: ImageMap Model

**Files:**
- Create: `src/updoc/Models/ImageMap.swift`
- Modify: `src/updoc/ImageLibraryManager.swift`

- [ ] **Step 1: Create ImageMap SwiftData model**
- [ ] **Step 2: Update ImageLibraryManager to track mappings**
- [ ] **Step 3: Commit**

---

### Task 3: GDocsService - Push Logic (Image Insertion)

**Files:**
- Modify: `src/updoc/GDocsService.swift`

- [ ] **Step 1: Add image insertion support to GDocsService**
- [ ] **Step 2: Commit**

---

### Task 4: GDocsService - Pull Logic (Image Parsing)

**Files:**
- Modify: `src/updoc/GDocsService.swift`

- [ ] **Step 1: Update convertToMarkdown to handle inline images**
- [ ] **Step 2: Commit**

---

### Task 5: SyncCoordinator Integration

**Files:**
- Modify: `src/updoc/SyncCoordinator.swift`

- [ ] **Step 1: Update SyncCoordinator to orchestrate image uploads**
- [ ] **Step 2: Commit**

---

### Task 6: EditorView Enhancement (Remote Images)

**Files:**
- Modify: `src/updoc/EditorView.swift`

- [ ] **Step 1: Update editor to render remote Markdown images**
- [ ] **Step 2: Final verification**
- [ ] **Step 3: Commit**
