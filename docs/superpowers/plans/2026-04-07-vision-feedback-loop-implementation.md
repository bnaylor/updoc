# Vision-Based Feedback Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a fully automated UI verification loop using `screencapture`, `osascript`, and Gemini Vision.

**Architecture:** Create a shell script to automate app lifecycle and capture. Add SwiftUI debug helpers. Integrate into the development workflow.

**Tech Stack:** Bash, AppleScript (`osascript`), SwiftUI, Gemini Vision.

---

### Task 1: Setup Infrastructure

**Files:**
- Create: `scripts/ui-audit.sh`
- Create: `src/updoc/View+Debug.swift`

- [ ] **Step 1: Create the audit directory**

```bash
mkdir -p tests/ui
```

- [ ] **Step 2: Create the debug extension**

```swift
// src/updoc/View+Debug.swift
import SwiftUI

extension View {
    func debugBorder(_ color: Color = .red) -> some View {
        #if DEBUG
        self.border(color, width: 1)
        #else
        self
        #endif
    }
}
```

- [ ] **Step 3: Create the ui-audit script**

```bash
# scripts/ui-audit.sh
#!/bin/bash
set -e

APP_NAME="updoc"
OUTPUT_DIR="tests/ui"
SNAPSHOT_FILE="${OUTPUT_DIR}/latest_render.png"

echo "Building ${APP_NAME}..."
swift build

echo "Launching ${APP_NAME}..."
./.build/debug/${APP_NAME} &
APP_PID=$!

# Give it time to launch and render
sleep 3

echo "Capturing snapshot..."
# Use osascript to get the window ID of the running app
WINDOW_ID=$(osascript -e "tell application \"System Events\" to tell process \"${APP_NAME}\" to get id of window 1" 2>/dev/null || echo "")

if [ -z "$WINDOW_ID" ]; then
    echo "Error: Could not find window for ${APP_NAME}"
    kill $APP_PID
    exit 1
fi

screencapture -l$WINDOW_ID "$SNAPSHOT_FILE"

echo "Terminating ${APP_NAME}..."
kill $APP_PID

echo "Snapshot saved to ${SNAPSHOT_FILE}"
```

- [ ] **Step 4: Make script executable**

```bash
chmod +x scripts/ui-audit.sh
```

- [ ] **Step 5: Commit infrastructure**

```bash
git add scripts/ui-audit.sh src/updoc/View+Debug.swift
git commit -m "feat: setup vision-based UI audit infrastructure"
```

---

### Task 2: Verify the Loop

- [ ] **Step 1: Run the audit script**

```bash
./scripts/ui-audit.sh
```

- [ ] **Step 2: Inspect the snapshot (Gemini only)**

```bash
# I will use read_file to view tests/ui/latest_render.png
```

- [ ] **Step 3: Add a test border to a view**
Modify `src/updoc/SidebarView.swift` to add `.debugBorder()` to a major component.

- [ ] **Step 4: Re-run audit and verify border is visible**

---

### Task 3: Roadmap Integration

- [ ] **Step 1: Add "Vision Loop" to ROADMAP.md as [x]**
