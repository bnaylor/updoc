# Design Doc: updoc Native macOS Note-Taking App

**Date:** 2026-04-02  
**Status:** Draft  
**Topic:** Core Architecture & Sync Strategy

## Overview
updoc is a native macOS application designed for frictionless, high-performance note-taking, primarily optimized for users moving between frequent meetings. It combines the speed and simplicity of a Markdown-style editor with deep, live-ish synchronization with the Google Docs ecosystem.

## Goals
- **Zero-Lag Editing:** Native Swift/TextKit 2 implementation ensures immediate response.
- **Frictionless Meeting Notes:** Automatic calendar-linked note creation and templates.
- **Google Docs Synergy:** Bidirectional sync between local Markdown and shared Google Docs.
- **Offline First:** Local persistence with background sync resilience.
- **Rich Interaction:** Support for "Chips" (Contacts/Directory lookup, Status, Dropdowns).

## Architecture

### High-Level Components
1. **UI Layer (SwiftUI + TextKit 2):**
    - **Sidebar:** Hybrid organization with "Meetings" (auto-sorted by date) and "Topics" (hierarchical folders).
    - **Editor:** A custom `NSTextView` wrapper using `TextKit 2` for high-performance "Live-Preview" Markdown. Syntax symbols (#, **, etc.) are styled or hidden but remain editable.
2. **Logic Layer (Swift Actors):**
    - **Sync Coordinator:** Manages the OAuth2 flow and debounced updates to the Google Docs/Drive REST APIs.
    - **Markdown Engine:** Handles AST (Abstract Syntax Tree) generation for conversion between Markdown, Internal Data Models, and Google Docs JSON structure.
    - **Moma/Directory Service:** Integration for `@` mentions and contact chip rendering.
3. **Data Layer (SwiftData):**
    - Local storage of notes, metadata, and cached meeting data.
    - Ensures full offline functionality and fast local search (Cmd+K).

## Key Workflows

### 1. Meeting Note Creation
- **Calendar Integration:** A dedicated view shows current and upcoming meetings from `EventKit`.
- **One-Click Notes:** Clicking "Start Meeting Note" pre-fills a template with the meeting title, participants (as chips), and date.
- **Auto-Linking:** Automatically creates and links a Google Doc if one doesn't exist, or links to the existing meeting notes URL found in the calendar invite.

### 2. Live-ish Sync
- **Local Edits:** Changes in the editor are immediately saved to `SwiftData`.
- **Debounced Push:** Every ~2 seconds of inactivity, changes are converted to Google Docs API batch requests and pushed.
- **Background Pull:** The app periodically checks the Google Drive "Head" version. If external changes are detected, it performs a non-destructive merge into the local Markdown.
- **Conflict Handling:** Priority is given to local edits during active sessions; external changes are merged line-by-line where possible.

### 3. Rich Components (Chips)
- **@Mentions:** Typing `@` triggers a background lookup via Moma API. Selecting a person embeds a "Contact Chip" which renders as a rich element in both updoc and Google Docs.
- **Status Dropdowns:** Markdown syntax like `[Status: In Progress]` renders as a native dropdown menu.

## Technical Choices
- **Language:** Swift 6.0 (Concurrency-safe).
- **Frameworks:** SwiftUI, SwiftData, TextKit 2, EventKit.
- **API Client:** Objective-C REST Client Library for Google APIs (via Bridging Header) or direct Swift `URLSession` calls for modern concurrency.

## Future Considerations
- **Gemini API:** Integration for "Help me write" or "Summarize meeting" features.
- **MCP Server:** Exposing local updoc content to AI agents.
- **Sharpei Integration:** Potential subsumption of TODO management.

## Testing Strategy
- **Unit Tests:** For Markdown/AST conversion logic and Sync merging logic.
- **Integration Tests:** Mocking Google API responses for sync lifecycle validation.
- **Performance Benchmarking:** Ensuring editor latency remains <16ms (60fps).
