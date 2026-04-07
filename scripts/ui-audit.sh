#!/bin/bash
set -e

APP_NAME="updoc"
OUTPUT_DIR="tests/ui"
SNAPSHOT_FILE="${OUTPUT_DIR}/latest_render.png"

mkdir -p "${OUTPUT_DIR}"

# 1. Ensure the app is bundled
echo "Bundling ${APP_NAME}..."
./scripts/bundle.sh > /dev/null

# 2. Launch the .app bundle
echo "Launching ${APP_NAME}.app..."
open "${APP_NAME}.app"

# 3. Give plenty of time for rendering and keychain
echo "Waiting for app to render (30s)..."
echo "PLEASE CLEAR ANY KEYCHAIN PROMPTS NOW."
sleep 30

# 4. Bring app to front
echo "Bringing ${APP_NAME} to front..."
osascript -e "tell application \"${APP_NAME}\" to activate" 2>/dev/null || true
sleep 2

# 5. Capture snapshot
echo "Capturing snapshot..."
# More aggressive window finding logic
WINDOW_ID=$(osascript -e "
    tell application \"System Events\"
        set allProcs to every process whose background only is false
        repeat with proc in allProcs
            if name of proc contains \"${APP_NAME}\" or name of proc contains \"updoc\" then
                try
                    -- Try to get the window ID
                    set winID to id of window 1 of proc
                    return winID
                end try
            end if
        end repeat
    end tell
    return \"\"
" 2>/dev/null || echo "")

if [ -n "$WINDOW_ID" ] && [ "$WINDOW_ID" != "\"\"" ]; then
    echo "Found Window ID: ${WINDOW_ID}. Capturing window..."
    screencapture -l$WINDOW_ID "$SNAPSHOT_FILE"
else
    echo "Warning: Could not find specific window ID. Attempting multi-display capture..."
    # Capture each display individually since we have 3 screens
    # We'll use a unique suffix for each
    screencapture -D 1 "${OUTPUT_DIR}/main_screen.png" 2>/dev/null || true
    screencapture -D 2 "${OUTPUT_DIR}/screen_2.png" 2>/dev/null || true
    screencapture -D 3 "${OUTPUT_DIR}/screen_3.png" 2>/dev/null || true
    
    # Also capture full screen (merged) as fallback
    screencapture "$SNAPSHOT_FILE"
fi

# 6. Terminate
echo "Terminating ${APP_NAME}..."
osascript -e "tell application \"${APP_NAME}\" to quit" 2>/dev/null || killall "${APP_NAME}" 2>/dev/null || true

echo "Snapshot(s) saved to ${OUTPUT_DIR}"
