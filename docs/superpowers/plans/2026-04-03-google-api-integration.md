# Google API Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace mock Google services with real GTMAppAuth (OAuth2) and native REST API calls for Calendar, Docs, and Drive.

**Architecture:** `AuthManager` handles OAuth2 via `GTMAppAuth` and `ASWebAuthenticationSession`. Services (`GDocsService`, `GDriveService`, `GCalendarService`) use native `URLSession` + `Codable` with tokens from `AuthManager`. `SyncCoordinator` orchestrates the flow.

**Tech Stack:** Swift 6.0, GTMAppAuth, URLSession, SwiftData.

---

### Task 1: Add Dependencies & Setup Environment

**Files:**
- Modify: `Package.swift`
- Create: `.env` (template)
- Create: `src/updoc/Config.swift`

- [ ] **Step 1: Update Package.swift with GTMAppAuth**

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/google/GTMAppAuth", from: "4.1.1")
],
targets: [
    .executableTarget(
        name: "updoc",
        dependencies: [
            .product(name: "GTMAppAuth", package: "GTMAppAuth")
        ],
        path: "src/updoc"
    ),
    // ...
]
```

- [ ] **Step 2: Create Config.swift to load .env**

```swift
import Foundation

public enum Config {
    public static let clientID = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"] ?? ""
    public static let clientSecret = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_SECRET"] ?? ""
    public static let redirectURI = ProcessInfo.processInfo.environment["GOOGLE_REDIRECT_URI"] ?? ""
}
```

- [ ] **Step 3: Commit**

```bash
git add Package.swift src/updoc/Config.swift
git commit -m "chore: add GTMAppAuth dependency and Config loader"
```

---

### Task 2: Implement Real AuthManager

**Files:**
- Modify: `src/updoc/AuthManager.swift`
- Test: `tests/updocTests/AuthManagerTests.swift`

- [ ] **Step 1: Rewrite AuthManager using GTMAppAuth**

```swift
import Foundation
import GTMAppAuth
import AppAuth
import AuthenticationServices

public actor AuthManager {
    public static let shared = AuthManager()
    private var authState: OIDAuthState?
    private let keychainKey = "updoc.authState"

    public func authorize(in window: NSWindow) async throws {
        let configuration = GTMAppAuthFetcherAuthorization.configurationForGoogle()
        let request = OIDAuthorizationRequest(
            configuration: configuration,
            clientId: Config.clientID,
            clientSecret: Config.clientSecret,
            scopes: [OIDServiceDocs, OIDServiceDrive, "https://www.googleapis.com/auth/calendar.events.readonly"],
            redirectURL: URL(string: Config.redirectURI)!,
            responseType: OIDResponseTypeCode,
            additionalParameters: nil
        )

        // Implement ASWebAuthenticationSession flow here
        // ... (full implementation in Task 2.1)
    }

    public func getAccessToken() async throws -> String {
        // Use authState.performAction to get fresh token
        return "real-token"
    }
}
```

- [ ] **Step 2: Implement Keychain persistence for OIDAuthState**

- [ ] **Step 3: Commit**

```bash
git add src/updoc/AuthManager.swift
git commit -m "feat: implement real AuthManager with GTMAppAuth"
```

---

### Task 3: Implement GDocsService (REST)

**Files:**
- Modify: `src/updoc/GDocsService.swift`
- Create: `src/updoc/GDocsModels.swift`

- [ ] **Step 1: Define Codable models for GDocs API**

```swift
struct GDocsDocument: Codable {
    let documentId: String
    let title: String
    let body: GDocsBody
}
// ...
```

- [ ] **Step 2: Update GDocsService to use URLSession**

```swift
public struct GDocsService {
    public func fetchDocContent(docId: String) async throws -> String {
        let token = try await AuthManager.shared.getAccessToken()
        let url = URL(string: "https://docs.googleapis.com/v1/documents/\(docId)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let doc = try JSONDecoder().decode(GDocsDocument.self, from: data)
        return convertToMarkdown(doc)
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add src/updoc/GDocsService.swift src/updoc/GDocsModels.swift
git commit -m "feat: implement real GDocsService REST calls"
```

---

### Task 4: Implement GDriveService & GCalendarService

**Files:**
- Modify: `src/updoc/GDriveService.swift`
- Modify: `src/updoc/GCalendarService.swift`

- [ ] **Step 1: Implement GDrive revision check**

- [ ] **Step 2: Implement GCalendar event fetching**

- [ ] **Step 3: Commit**

```bash
git add src/updoc/GDriveService.swift src/updoc/GCalendarService.swift
git commit -m "feat: implement real GDrive and GCalendar REST calls"
```

---

### Task 5: Update SyncCoordinator & UI

**Files:**
- Modify: `src/updoc/SyncCoordinator.swift`
- Modify: `src/updoc/ContentView.swift`

- [ ] **Step 1: Handle auth errors in SyncCoordinator**

- [ ] **Step 2: Add Login button if not authenticated**

- [ ] **Step 3: Commit**

```bash
git add src/updoc/SyncCoordinator.swift src/updoc/ContentView.swift
git commit -m "feat: handle real sync errors and auth UI"
```
