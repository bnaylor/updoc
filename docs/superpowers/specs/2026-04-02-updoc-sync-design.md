# Design Doc: Google Docs Sync Implementation

**Date:** 2026-04-02  
**Status:** Draft  
**Topic:** Bidirectional Sync & Authentication

## Overview
This document outlines the implementation plan for the **Google Docs Sync** feature in **updoc**. It covers the OAuth2 authentication flow, the bidirectional sync protocol, and the emergency "Escape Hatch" for direct browser editing.

## Goals
- **Secure Authentication:** OAuth2 via system browser with Keychain token storage.
- **Reliable Bidirectional Sync:** Automatic merging of local and remote changes.
- **Intelligent Pre-fetching:** Prioritizing active notes and upcoming meeting data.
- **Escape Hatch:** One-click access to the linked Google Doc in the browser.

## Architecture

### Sync Coordinator (Swift Actor)
- **State Management:** Manages the sync state (lastSyncedRevision, tokens).
- **Drive API Monitor:** Periodically checks for remote changes.
- **Docs API Synchronizer:** Handles content conversion and updates.

### OAuth2 Authentication Manager
- **Flow:** System browser redirect → custom URL scheme callback.
- **Credential Storage:** macOS Keychain (access/refresh tokens).
- **Scope Management:** Docs, Drive, and User Profile.

### Sync Protocol
- **Push Cycle:** Debounced local updates (~2s inactivity).
- **Pull Cycle:** Periodic remote change checks (~30s intervals).
- **Conflict Handling:** 3-way merge algorithm with a side-by-side resolver UI for manual resolution.

## Key Features

### 1. Initial Authentication
- Triggered on first sync attempt or when tokens expire.
- Opens default browser for Google login.
- Automatically returns to **updoc** after authorization.

### 2. Intelligent Pre-fetching
- Automatically syncs the current note and any notes linked to upcoming meetings (within a 4-hour window).
- Fallback: "Sync All Notes" option in the menubar/settings for manual refreshes.

### 3. Open in Browser
- A "Open in Google Docs" button or menu item in the editor header for linked notes.
- Instantly opens the Google Doc URL in the default browser.

## Security Considerations
- **Keychain Integration:** Protecting sensitive tokens.
- **HTTPS Enforcement:** All API calls made over secure connections.
- **Localized Encryption:** Leveraging macOS system-level encryption for the app's data folder.

## Future Considerations
- **Advanced Merge Strategies:** Semantic merging for specific document structures (e.g., tables).
- **Offline Batch Replay:** More robust handling of long-term offline edits.
- **Sync Status Visuals:** Richer indicators of sync progress and health.
