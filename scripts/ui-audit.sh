#!/bin/bash
set -e

APP_NAME="updoc"
OUTPUT_DIR="tests/ui"
SNAPSHOT_FILE="${OUTPUT_DIR}/latest_render.png"

mkdir -p "${OUTPUT_DIR}"

# 1. Ensure the app is bundled
echo "Bundling ${APP_NAME}..."
./scripts/bundle.sh > /dev/null

# 2. Kill any existing instance to ensure clean start
echo "Ensuring ${APP_NAME} is not already running..."
killall "${APP_NAME}" 2>/dev/null || true
sleep 1

# 3. Launch the .app bundle
echo "Launching ${APP_NAME}.app..."
# We use || true because open sometimes returns -609 (Connection is invalid) 
# even if the app launches correctly after a bundle update.
open "${APP_NAME}.app" || true

# 4. Give plenty of time for rendering and keychain
echo "Waiting for app to render (30s)..."
echo "PLEASE CLEAR ANY KEYCHAIN PROMPTS NOW."
sleep 30

# 5. Capture snapshot using getwindowid
echo "Capturing snapshot..."
# getwindowid <process_name> <window_title>
# Here we assume both are "updoc" as per user suggestion
WINDOW_ID=$(getwindowid "${APP_NAME}" "${APP_NAME}" 2>/dev/null || echo "")

if [ -n "$WINDOW_ID" ]; then
    echo "Found Window ID: ${WINDOW_ID}. Capturing window..."
    screencapture -l$WINDOW_ID "$SNAPSHOT_FILE"
else
    echo "Warning: Could not find specific window ID for ${APP_NAME}. Attempting fallback capture..."
    screencapture "$SNAPSHOT_FILE"
fi

# 6. Terminate
echo "Terminating ${APP_NAME}..."
killall "${APP_NAME}" 2>/dev/null || true

echo "Snapshot(s) saved to ${OUTPUT_DIR}"
