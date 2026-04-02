# Design Doc: updoc App Polish & UI/UX Refinement

**Date:** 2026-04-02  
**Status:** Draft  
**Topic:** Theming Engine, Typography, and Command Palette (Cmd+K)

## Overview
This document outlines the visual and interaction refinements for **updoc**. It focuses on creating a "pleasant and frictionless" experience through curated typography themes and a powerful Command Palette for keyboard-driven navigation.

## Goals
- **Pleasant Aesthetics:** Curated typography and color themes (Modern, Serif, Mono).
- **Frictionless Navigation:** A central Command Palette (Cmd+K) for searching notes and executing actions.
- **Native Integration:** Mirroring all commands in the standard macOS Menu Bar.
- **Power User Speed:** Displaying keyboard shortcuts within the palette for easy learning.

## Architecture

### 1. ThemeManager
- **State:** Tracks the current `Theme` and `ColorMode` (Light/Dark).
- **Theme Definitions:**
    - **Modern:** SF Pro, tight margins, high readability.
    - **Serif:** New York, wider margins, "notebook" feel.
    - **Mono:** SF Mono, technical, precise spacing.
- **Dynamic Styling:** Injects theme-specific fonts and colors into the `EditorView` and `SidebarView`.

### 2. Command Engine (Cmd+K)
- **UI:** A modal overlay at the top of the main window.
- **Data Source:**
    - **Notes:** All local notes for "Quick Open" functionality.
    - **Commands:** A registry of app actions (New Note, Sync, Settings, Switch Theme).
- **Matching:** Fuzzy search for notes and command titles.

## Key Workflows

### 1. Switching Themes
- Triggered via Command Palette ("Switch to Serif") or Menu Bar (View > Theme).
- Instantly updates the typography and color scheme of the entire app.

### 2. Command Palette Navigation
- `Cmd+K` → Type "sync" → `Enter` (Triggers `SyncCoordinator.sync()`).
- `Cmd+K` → Type "ref" → Select "Serif Theme Design" → `Enter` (Jumps to that note).

### 3. Native Menu Bar Mirroring
- **File:** New Note (Cmd+N), Link Doc.
- **Edit:** Sync Now (Cmd+S), Delete Note.
- **View:** Theme selection, Toggle Sidebar (Cmd+Option+S).

## Technical Choices
- **UI:** SwiftUI for the Command Palette UI; TextKit 2 for dynamic font application in the editor.
- **Persistence:** Current theme choice stored in `UserDefaults` or `SwiftData`.
- **Keyboard Handling:** Using `commandShortcut` modifiers and specialized key event monitors for Cmd+K.

## Future Considerations
- **User-Defined Themes:** Allowing users to import their own CSS-like theme definitions.
- **Customizable Shortcuts:** A UI for remapping the default keyboard shortcuts.
- **Deep Command History:** Remembering frequently used commands for faster access.
