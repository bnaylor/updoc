# Design Spec: Google API Integration (Real)

**Date:** 2026-04-03
**Status:** Draft (Design Approved)
**Topic:** Replacing mock Google Services with real GTMAppAuth and REST API calls.

---

## 1. Goals
- Implement real OAuth2 authentication flow for macOS using GTMAppAuth.
- Replace mock `GDocsService`, `GDriveService`, and `GCalendarService` with real Google REST API implementations.
- Maintain existing `SyncCoordinator` logic while ensuring it works with real data and handles network/auth errors.
- Use a local `.env` file (git-ignored) for Client ID and Secret storage during development.

---

## 2. Architecture

### A. Authentication Layer (`AuthManager`)
- **Library:** `GTMAppAuth` (SPM dependency).
- **Mechanism:** `ASWebAuthenticationSession` for the system browser flow.
- **Storage:** Securely persist `OIDAuthState` to the macOS Keychain.
- **Responsibility:** Provide valid access tokens (with auto-refresh) to service classes.

### B. Service Layer (REST)
- **Pattern:** Native `URLSession` + `Codable` + `Async/Await`.
- **GDocsService:**
  - `fetchDocContent(docId:)`: GET `/v1/documents/{docId}`.
  - `updateDocContent(docId:content:)`: POST `/v1/documents/{docId}:batchUpdate`.
- **GDriveService:**
  - `getFileRevision(fileId:)`: GET `/v3/files/{fileId}?fields=headRevisionId`.
- **GCalendarService:**
  - `fetchTodaysEvents()`: GET `/v3/calendars/primary/events`.

### C. Logic Layer (`SyncCoordinator`)
- Orchestrates the 3-way sync (local vs remote vs base).
- Handles API errors (retries, auth prompts).

---

## 3. Data Models (Codable)
- Define lightweight `GDocsResponse`, `GDriveResponse`, `GCalendarResponse` structs to map API JSON to our domain models (`Note`, `CalendarEvent`).

---

## 4. Dependencies (SPM)
- `GTMAppAuth` (https://github.com/google/GTMAppAuth)
- `AppAuth` (dependency of GTMAppAuth)

---

## 5. Security & Error Handling
- **Secrets:** Client ID and Secret read from `.env` file or environment variables.
- **Tokens:** Access tokens are never logged; OIDAuthState is stored in Keychain.
- **Errors:**
  - 401 Unauthorized: Trigger token refresh or re-auth flow.
  - Network errors: Exponential backoff for retries in `SyncCoordinator`.
  - Conflicts: Maintain "Safe Merge" logic (appending remote changes if diverged).

---

## 6. Implementation Plan (High Level)
1. Add SPM dependencies.
2. Implement `.env` loader.
3. Rewrite `AuthManager` with `GTMAppAuth`.
4. Implement REST models and Service classes.
5. Update `SyncCoordinator` to handle real async calls and errors.
6. Verify with integration tests (using test account).
