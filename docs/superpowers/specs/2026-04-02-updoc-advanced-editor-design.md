# Design Doc: updoc Advanced Editor Features

**Date:** 2026-04-02  
**Status:** Draft  
**Topic:** Rich-Text Integration, Chips, Checklists, and Image Management

## Overview
This document outlines the implementation of rich-text features in the **updoc** editor. It moves beyond basic Markdown styling to include interactive "Chips," enhanced checklist behavior, and a local image library with Google Drive sync.

## Goals
- **Interactive @Mentions:** Smart autocomplete for persons (Moma) and dates.
- **Fluent Checklists:** Support for `[ ]` and `√` (Option+V) syntax with auto-conversion.
- **Action Item Promotion:** Ability to turn checklist items into tracked tasks with assignments.
- **Library-Based Images:** Fast local image management with asynchronous Drive sync.
- **Seamless Sync:** Translating rich editor elements into faithful Google Docs representations.

## Architecture

### 1. Rich-Text Engine (TextKit 2)
- **NSTextAttachment:** Used for "Contact Chips" and "Date Chips."
- **Custom Attributes:** Used for checklist states and "Action Item" tracking.
- **Autocomplete Manager:** A logic layer that monitors text input for `@` and `√` triggers.

### 2. Moma & Date Services
- **MomaService:** Fetches person metadata from the internal directory.
- **DateService:** Parses keywords like "today," "next Friday," or specific dates into `Date` objects.

### 3. Image Library Manager
- **Storage:** Images are stored in a hidden `assets/` folder within the app's data directory.
- **Sync:** The `SyncCoordinator` monitors this folder and handles Drive uploads.

## Key Workflows

### 1. Smart '@' Autocomplete
- Typing `@` opens a suggestion list.
- **Matches:**
    - Directory names/emails (Moma).
    - Date keywords (Today, Tomorrow, etc.).
- **Output:** A rich `NSTextAttachment` (Chip) embedded in the document.

### 2. Checklist & Action Items
- **Shortcuts:** `[ ]` or `√` at the start of a line.
- **Behavior:** Checking a task applies strike-through and dimming.
- **Promotion:** Context menu action to "Promote to Action Item," adding assignments and status tracking (stored in `SwiftData`).

### 3. Image Drag-and-Drop
- Dragging an image into the editor:
    1.  Saves the image to the local library.
    2.  Inserts a placeholder/preview in the editor.
    3.  Triggers a background upload to Google Drive for future Doc sync.

## Technical Choices
- **UI:** Custom `NSTextView` delegate for autocomplete and attachment handling.
- **Data Model:** `ActionItem` and `AssetReference` models added to `SwiftData`.
- **Sync Bridge:** Mapping `NSTextAttachment` elements to Google Docs `InlineObject` or `link` types.

## Future Considerations
- **Sharpei Integration:** Direct sync of "Promoted Action Items" to the Sharpei task manager.
- **Third-Party Chips:** Potentially supporting chips for other services (e.g., Buganizer IDs).
- **Advanced Image Editing:** Basic cropping/annotation within updoc.
