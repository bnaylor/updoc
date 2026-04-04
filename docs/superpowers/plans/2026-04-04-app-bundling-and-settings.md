# App Bundling and Persistent Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform updoc into a bundled macOS app with a persistent Settings UI for API credentials.

**Architecture:** 
Introduce a `SettingsView` using `@AppStorage` for persistence. Update `Config` to prioritize these values. Create a bash script to automate the creation of the `.app` bundle structure and installation of the binary and `Info.plist`.

**Tech Stack:** Swift, SwiftUI, Bash.

---

### Task 1: Implement Persistent Settings

**Files:**
- Modify: `src/updoc/Config.swift`
- Create: `src/updoc/SettingsView.swift`
- Modify: `src/updoc/updocApp.swift`

- [ ] **Step 1: Update Config to use UserDefaults**

```swift
public enum Config {
    private static let defaults = UserDefaults.standard
    
    public static var clientID: String {
        defaults.string(forKey: "googleClientID") ?? ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"] ?? ""
    }
    // ... repeat for clientSecret and redirectURI
}
```

- [ ] **Step 2: Create SettingsView**

```swift
struct SettingsView: View {
    @AppStorage("googleClientID") private var clientID = ""
    @AppStorage("googleClientSecret") private var clientSecret = ""
    @AppStorage("googleRedirectURI") private var redirectURI = ""
    
    var body: some View {
        Form {
            Section("Google API Credentials") {
                TextField("Client ID", text: $clientID)
                TextField("Client Secret", text: $clientSecret)
                TextField("Redirect URI", text: $redirectURI)
            }
        }
        .padding(20)
        .frame(width: 450)
    }
}
```

- [ ] **Step 3: Add Settings scene to updocApp**

```swift
    var body: some Scene {
        WindowGroup { ... }
        Settings {
            SettingsView()
        }
    }
```

- [ ] **Step 4: Commit**

```bash
git add src/updoc/Config.swift src/updoc/SettingsView.swift src/updoc/updocApp.swift
git commit -m "feat: implement persistent Settings UI for API credentials"
```

### Task 2: Create App Bundling Script

**Files:**
- Create: `scripts/bundle.sh`
- Modify: `src/updoc/Info.plist` (ensure basics like BundleName and Identifier are correct)

- [ ] **Step 1: Write bundle.sh**

```bash
#!/bin/bash
set -e

APP_NAME="updoc"
BUNDLE_ID="com.example.updoc"
BUILD_DIR=".build/apple/Products/Release"

# Build
swift build -c release --arch arm64 --arch x86_64

# Create structure
mkdir -p "${APP_NAME}.app/Contents/MacOS"
mkdir -p "${APP_NAME}.app/Contents/Resources"

# Copy binary
cp ".build/apple/Products/Release/${APP_NAME}" "${APP_NAME}.app/Contents/MacOS/"

# Copy Info.plist (ensure it's updated with actual values)
cp src/updoc/Info.plist "${APP_NAME}.app/Contents/Info.plist"

echo "Bundle created: ${APP_NAME}.app"
```

- [ ] **Step 2: Update Info.plist with standard keys**

- [ ] **Step 3: Commit**

```bash
git add scripts/bundle.sh src/updoc/Info.plist
git commit -m "feat: add app bundling script"
```

### Task 3: Setup Wizard & Verification

**Files:**
- Modify: `src/updoc/ContentView.swift`

- [ ] **Step 1: Check for missing credentials on launch**

In `onAppear`, if config is missing, trigger a sheet showing the `SettingsView`.

- [ ] **Step 2: Verify the bundle**
  - Run `./scripts/bundle.sh`
  - Open `updoc.app`
  - Verify menu bar ownership
  - Verify keyboard focus in editor
  - Enter credentials in Settings and verify they persist

- [ ] **Step 3: Commit**

```bash
git add src/updoc/ContentView.swift
git commit -m "feat: add setup wizard for missing credentials"
```
