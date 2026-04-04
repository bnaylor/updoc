# Google API Auth Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add GTMAppAuth dependency and environment-based configuration to enable Google API authentication.

**Architecture:** Use Swift Package Manager for dependency management and a static `Config` enum to load Google API credentials from environment variables.

**Tech Stack:** Swift, Swift Package Manager, GTMAppAuth.

---

### Task 1: Add GTMAppAuth Dependency

**Files:**
- Modify: `Package.swift`

- [ ] **Step 1: Update dependencies in Package.swift**

```swift
    dependencies: [
        .package(url: "https://github.com/google/GTMAppAuth", from: "4.1.1")
    ],
```

- [ ] **Step 2: Add GTMAppAuth product to target dependencies**

```swift
        .executableTarget(
            name: "updoc",
            dependencies: [
                .product(name: "GTMAppAuth", package: "GTMAppAuth")
            ],
            path: "src/updoc"
        ),
```

- [ ] **Step 3: Run swift build to verify dependency resolution**

Run: `swift build`
Expected: Resolution and compilation pass.

- [ ] **Step 4: Commit**

```bash
git add Package.swift
git commit -m "feat: add GTMAppAuth dependency"
```

### Task 2: Create Config.swift

**Files:**
- Create: `src/updoc/Config.swift`

- [ ] **Step 1: Create Config.swift with environment variable loading**

```swift
import Foundation

public enum Config {
    public static let clientID = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"] ?? ""
    public static let clientSecret = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_SECRET"] ?? ""
    public static let redirectURI = ProcessInfo.processInfo.environment["GOOGLE_REDIRECT_URI"] ?? ""
}
```

- [ ] **Step 2: Run swift build to verify compilation**

Run: `swift build`
Expected: Compilation passes.

- [ ] **Step 3: Commit**

```bash
git add src/updoc/Config.swift
git commit -m "feat: add environment-based Google API configuration"
```
