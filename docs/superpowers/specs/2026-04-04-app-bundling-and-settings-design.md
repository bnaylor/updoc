# App Bundling and Persistent Settings Design

**Goal:** Transform updoc into a proper macOS application bundle and provide a persistent settings UI for Google API configuration.

## Overview
Currently, updoc runs as a raw binary via `swift run`. This causes issues with system-level integrations like menu bar ownership, keyboard focus, and environment variable management. This design introduces a standard `.app` bundle structure and an in-app Settings UI to handle configuration.

## Architecture & Implementation

### 1. Persistent Settings
- **SettingsView:** A standard SwiftUI `Settings` scene in `updocApp.swift`.
- **Fields:** `googleClientID`, `googleClientSecret`, `googleRedirectURI`.
- **Persistence:** Use `@AppStorage` (UserDefaults) for initial implementation.
- **Config Update:** Update `Config.swift` to use `UserDefaults` values as the primary source, falling back to environment variables.

### 2. App Bundling
- **Structure:**
  ```
  updoc.app/
    Contents/
      Info.plist
      MacOS/
        updoc (executable)
      Resources/
        AppIcon.icns (placeholder)
  ```
- **Script:** A `scripts/bundle.sh` to automate the build and assembly process for local development.

### 3. System Integration (Hypothesized Fixes)
- **Menu Bar:** Proper bundling ensures the system recognizes updoc as the foreground app, allowing it to own the menu bar and respond to shortcuts (Cmd+C, Cmd+V, etc.).
- **Focus:** Resolves issues where keyboard focus falls through to the launching terminal by establishing a proper application context.

## UI/UX
- **Settings Menu:** Accessible via `updoc > Settings...` (Cmd+,).
- **Setup Wizard:** If API credentials are missing on launch, the app will automatically present the Settings view.

## Success Criteria
- [ ] `scripts/bundle.sh` successfully creates a runnable `updoc.app`.
- [ ] Google API credentials persist across app restarts without environment variables.
- [ ] App correctly owns the macOS menu bar and responds to standard shortcuts.
- [ ] Keyboard input remains captured by the app and does not leak to the terminal.
