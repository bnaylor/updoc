# Implement Rebase/Retry Loop with Backoff Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a retry loop with exponential backoff for Google Docs updates to handle revision mismatches (conflicts) by re-fetching the document and rebasing local changes.

**Architecture:** Refactor `updateDocContent` to use a retryable `performUpdate` helper. If `performUpdate` fails with a revision mismatch (HTTP 400), the loop will fetch the latest document state, rebase the local content, and retry up to 5 times with exponential backoff.

**Tech Stack:** Swift, Foundation (async/await), Google Docs REST API.

---

### Task 1: Refactor GDocsService and Implement Helpers

**Files:**
- Modify: `src/updoc/GDocsService.swift`

- [x] **Step 1: Define performUpdate helper**
Extract the core batchUpdate logic from `updateDocContent` into a private `performUpdate` function.

- [x] **Step 2: Define basic merge/rebase helper**
Implement a simple `rebase` function that combines local changes with remote updates. Since we don't have a full 3-way merge engine, we will implement a simplified version that handles basic rebase of content.

- [x] **Step 3: Implement retry loop in updateDocContent**
Wrap the update logic in a loop with exponential backoff and error handling for revision mismatches.

### Task 2: Verification

**Files:**
- Test: `tests/updocTests/ServiceTests.swift` (or similar)

- [x] **Step 1: Verify compilation**
Run `swift build` to ensure the project still compiles.

- [x] **Step 2: (Optional) Manual verification or Mock test**
If possible, add a test case that mocks a 400 error to verify the retry logic.
