# Design: Fully Agentic Vision-Based Feedback Loop

This document outlines the implementation of an autonomous UI verification loop using native macOS tools and Gemini Vision.

## Objective
To enable Gemini to automatically verify and iterate on the `updoc` UI by capturing screenshots of the running application and analyzing them using vision capabilities.

## Components

### 1. Audit Script (`scripts/ui-audit.sh`)
A shell script that automates the "Build -> Launch -> Snap -> Kill" lifecycle.
- **Build**: Runs `swift build`.
- **Launch**: Runs the `updoc` binary in the background.
- **Snap**: Uses `osascript` to find the window ID and `screencapture -l` to take a window-specific screenshot.
- **Kill**: Terminates the `updoc` process.
- **Output**: Saves the snapshot to `tests/ui/latest_render.png`.

### 2. Debug Modifiers (`src/updoc/View+Debug.swift`)
A SwiftUI extension providing `.debugBorder()` to help identify layout boundaries during the audit.

### 3. Verification Workflow
1.  Gemini applies a UI change.
2.  Gemini executes `./scripts/ui-audit.sh`.
3.  Gemini reads `tests/ui/latest_render.png` using the `read_file` tool.
4.  Gemini analyzes the image against the intended design and previous renders.
5.  Gemini applies fixes if violations are detected.

## Success Criteria
- The loop completes in under 15 seconds.
- Gemini can successfully identify overlapping elements, incorrect padding, or missing components from the screenshot.
- UI iterations become more accurate without requiring manual user descriptions.
