# CodeMirror 6 Editor Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `EditorView.swift` (TextKit 2 / NSTextView) and `MarkdownEngine.swift` (regex parser) with a CodeMirror 6 editor hosted in a WKWebView, preserving all existing markdown features, themes, search navigation, and checklist behaviour.

**Architecture:** A TypeScript/CM6 bundle is compiled by `esbuild` and served from the app bundle via a custom `editor://` URL scheme. `CodeMirrorEditorView.swift` (an `NSViewRepresentable` wrapping `WKWebView`) replaces `EditorView.swift`. A Swift ↔ JS bridge handles content, theme, scroll, and read-only state. A feature flag (`@AppStorage("useCodeMirrorEditor")`) lets both editors run side-by-side during development.

**Tech Stack:** TypeScript, CodeMirror 6 (`@codemirror/view`, `@codemirror/state`, `@codemirror/lang-markdown`, `@codemirror/commands`, `@codemirror/language`, `@lezer/markdown`), esbuild, Swift 6, WKWebView, SwiftData.

---

## File Map

### New files
| Path | Purpose |
|---|---|
| `editor/package.json` | Node.js manifest for CM6 dependencies |
| `editor/tsconfig.json` | TypeScript compiler config |
| `editor/src/editor.ts` | Main CM6 entry point + public `window.updoc` API |
| `editor/src/updocDecorations.ts` | Custom decorations: underline, highlight, syntax hiding, checkbox widgets |
| `scripts/build_editor.sh` | Runs esbuild to produce `editor.js` |
| `src/updoc/Resources/editor/editor.html` | Host HTML page loaded by WKWebView |
| `src/updoc/EditorSchemeHandler.swift` | `WKURLSchemeHandler` serving `editor://` requests from app bundle |
| `src/updoc/CodeMirrorEditorView.swift` | `NSViewRepresentable` wrapping WKWebView |
| `src/updoc/AppMigrationManager.swift` | One-time checklist syntax migration `[ ] → - [ ]` |
| `tests/updocTests/AppMigrationManagerTests.swift` | Unit tests for content migration |
| `tests/updocTests/ThemeCSSTests.swift` | Unit tests for `CustomTheme.cssVariables()` |

### Modified files
| Path | Change |
|---|---|
| `src/updoc/ThemeManager.swift` | Add `cssVariables() -> [String: String]` to `CustomTheme` |
| `src/updoc/NoteDetailView.swift` | Feature flag: use `CodeMirrorEditorView` when flag on |
| `src/updoc/SettingsView.swift` | Add Developer tab with `useCodeMirrorEditor` toggle |
| `src/updoc/WeeklyLogDashboardView.swift` | Same feature flag as NoteDetailView |
| `src/updoc/updocApp.swift` | Call `AppMigrationManager.runIfNeeded(context:)` on launch |

### Deleted at end (Task 14)
- `src/updoc/EditorView.swift`
- `src/updoc/MarkdownEngine.swift`
- `src/updoc/EditorLayoutManager.swift`

---

## Task 1: JavaScript package setup

**Files:**
- Create: `editor/package.json`
- Create: `editor/tsconfig.json`
- Create: `editor/src/editor.ts` (placeholder)
- Create: `scripts/build_editor.sh`

- [ ] **Step 1: Create the Node.js package manifest**

Create `editor/package.json`:
```json
{
  "name": "updoc-editor",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "build": "esbuild src/editor.ts --bundle --outfile=../src/updoc/Resources/editor/editor.js --platform=browser --target=safari16 --minify"
  },
  "dependencies": {
    "@codemirror/commands": "^6.7.0",
    "@codemirror/lang-markdown": "^6.3.1",
    "@codemirror/language": "^6.10.2",
    "@codemirror/state": "^6.4.1",
    "@codemirror/view": "^6.34.3",
    "@lezer/highlight": "^1.2.1",
    "@lezer/markdown": "^1.3.1"
  },
  "devDependencies": {
    "esbuild": "^0.24.0",
    "typescript": "^5.5.0"
  }
}
```

- [ ] **Step 2: Create TypeScript config**

Create `editor/tsconfig.json`:
```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "lib": ["ES2020", "DOM"]
  },
  "include": ["src/**/*.ts"]
}
```

- [ ] **Step 3: Create placeholder entry point**

Create `editor/src/editor.ts`:
```typescript
// Placeholder — filled in Task 3
console.log("updoc editor loaded")
```

- [ ] **Step 4: Create build script**

Create `scripts/build_editor.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
EDITOR_DIR="$REPO_ROOT/editor"
OUTPUT_DIR="$REPO_ROOT/src/updoc/Resources/editor"

mkdir -p "$OUTPUT_DIR"
cd "$EDITOR_DIR"

if ! command -v node &>/dev/null; then
  echo "warning: node not found, skipping editor bundle build"
  exit 0
fi

npm install --silent
npm run build
echo "editor.js built successfully → $OUTPUT_DIR/editor.js"
```

- [ ] **Step 5: Make script executable and install dependencies**

```bash
chmod +x scripts/build_editor.sh
mkdir -p src/updoc/Resources/editor
cd editor && npm install && cd ..
```

- [ ] **Step 6: Run build to verify it produces editor.js**

```bash
./scripts/build_editor.sh
```

Expected: `editor.js built successfully → src/updoc/Resources/editor/editor.js`

- [ ] **Step 7: Add node_modules to .gitignore**

```bash
echo "editor/node_modules/" >> .gitignore
```

- [ ] **Step 8: Commit**

```bash
git add editor/package.json editor/package-lock.json editor/tsconfig.json editor/src/editor.ts scripts/build_editor.sh src/updoc/Resources/editor/editor.js .gitignore
git commit -m "feat: add CM6 editor JS project scaffold and build script"
```

---

## Task 2: HTML host page and URL scheme handler

**Files:**
- Create: `src/updoc/Resources/editor/editor.html`
- Create: `src/updoc/EditorSchemeHandler.swift`

- [ ] **Step 1: Create editor.html**

Create `src/updoc/Resources/editor/editor.html`:
```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    html, body { height: 100%; overflow: hidden; background: var(--updoc-bg, white); }
    #editor { height: 100%; }
    .cm-editor { height: 100%; }
    .cm-scroller { overflow: auto; height: 100%; }
  </style>
</head>
<body>
  <div id="editor"></div>
  <script src="editor.js"></script>
</body>
</html>
```

- [ ] **Step 2: Create EditorSchemeHandler.swift**

Create `src/updoc/EditorSchemeHandler.swift`:
```swift
import WebKit

/// Serves files from the app bundle's Resources/editor/ directory
/// in response to editor:// URL requests from WKWebView.
final class EditorSchemeHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url else {
            task.didFailWithError(URLError(.badURL))
            return
        }

        let fileName = url.lastPathComponent
        let nameWithoutExt = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension

        guard let resourceURL = Bundle.main.url(
            forResource: nameWithoutExt,
            withExtension: ext,
            subdirectory: "editor"
        ) else {
            task.didFailWithError(URLError(.fileDoesNotExist))
            return
        }

        do {
            let data = try Data(contentsOf: resourceURL)
            let mimeType: String
            switch ext {
            case "js":  mimeType = "application/javascript"
            case "css": mimeType = "text/css"
            default:    mimeType = "text/html"
            }
            let response = URLResponse(
                url: url,
                mimeType: mimeType,
                expectedContentLength: data.count,
                textEncodingName: "utf-8"
            )
            task.didReceive(response)
            task.didReceive(data)
            task.didFinish()
        } catch {
            task.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}
```

- [ ] **Step 3: Add editor.html to Xcode target**

In Xcode: select `editor.html` in the project navigator → check the app target in the File Inspector → confirm it appears in Build Phases → Copy Bundle Resources alongside `editor.js`. Do the same for `editor.js` if it was not auto-added.

- [ ] **Step 4: Commit**

```bash
git add src/updoc/Resources/editor/editor.html src/updoc/EditorSchemeHandler.swift
git commit -m "feat: add editor host HTML and WKURLSchemeHandler for editor:// scheme"
```

---

## Task 3: Basic CM6 editor with Swift bridge (content in/out)

**Files:**
- Modify: `editor/src/editor.ts` (full implementation)
- Create: `src/updoc/CodeMirrorEditorView.swift`

- [ ] **Step 1: Implement the TypeScript editor entry point**

Replace `editor/src/editor.ts` with:
```typescript
import { EditorView, keymap } from "@codemirror/view"
import { EditorState, Compartment } from "@codemirror/state"
import { defaultKeymap, history, historyKeymap, indentWithTab } from "@codemirror/commands"
import { markdown, markdownLanguage } from "@codemirror/lang-markdown"
import { GFM } from "@lezer/markdown"
import { syntaxHighlighting, defaultHighlightStyle } from "@codemirror/language"

// Compartment for toggling read-only state after editor creation
const readOnlyCompartment = new Compartment()

// ─── Bridge helpers ────────────────────────────────────────────────────────────

declare global {
  interface Window {
    webkit?: { messageHandlers: Record<string, { postMessage(data: unknown): void }> }
    updoc: UpdocAPI
  }
}

interface UpdocAPI {
  loadContent(text: string): void
  setTheme(vars: Record<string, string>): void
  scrollToRange(from: number, to: number): void
  setReadOnly(readOnly: boolean): void
}

function postMessage(name: string, payload: Record<string, unknown>): void {
  window.webkit?.messageHandlers[name]?.postMessage(payload)
}

let debounceTimer: ReturnType<typeof setTimeout> | null = null

function notifyContentChanged(view: EditorView): void {
  if (debounceTimer) clearTimeout(debounceTimer)
  debounceTimer = setTimeout(() => {
    postMessage("contentChanged", { text: view.state.doc.toString() })
  }, 300)
}

// ─── Editor instance ───────────────────────────────────────────────────────────

let editor: EditorView | null = null

function createEditor(): void {
  editor = new EditorView({
    state: EditorState.create({
      doc: "",
      extensions: [
        history(),
        keymap.of([...defaultKeymap, ...historyKeymap, indentWithTab]),
        markdown({ base: markdownLanguage, extensions: [GFM] }),
        syntaxHighlighting(defaultHighlightStyle),
        EditorView.lineWrapping,
        readOnlyCompartment.of(EditorState.readOnly.of(false)),
        EditorView.updateListener.of((update) => {
          if (update.docChanged) notifyContentChanged(update.view)
        }),
        EditorView.theme({
          "&": {
            height: "100%",
            fontSize: "var(--updoc-font-size, 16px)",
            fontFamily: "var(--updoc-font-family, -apple-system, sans-serif)",
          },
          ".cm-scroller": { overflow: "auto" },
          ".cm-content": { padding: "16px 20px", caretColor: "var(--updoc-text, currentColor)" },
          ".cm-focused": { outline: "none" },
        }),
      ],
    }),
    parent: document.getElementById("editor")!,
  })

  // Notify Swift the editor is ready
  postMessage("contentChanged", { text: "" })
}

// ─── Public API (called from Swift via evaluateJavaScript) ────────────────────

window.updoc = {
  loadContent(text: string): void {
    if (!editor) return
    editor.dispatch({
      changes: { from: 0, to: editor.state.doc.length, insert: text },
    })
  },

  setTheme(vars: Record<string, string>): void {
    const root = document.documentElement
    for (const [key, value] of Object.entries(vars)) {
      root.style.setProperty(key, value)
    }
    if (vars["--updoc-bg"]) document.body.style.backgroundColor = vars["--updoc-bg"]
  },

  scrollToRange(from: number, to: number): void {
    if (!editor) return
    editor.dispatch({
      selection: { anchor: from, head: to },
      effects: EditorView.scrollIntoView(from, { y: "center" }),
    })
  },

  setReadOnly(readOnly: boolean): void {
    if (!editor) return
    editor.dispatch({
      effects: readOnlyCompartment.reconfigure(EditorState.readOnly.of(readOnly)),
    })
  },
}

document.addEventListener("DOMContentLoaded", createEditor)
```

- [ ] **Step 2: Build the bundle**

```bash
./scripts/build_editor.sh
```

Expected: `editor.js built successfully`

- [ ] **Step 3: Create CodeMirrorEditorView.swift**

Create `src/updoc/CodeMirrorEditorView.swift`:
```swift
import SwiftUI
import WebKit
import AppKit

struct CodeMirrorEditorView: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectionRange: NSRange?
    var theme: String
    var isReadOnly: Bool

    @AppStorage("spellcheckEnabled") private var spellcheckEnabled: Bool = true
    @AppStorage("autocorrectEnabled") private var autocorrectEnabled: Bool = true
    @Environment(ThemeManager.self) private var themeManager

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(EditorSchemeHandler(), forURLScheme: "editor")
        config.preferences.isGrammarCheckingEnabled = spellcheckEnabled

        let controller = config.userContentController
        controller.add(context.coordinator, name: "contentChanged")
        controller.add(context.coordinator, name: "checkboxToggled")
        controller.add(context.coordinator, name: "linkClicked")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        context.coordinator.parent = self

        webView.load(URLRequest(url: URL(string: "editor://host/editor.html")!))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self

        // Push content if it changed externally (sync, template apply, etc.)
        if coordinator.lastKnownText != text {
            coordinator.loadContent(text)
        }

        // Handle search result navigation
        if let range = selectionRange {
            coordinator.scrollToRange(from: range.location, to: range.location + range.length)
            DispatchQueue.main.async { self.selectionRange = nil }
        }
    }

    // MARK: – Coordinator

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: CodeMirrorEditorView
        weak var webView: WKWebView?

        /// The last text value we sent to the editor (or received from it).
        /// Used to suppress round-trip echoes in updateNSView.
        var lastKnownText: String = ""

        private var isEditorReady = false
        private var pendingContent: String?

        init(_ parent: CodeMirrorEditorView) {
            self.parent = parent
        }

        deinit {
            webView?.configuration.userContentController.removeAllScriptMessageHandlers()
        }

        // MARK: WKNavigationDelegate

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isEditorReady = true
            applyTheme()
            setReadOnly(parent.isReadOnly)
            if let pending = pendingContent {
                loadContent(pending)
                pendingContent = nil
            } else {
                loadContent(parent.text)
            }
        }

        // MARK: WKScriptMessageHandler

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard let body = message.body as? [String: Any] else { return }
            switch message.name {
            case "contentChanged":
                if let text = body["text"] as? String {
                    lastKnownText = text
                    parent.text = text
                }
            case "checkboxToggled":
                // CM6 widget already updated its own state; the subsequent
                // contentChanged message delivers the updated text.
                break
            case "linkClicked":
                if let urlString = body["url"] as? String,
                   let url = URL(string: urlString) {
                    NSWorkspace.shared.open(url)
                }
            default:
                break
            }
        }

        // MARK: Bridge helpers

        func loadContent(_ text: String) {
            guard isEditorReady, let webView else {
                pendingContent = text
                return
            }
            lastKnownText = text
            let escaped = text
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
            webView.evaluateJavaScript("window.updoc.loadContent(`\(escaped)`)")
        }

        func scrollToRange(from: Int, to: Int) {
            guard isEditorReady, let webView else { return }
            webView.evaluateJavaScript("window.updoc.scrollToRange(\(from), \(to))")
        }

        func setReadOnly(_ readOnly: Bool) {
            guard isEditorReady, let webView else { return }
            webView.evaluateJavaScript("window.updoc.setReadOnly(\(readOnly))")
        }

        func applyTheme() {
            guard isEditorReady, let webView else { return }
            guard let theme = ThemeManager.shared.getTheme(named: parent.theme) else { return }
            let vars = theme.cssVariables()
            guard let data = try? JSONSerialization.data(withJSONObject: vars),
                  let json = String(data: data, encoding: .utf8) else { return }
            webView.evaluateJavaScript("window.updoc.setTheme(\(json))")
        }
    }
}
```

- [ ] **Step 4: Add `evaluateJavaScript` convenience overload to silence warnings**

AppKit's `evaluateJavaScript` has a required completion handler. Add a fire-and-forget helper at the bottom of `CodeMirrorEditorView.swift`:
```swift
private extension WKWebView {
    @discardableResult
    func evaluateJavaScript(_ script: String) -> WKWebView {
        evaluateJavaScript(script, completionHandler: nil)
        return self
    }
}
```

- [ ] **Step 5: Commit**

```bash
git add editor/src/editor.ts src/updoc/Resources/editor/editor.js src/updoc/CodeMirrorEditorView.swift
git commit -m "feat: basic CM6 editor with Swift bridge (content in/out)"
```

---

## Task 4: Feature flag in NoteDetailView and SettingsView

**Files:**
- Modify: `src/updoc/NoteDetailView.swift`
- Modify: `src/updoc/SettingsView.swift`

- [ ] **Step 1: Add feature flag to NoteDetailView**

In `NoteDetailView.swift`, add the `@AppStorage` property after the existing `@Environment` declarations (around line 18):
```swift
@AppStorage("useCodeMirrorEditor") private var useCodeMirrorEditor: Bool = false
```

Replace the `EditorView(...)` call at line 151 with:
```swift
if useCodeMirrorEditor {
    CodeMirrorEditorView(
        text: $note.content,
        selectionRange: $selectionRange,
        theme: themeManager.themeName(for: note),
        isReadOnly: note.isReadOnly
    )
} else {
    EditorView(
        text: $note.content,
        assetIds: $note.assetIds,
        selectionRange: $selectionRange,
        theme: themeManager.themeName(for: note),
        isReadOnly: note.isReadOnly,
        modelContainer: modelContext.container
    )
}
```

- [ ] **Step 2: Add Developer tab to SettingsView**

In `src/updoc/SettingsView.swift`, add `.developer` to the `Tab` enum (after line 12):
```swift
case developer
```

Add the toolbar button after the last existing `ToolbarButton` (after the address book button):
```swift
ToolbarButton(title: "Developer", icon: "wrench.and.screwdriver", isSelected: selectedTab == .developer) {
    selectedTab = .developer
}
```

Add the developer panel view inside the `switch selectedTab` block (add a new `case .developer:` branch):
```swift
case .developer:
    DeveloperSettingsView()
```

- [ ] **Step 3: Create DeveloperSettingsView inside SettingsView.swift**

Add this at the bottom of `SettingsView.swift`, before the final closing brace of the file:
```swift
private struct DeveloperSettingsView: View {
    @AppStorage("useCodeMirrorEditor") private var useCodeMirrorEditor: Bool = false

    var body: some View {
        Form {
            Section("Editor") {
                Toggle("Use CodeMirror 6 editor (experimental)", isOn: $useCodeMirrorEditor)
                Text("Switches the note editor to CodeMirror 6 (WKWebView-based). Restart not required.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
```

- [ ] **Step 4: Build and verify**

```bash
xcodebuild -scheme updoc -configuration Debug build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Manual test**

Run the app, open Settings, click Developer, toggle "Use CodeMirror 6 editor." Switch back to a note. The WKWebView-based editor should appear (blank white box with a cursor). Type some text and verify it saves (selecting another note and returning shows the typed text).

- [ ] **Step 6: Commit**

```bash
git add src/updoc/NoteDetailView.swift src/updoc/SettingsView.swift
git commit -m "feat: feature flag to switch between legacy and CM6 editors"
```

---

## Task 5: Theme integration

**Files:**
- Modify: `src/updoc/ThemeManager.swift`
- Create: `tests/updocTests/ThemeCSSTests.swift`

- [ ] **Step 1: Write failing test for cssVariables()**

Create `tests/updocTests/ThemeCSSTests.swift`:
```swift
import Testing
import Foundation
@testable import updoc

struct ThemeCSSTests {
    @Test func modernThemeProducesRequiredCSSVars() {
        let theme = CustomTheme(
            name: "Modern",
            backgroundColor: "#FFFFFF",
            textColor: "#000000",
            headingColor: "#333333",
            blockquoteColor: "#666666",
            highlightColor: "#FFFF00",
            linkColor: "#0000FF",
            fontFamily: "system",
            fontSize: 16
        )
        let vars = theme.cssVariables()

        #expect(vars["--updoc-bg"] == "#FFFFFF")
        #expect(vars["--updoc-text"] == "#000000")
        #expect(vars["--updoc-heading"] == "#333333")
        #expect(vars["--updoc-blockquote"] == "#666666")
        #expect(vars["--updoc-highlight"] == "#FFFF00")
        #expect(vars["--updoc-link"] == "#0000FF")
        #expect(vars["--updoc-font-size"] == "16px")
        #expect(vars["--updoc-font-family"] == "-apple-system, sans-serif")
    }

    @Test func monoFontFamilyMapsToMonospace() {
        let theme = CustomTheme(
            name: "Mono",
            backgroundColor: "#111111",
            textColor: "#00FF00",
            headingColor: "#00FF00",
            blockquoteColor: "#00CC00",
            highlightColor: "#FFFF00",
            linkColor: "#00FFFF",
            fontFamily: "mono",
            fontSize: 14
        )
        let vars = theme.cssVariables()
        #expect(vars["--updoc-font-family"] == "'SF Mono', 'Menlo', monospace")
    }

    @Test func optionalCodeColorAppearsWhenSet() {
        var theme = CustomTheme(
            name: "Test",
            backgroundColor: "#FFF",
            textColor: "#000",
            headingColor: "#000",
            blockquoteColor: "#555",
            highlightColor: "#FF0",
            linkColor: "#00F",
            fontFamily: "system",
            fontSize: 16
        )
        theme.codeColor = "#CC0000"
        theme.codeBackgroundColor = "#F5F5F5"
        let vars = theme.cssVariables()
        #expect(vars["--updoc-code"] == "#CC0000")
        #expect(vars["--updoc-code-bg"] == "#F5F5F5")
    }
}
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
swift test --filter ThemeCSSTests 2>&1 | tail -10
```

Expected: FAIL — `value of type 'CustomTheme' has no member 'cssVariables'`

- [ ] **Step 3: Add cssVariables() to CustomTheme**

In `src/updoc/ThemeManager.swift`, add the following extension after the `CustomTheme` struct definition (after line ~590):
```swift
extension CustomTheme {
    /// Returns a dictionary of CSS custom property names → values
    /// suitable for pushing to the CM6 editor via window.updoc.setTheme().
    public func cssVariables() -> [String: String] {
        var vars: [String: String] = [
            "--updoc-bg":          backgroundColor,
            "--updoc-text":        textColor,
            "--updoc-heading":     headingColor,
            "--updoc-blockquote":  blockquoteColor,
            "--updoc-highlight":   highlightColor,
            "--updoc-link":        linkColor,
            "--updoc-font-size":   "\(Int(fontSize))px",
            "--updoc-font-family": Self.cssFontStack(fontFamily),
        ]
        if let v = codeColor           { vars["--updoc-code"]         = v }
        if let v = codeBackgroundColor { vars["--updoc-code-bg"]      = v }
        if let v = codeFontFamily      { vars["--updoc-code-font"]    = Self.cssFontStack(v) }
        if let v = codeFontSize        { vars["--updoc-code-size"]    = "\(Int(v))px" }
        if let v = bulletColor         { vars["--updoc-bullet"]       = v }
        if let v = horizontalRuleColor { vars["--updoc-hr"]           = v }
        if let v = headingFontFamily   { vars["--updoc-heading-font"] = Self.cssFontStack(v) }
        if let v = headingFontSize     { vars["--updoc-heading-size"] = "\(Int(v))px" }
        return vars
    }

    private static func cssFontStack(_ family: String) -> String {
        switch family {
        case "serif": return "'New York', 'Times New Roman', serif"
        case "mono":  return "'SF Mono', 'Menlo', monospace"
        default:      return "-apple-system, sans-serif"
        }
    }
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
swift test --filter ThemeCSSTests 2>&1 | tail -10
```

Expected: PASS (3 tests)

- [ ] **Step 5: Update setTheme JS to apply font variables**

In `editor/src/editor.ts`, the `setTheme` implementation already applies all CSS vars via `root.style.setProperty`. No code change needed; the CM6 theme references the vars via `var(--updoc-font-size)` etc. already set in the `EditorView.theme({})` block in Task 3.

- [ ] **Step 6: Rebuild bundle**

```bash
./scripts/build_editor.sh
```

- [ ] **Step 7: Commit**

```bash
git add src/updoc/ThemeManager.swift src/updoc/Resources/editor/editor.js tests/updocTests/ThemeCSSTests.swift
git commit -m "feat: CustomTheme.cssVariables() + theme push to CM6 editor"
```

---

## Task 6: Markdown syntax highlighting

**Files:**
- Modify: `editor/src/editor.ts`

CodeMirror 6's `defaultHighlightStyle` handles headings, bold, italic, code, links, and blockquotes automatically when combined with `lang-markdown`. This task replaces `defaultHighlightStyle` with a theme-aware custom style that reads the CSS variables set by `setTheme`.

- [ ] **Step 1: Add custom highlight style to editor.ts**

Add this block to `editor/src/editor.ts`, after the imports:
```typescript
import { HighlightStyle } from "@codemirror/language"
import { tags } from "@lezer/highlight"

function makeHighlightStyle(): HighlightStyle {
  return HighlightStyle.define([
    { tag: tags.heading1,    fontSize: "var(--updoc-heading-size, 2em)",   fontWeight: "bold",   color: "var(--updoc-heading, inherit)" },
    { tag: tags.heading2,    fontSize: "var(--updoc-heading-size, 1.6em)", fontWeight: "bold",   color: "var(--updoc-heading, inherit)" },
    { tag: tags.heading3,    fontSize: "var(--updoc-heading-size, 1.3em)", fontWeight: "bold",   color: "var(--updoc-heading, inherit)" },
    { tag: tags.heading4,    fontWeight: "bold", color: "var(--updoc-heading, inherit)" },
    { tag: tags.heading5,    fontWeight: "bold", color: "var(--updoc-heading, inherit)" },
    { tag: tags.heading6,    fontWeight: "bold", color: "var(--updoc-heading, inherit)" },
    { tag: tags.strong,      fontWeight: "bold" },
    { tag: tags.emphasis,    fontStyle: "italic" },
    { tag: tags.strikethrough, textDecoration: "line-through" },
    { tag: tags.link,        color: "var(--updoc-link, #0070f3)", textDecoration: "underline" },
    { tag: tags.url,         color: "var(--updoc-link, #0070f3)" },
    { tag: tags.monospace,   fontFamily: "var(--updoc-code-font, 'SF Mono', monospace)", fontSize: "var(--updoc-code-size, 0.9em)", color: "var(--updoc-code, inherit)", backgroundColor: "var(--updoc-code-bg, rgba(0,0,0,0.06))" },
    { tag: tags.quote,       color: "var(--updoc-blockquote, #666)", borderLeft: "3px solid var(--updoc-blockquote, #ccc)", paddingLeft: "8px" },
    { tag: tags.processingInstruction, color: "var(--updoc-text, inherit)", opacity: "0.4" }, // syntax markers
    { tag: tags.meta,        color: "var(--updoc-text, inherit)", opacity: "0.4" },
  ])
}
```

In `createEditor()`, replace `syntaxHighlighting(defaultHighlightStyle)` with:
```typescript
syntaxHighlighting(makeHighlightStyle()),
```

- [ ] **Step 2: Rebuild and test visually**

```bash
./scripts/build_editor.sh
```

Run the app with CM6 flag on. Type the following in the editor and confirm correct rendering:
```
# Heading 1
## Heading 2
**bold** and *italic* and ~~strikethrough~~
`inline code`
[link text](https://example.com)
> blockquote
```

- [ ] **Step 3: Commit**

```bash
git add editor/src/editor.ts src/updoc/Resources/editor/editor.js
git commit -m "feat: CM6 markdown syntax highlighting via theme CSS variables"
```

---

## Task 7: Syntax hiding (markers disappear away from cursor)

**Files:**
- Create: `editor/src/updocDecorations.ts`
- Modify: `editor/src/editor.ts`

Syntax hiding shows `**bold**` as `**bold**` only on the current line; on all other lines the `**` markers are hidden and the text renders styled.

- [ ] **Step 1: Create updocDecorations.ts with the syntax-hiding plugin**

Create `editor/src/updocDecorations.ts`:
```typescript
import {
  EditorView, Decoration, DecorationSet, WidgetType, ViewPlugin, ViewUpdate
} from "@codemirror/view"
import { RangeSetBuilder } from "@codemirror/state"
import { syntaxTree } from "@codemirror/language"

/// A zero-width invisible decoration used to hide syntax markers.
const hiddenDeco = Decoration.mark({ class: "cm-updoc-hidden" })

/// Returns the line number (0-based) that contains the primary cursor.
function cursorLine(view: EditorView): number {
  return view.state.doc.lineAt(view.state.selection.main.head).number
}

/// Node names in the Lezer markdown syntax tree whose text should be hidden
/// when the cursor is not on the same line.
const HIDEABLE_NODES = new Set([
  "EmphasisMark",      // * or _
  "StrongEmphasisMark", // ** or __
  "CodeMark",          // `
  "HeaderMark",        // # ## etc.
  "QuoteMark",         // >
  "LinkMark",          // [ ] ( )
  "HorizontalRule",    // --- (hide the dashes, keep spacing)
])

export const syntaxHidingPlugin = ViewPlugin.fromClass(
  class {
    decorations: DecorationSet

    constructor(view: EditorView) {
      this.decorations = this.build(view)
    }

    update(update: ViewUpdate) {
      if (update.docChanged || update.selectionSet || update.viewportChanged) {
        this.decorations = this.build(update.view)
      }
    }

    build(view: EditorView): DecorationSet {
      const builder = new RangeSetBuilder<Decoration>()
      const activeLine = cursorLine(view)

      syntaxTree(view.state).iterate({
        enter(node) {
          if (!HIDEABLE_NODES.has(node.name)) return
          const line = view.state.doc.lineAt(node.from).number
          if (line !== activeLine) {
            builder.add(node.from, node.to, hiddenDeco)
          }
        },
      })

      return builder.finish()
    }
  },
  { decorations: (v) => v.decorations }
)

export const syntaxHidingTheme = EditorView.baseTheme({
  ".cm-updoc-hidden": { display: "none" },
})
```

- [ ] **Step 2: Import and register the plugin in editor.ts**

Add import at the top of `editor/src/editor.ts`:
```typescript
import { syntaxHidingPlugin, syntaxHidingTheme } from "./updocDecorations"
```

Add both to the `extensions` array in `createEditor()`:
```typescript
syntaxHidingPlugin,
syntaxHidingTheme,
```

- [ ] **Step 3: Rebuild**

```bash
./scripts/build_editor.sh
```

- [ ] **Step 4: Manual test**

In the CM6 editor type:
```
**bold text here**
*italic here*
```

Move cursor to line 1: `**` markers should appear. Move cursor away: only `bold text here` (styled) should be visible; the `**` markers should disappear.

- [ ] **Step 5: Commit**

```bash
git add editor/src/updocDecorations.ts editor/src/editor.ts src/updoc/Resources/editor/editor.js
git commit -m "feat: syntax hiding — markers invisible when cursor is off-line"
```

---

## Task 8: Custom updoc decorations (underline and highlight)

**Files:**
- Modify: `editor/src/updocDecorations.ts`
- Modify: `editor/src/editor.ts`

updoc uses `~text~` for underline and `==text==` for highlight — both non-standard. CM6's Lezer markdown parser doesn't know about them, so we need a `ViewPlugin` that finds them with a regex and applies decorations.

- [ ] **Step 1: Add custom decoration plugin to updocDecorations.ts**

Append to `editor/src/updocDecorations.ts`:
```typescript
const underlineMark = Decoration.mark({ class: "cm-updoc-underline" })
const highlightMark = Decoration.mark({ class: "cm-updoc-highlight" })

// Matches ~text~ (single tilde, not double ~~)
const UNDERLINE_RE = /(?<![~])~(?!~)(.+?)(?<![~])~(?!~)/g
// Matches ==text==
const HIGHLIGHT_RE = /==(.+?)==/g

export const customMarkPlugin = ViewPlugin.fromClass(
  class {
    decorations: DecorationSet

    constructor(view: EditorView) {
      this.decorations = this.build(view)
    }

    update(update: ViewUpdate) {
      if (update.docChanged || update.viewportChanged) {
        this.decorations = this.build(update.view)
      }
    }

    build(view: EditorView): DecorationSet {
      const builder = new RangeSetBuilder<Decoration>()
      const activeLine = cursorLine(view)

      for (const { from, to } of view.visibleRanges) {
        const text = view.state.sliceDoc(from, to)

        for (const re of [
          { pattern: UNDERLINE_RE, deco: underlineMark },
          { pattern: HIGHLIGHT_RE, deco: highlightMark },
        ]) {
          re.pattern.lastIndex = 0
          let m: RegExpExecArray | null
          while ((m = re.pattern.exec(text)) !== null) {
            const start = from + m.index
            const end = start + m[0].length
            const line = view.state.doc.lineAt(start).number
            if (line !== activeLine) {
              // Hide the syntax markers (first/last 1-2 chars)
              const markerLen = re.deco === underlineMark ? 1 : 2
              builder.add(start,              start + markerLen, hiddenDeco)
              builder.add(end - markerLen,    end,               hiddenDeco)
              builder.add(start + markerLen,  end - markerLen,   re.deco)
            }
          }
        }
      }

      return builder.finish()
    }
  },
  { decorations: (v) => v.decorations }
)

export const customMarkTheme = EditorView.baseTheme({
  ".cm-updoc-underline": { textDecoration: "underline" },
  ".cm-updoc-highlight": {
    backgroundColor: "var(--updoc-highlight, rgba(255,255,0,0.4))",
    borderRadius: "2px",
  },
})
```

- [ ] **Step 2: Import and register in editor.ts**

Update the import from `updocDecorations`:
```typescript
import {
  syntaxHidingPlugin,
  syntaxHidingTheme,
  customMarkPlugin,
  customMarkTheme,
} from "./updocDecorations"
```

Add to extensions:
```typescript
customMarkPlugin,
customMarkTheme,
```

- [ ] **Step 3: Rebuild and test visually**

```bash
./scripts/build_editor.sh
```

Type in CM6 editor:
```
~underlined text~
==highlighted text==
```

Move cursor away from each line. Markers should hide and styles should apply.

- [ ] **Step 4: Commit**

```bash
git add editor/src/updocDecorations.ts editor/src/editor.ts src/updoc/Resources/editor/editor.js
git commit -m "feat: underline (~text~) and highlight (==text==) custom decorations"
```

---

## Task 9: GFM task lists with interactive checkbox widgets

**Files:**
- Modify: `editor/src/updocDecorations.ts`
- Modify: `editor/src/editor.ts`
- Modify: `src/updoc/CodeMirrorEditorView.swift`

GFM `- [ ] task` and `- [x] task` are parsed natively by `@lezer/markdown` when the `GFM` extension is active (already included in Task 3). This task adds:
1. A checkbox widget that replaces `[ ]` / `[x]` with a real `<input type="checkbox">`
2. A `√` input rule that inserts `- [ ] ` 
3. The `checkboxToggled` Swift handler that updates the note's content

- [ ] **Step 1: Add CheckboxWidget to updocDecorations.ts**

Append to `editor/src/updocDecorations.ts`:
```typescript
export class CheckboxWidget extends WidgetType {
  constructor(readonly checked: boolean) { super() }

  toDOM(): HTMLElement {
    const wrap = document.createElement("span")
    wrap.setAttribute("aria-hidden", "true")
    const box = document.createElement("input")
    box.type = "checkbox"
    box.checked = this.checked
    box.style.cursor = "pointer"
    box.style.verticalAlign = "middle"
    box.style.marginRight = "4px"
    wrap.appendChild(box)
    return wrap
  }

  ignoreEvent(event: Event): boolean {
    return false // let click events through
  }
}

export const taskListPlugin = ViewPlugin.fromClass(
  class {
    decorations: DecorationSet

    constructor(view: EditorView) {
      this.decorations = this.build(view)
    }

    update(update: ViewUpdate) {
      if (update.docChanged || update.viewportChanged) {
        this.decorations = this.build(update.view)
      }
    }

    build(view: EditorView): DecorationSet {
      const builder = new RangeSetBuilder<Decoration>()

      for (let i = 1; i <= view.state.doc.lines; i++) {
        const line = view.state.doc.line(i)
        const text = line.text

        // Match "- [ ] " or "- [x] " at start of line (with optional leading whitespace)
        const m = text.match(/^(\s*-\s)(\[[ xX]\])(\s)/)
        if (!m) continue

        const checkboxFrom = line.from + m[1].length
        const checkboxTo   = checkboxFrom + m[2].length
        const checked      = m[2].toLowerCase() === "[x]"

        builder.add(
          checkboxFrom,
          checkboxTo,
          Decoration.replace({ widget: new CheckboxWidget(checked) })
        )
      }

      return builder.finish()
    }
  },
  { decorations: (v) => v.decorations }
)
```

- [ ] **Step 2: Wire checkbox click to toggle content**

In `editor/src/editor.ts`, add a DOM event handler for checkbox clicks in `createEditor()`.

Note: use `posAtCoords` (mouse coordinates → document position) rather than `posAtDOM` (DOM node → position). `posAtDOM` is unreliable for widget replacement nodes.

Add to the `extensions` array:
```typescript
EditorView.domEventHandlers({
  mousedown(event, view) {
    const target = event.target as HTMLElement
    if (target.tagName !== "INPUT" || (target as HTMLInputElement).type !== "checkbox") {
      return false
    }
    event.preventDefault()
    const pos = view.posAtCoords({ x: event.clientX, y: event.clientY }, false)
    if (pos == null) return false
    const line = view.state.doc.lineAt(pos)
    const m = line.text.match(/^(\s*-\s)(\[[ xX]\])/)
    if (!m) return false
    const from = line.from + m[1].length
    const to   = from + m[2].length
    const isChecked = m[2].toLowerCase() === "[x]"
    view.dispatch({
      changes: { from, to, insert: isChecked ? "[ ]" : "[x]" }
    })
    return true
  }
}),
```

- [ ] **Step 3: Add √ input rule**

In `createEditor()`, add a `keymap` entry for the `√` character (Option+V on US keyboards):
```typescript
keymap.of([
  {
    key: "√",
    run(view) {
      const cursor = view.state.selection.main.head
      const line = view.state.doc.lineAt(cursor)
      // Only trigger at start of line or after whitespace
      const before = view.state.sliceDoc(line.from, cursor)
      if (before.trim() === "") {
        view.dispatch({ changes: { from: cursor, insert: "- [ ] " } })
        return true
      }
      return false
    }
  }
]),
```

- [ ] **Step 4: Import and register taskListPlugin in editor.ts**

Update import:
```typescript
import {
  syntaxHidingPlugin,
  syntaxHidingTheme,
  customMarkPlugin,
  customMarkTheme,
  taskListPlugin,
} from "./updocDecorations"
```

Add to extensions:
```typescript
taskListPlugin,
```

- [ ] **Step 5: Rebuild**

```bash
./scripts/build_editor.sh
```

- [ ] **Step 6: Manual test**

In CM6 editor:
1. Type `- [ ] buy oat milk` — a checkbox should appear
2. Click the checkbox — it should toggle to `[x]`
3. Type `√` at the start of a new line — it should insert `- [ ] `

- [ ] **Step 7: Commit**

```bash
git add editor/src/updocDecorations.ts editor/src/editor.ts src/updoc/Resources/editor/editor.js src/updoc/CodeMirrorEditorView.swift
git commit -m "feat: GFM task list checkboxes with interactive toggle and √ shortcut"
```

---

## Task 10: Search result navigation (scrollToRange)

The `selectionRange: NSRange?` binding is already wired in `CodeMirrorEditorView.updateNSView` (Task 3). `NSRange` uses UTF-16 code unit offsets, which matches CM6's internal position model. This task verifies the end-to-end flow works.

**Files:**
- No code changes needed — verify existing wiring

- [ ] **Step 1: Manual test of search navigation**

1. Enable CM6 editor via Settings > Developer
2. Create a note with several paragraphs including the word "quantum"
3. Open global search (Cmd+Shift+F), search for "quantum"
4. Click the result
5. Confirm the CM6 editor scrolls and selects the matched word

- [ ] **Step 2: If navigation does not work, debug**

Check `ContentView.swift` line ~103 where `selectionRange = snippet.absoluteRange` is set. Confirm the `NoteDetailView` receives the updated binding and calls `coordinator.scrollToRange`.

Add a temporary `print` in `Coordinator.scrollToRange` to confirm it fires:
```swift
func scrollToRange(from: Int, to: Int) {
    print("[CM6] scrollToRange from:\(from) to:\(to)")
    guard isEditorReady, let webView else { return }
    webView.evaluateJavaScript("window.updoc.scrollToRange(\(from), \(to))")
}
```

Remove the print after confirming.

- [ ] **Step 3: Commit (only if step 2 required fixes)**

```bash
git add src/updoc/CodeMirrorEditorView.swift
git commit -m "fix: CM6 editor scroll-to-search-result wiring"
```

---

## Task 11: Spell check and autocorrect forwarding

**Files:**
- Modify: `src/updoc/CodeMirrorEditorView.swift`

- [ ] **Step 1: Forward autocorrect setting to WKWebView**

In `CodeMirrorEditorView.makeNSView`, the `spellcheckEnabled` `@AppStorage` is already forwarded to `config.preferences.isGrammarCheckingEnabled`. Add autocorrect:

After `config.preferences.isGrammarCheckingEnabled = spellcheckEnabled`, add:
```swift
// WKWebView inherits system autocorrect from the responder chain;
// disable via contenteditable attribute when the user turns it off.
// The CM6 editor.html already uses contenteditable, so we push the
// attribute via JS after load.
```

In `Coordinator.webView(_:didFinish:)`, after `applyTheme()`, add:
```swift
let autocorrect = parent.autocorrectEnabled
webView.evaluateJavaScript(
    "document.querySelector('.cm-content')?.setAttribute('autocorrect', '\(autocorrect ? "on" : "off")')"
)
webView.evaluateJavaScript(
    "document.querySelector('.cm-content')?.setAttribute('spellcheck', '\(parent.spellcheckEnabled ? "true" : "false")')"
)
```

- [ ] **Step 2: Build**

```bash
xcodebuild -scheme updoc -configuration Debug build 2>&1 | tail -5
```

- [ ] **Step 3: Manual test**

In Settings > Editor, toggle spell check off. Switch to the CM6 editor. Confirm red squiggles disappear (may require re-opening the note).

- [ ] **Step 4: Commit**

```bash
git add src/updoc/CodeMirrorEditorView.swift
git commit -m "feat: forward spellcheck/autocorrect settings to CM6 WKWebView"
```

---

## Task 12: AppMigrationManager — checklist syntax migration

**Files:**
- Create: `src/updoc/AppMigrationManager.swift`
- Create: `tests/updocTests/AppMigrationManagerTests.swift`
- Modify: `src/updoc/updocApp.swift`

- [ ] **Step 1: Write failing tests**

Create `tests/updocTests/AppMigrationManagerTests.swift`:
```swift
import Testing
import Foundation
@testable import updoc

struct AppMigrationManagerTests {
    @Test func bareUncheckedBecomesGFM() {
        let input    = "[ ] buy milk"
        let expected = "- [ ] buy milk"
        #expect(AppMigrationManager.migrateContent(input) == expected)
    }

    @Test func bareCheckedBecomesGFM() {
        let input    = "[x] done task"
        let expected = "- [x] done task"
        #expect(AppMigrationManager.migrateContent(input) == expected)
    }

    @Test func uppercaseXNormalised() {
        let input    = "[X] Done"
        let expected = "- [x] Done"
        #expect(AppMigrationManager.migrateContent(input) == expected)
    }

    @Test func indentedLinePreservesIndent() {
        let input    = "  [ ] indented task"
        let expected = "  - [ ] indented task"
        #expect(AppMigrationManager.migrateContent(input) == expected)
    }

    @Test func alreadyGFMLineIsUntouched() {
        let input    = "- [ ] already correct"
        let expected = "- [ ] already correct"
        #expect(AppMigrationManager.migrateContent(input) == expected)
    }

    @Test func bulletVariantsUntouched() {
        let input    = "* [ ] asterisk bullet\n+ [x] plus bullet"
        #expect(AppMigrationManager.migrateContent(input) == input)
    }

    @Test func multiLineDocumentMigratesOnlyBareLine() {
        let input = """
        # Heading
        [ ] task one
        - [ ] already done
        [x] completed
        Normal paragraph text
        """
        let expected = """
        # Heading
        - [ ] task one
        - [ ] already done
        - [x] completed
        Normal paragraph text
        """
        #expect(AppMigrationManager.migrateContent(input) == expected)
    }

    @Test func emptyStringReturnedUnchanged() {
        #expect(AppMigrationManager.migrateContent("") == "")
    }
}
```

- [ ] **Step 2: Run to confirm failure**

```bash
swift test --filter AppMigrationManagerTests 2>&1 | tail -10
```

Expected: FAIL — module not found / type not found

- [ ] **Step 3: Implement AppMigrationManager**

Create `src/updoc/AppMigrationManager.swift`:
```swift
import Foundation
import SwiftData

/// Runs one-time content migrations keyed by an integer version stored in UserDefaults.
/// Each migration version runs exactly once, in order, on first launch after an upgrade.
@MainActor
struct AppMigrationManager {
    static let currentVersion = 1
    private static let versionKey = "appMigrationVersion"

    /// Call once from the app entry point after the ModelContext is available.
    static func runIfNeeded(context: ModelContext) {
        let last = UserDefaults.standard.integer(forKey: versionKey)
        guard last < currentVersion else { return }

        if last < 1 { migrateChecklistSyntax(context: context) }

        UserDefaults.standard.set(currentVersion, forKey: versionKey)
    }

    private static func migrateChecklistSyntax(context: ModelContext) {
        let descriptor = FetchDescriptor<Note>()
        guard let notes = try? context.fetch(descriptor) else { return }
        var changed = false
        for note in notes {
            let migrated = migrateContent(note.content)
            if migrated != note.content {
                note.content = migrated
                changed = true
            }
        }
        if changed { try? context.save() }
    }

    /// Pure function — converts bare `[ ] text` / `[x] text` lines to GFM `- [ ] text` / `- [x] text`.
    /// Lines that already have a list marker (`-`, `*`, `+`) before the checkbox are left unchanged.
    static func migrateContent(_ content: String) -> String {
        let lines = content.components(separatedBy: "\n")
        return lines.map { line -> String in
            let whitespace = String(line.prefix(while: { $0 == " " || $0 == "\t" }))
            let rest = String(line.dropFirst(whitespace.count))

            // Already has a recognised list marker — leave alone
            if rest.hasPrefix("- [") || rest.hasPrefix("* [") || rest.hasPrefix("+ [") {
                return line
            }

            if rest.hasPrefix("[ ] ") {
                return whitespace + "- [ ] " + rest.dropFirst(4)
            }
            if rest == "[ ]" {
                return whitespace + "- [ ]"
            }
            if rest.hasPrefix("[x] ") || rest.hasPrefix("[X] ") {
                return whitespace + "- [x] " + rest.dropFirst(4)
            }
            if rest == "[x]" || rest == "[X]" {
                return whitespace + "- [x]"
            }

            return line
        }.joined(separator: "\n")
    }
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
swift test --filter AppMigrationManagerTests 2>&1 | tail -10
```

Expected: PASS (8 tests)

- [ ] **Step 5: Call migration from updocApp.swift**

In `src/updoc/updocApp.swift`, inside the `WindowGroup` `.task` modifier (after `await AuthManager.shared.load()`), add:

First add `@Environment(\.modelContext) private var modelContext` to `ContentView` — actually, the migration needs to run from `updocApp` where the container is available. The cleanest approach is a `.task` modifier on the `WindowGroup`'s content. Open `updocApp.swift` and modify the `ContentView()` block:

```swift
WindowGroup("updoc") {
    ContentView()
        .task {
            await AuthManager.shared.load()
        }
        .task {
            // Run once on first launch after upgrade
            let ctx = container.mainContext
            await MainActor.run {
                AppMigrationManager.runIfNeeded(context: ctx)
            }
        }
        .environment(themeManager)
}
```

- [ ] **Step 6: Build**

```bash
xcodebuild -scheme updoc -configuration Debug build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 7: Commit**

```bash
git add src/updoc/AppMigrationManager.swift tests/updocTests/AppMigrationManagerTests.swift src/updoc/updocApp.swift
git commit -m "feat: AppMigrationManager migrates bare [ ] checklist syntax to GFM - [ ]"
```

---

## Task 13: WeeklyLogDashboardView editor swap

**Files:**
- Modify: `src/updoc/WeeklyLogDashboardView.swift`

- [ ] **Step 1: Add feature flag and swap editor**

In `src/updoc/WeeklyLogDashboardView.swift`, add after the existing `@State` declarations:
```swift
@AppStorage("useCodeMirrorEditor") private var useCodeMirrorEditor: Bool = false
@Environment(ThemeManager.self) private var themeManager
```

Find the `EditorView(...)` call (around line 78). Replace it with the same feature-flag pattern used in `NoteDetailView`:
```swift
if useCodeMirrorEditor {
    CodeMirrorEditorView(
        text: $note.content,
        selectionRange: $selectionRange,
        theme: themeManager.themeName(for: note),
        isReadOnly: note.isReadOnly
    )
} else {
    EditorView(
        text: $note.content,
        assetIds: $note.assetIds,
        selectionRange: $selectionRange,
        theme: themeManager.themeName(for: note),
        isReadOnly: note.isReadOnly,
        modelContainer: modelContext.container
    )
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild -scheme updoc -configuration Debug build 2>&1 | tail -5
```

- [ ] **Step 3: Manual test**

Enable the feature flag, open the Weekly Log view, confirm the CM6 editor loads and accepts text input.

- [ ] **Step 4: Commit**

```bash
git add src/updoc/WeeklyLogDashboardView.swift
git commit -m "feat: use CM6 editor in WeeklyLogDashboardView when flag enabled"
```

---

## Task 14: Markdown parity verification and feature flag removal

**Prerequisite:** All tasks above complete. The CM6 editor should handle everything in `docs/MARKDOWN.md`.

- [ ] **Step 1: Parity checklist — run through docs/MARKDOWN.md**

Enable CM6 editor. In a test note, type and verify each of the following renders correctly:
- `# H1` through `###### H6` — headings in theme heading color
- `**bold**`, `*italic*`, `***bold italic***`
- `~underline~` — underlined
- `~~strikethrough~~` — struck through
- `==highlight==` — highlighted background
- `` `inline code` `` — monospace with background
- ` ``` multiline ``` ` — code block
- `> blockquote` — styled with left border
- `---` — horizontal rule
- `[link](https://example.com)` — clickable link opens browser
- `- [ ] task` and `- [x] done` — checkbox renders, toggles on click
- Switching themes updates colors immediately

- [ ] **Step 2: Verify search navigation**

Search for a word that appears in the middle of a long note. Select the result. Confirm the CM6 editor scrolls to and highlights it.

- [ ] **Step 3: Verify sync still works**

With a note linked to a Google Doc, trigger Sync Now. Confirm the sync completes and the note content is unchanged (the `$note.content` binding still drives sync regardless of which editor is shown).

- [ ] **Step 4: Remove feature flag — NoteDetailView**

In `src/updoc/NoteDetailView.swift`, remove the `@AppStorage("useCodeMirrorEditor")` line and replace the `if useCodeMirrorEditor { ... } else { ... }` block with just the `CodeMirrorEditorView(...)` call:
```swift
CodeMirrorEditorView(
    text: $note.content,
    selectionRange: $selectionRange,
    theme: themeManager.themeName(for: note),
    isReadOnly: note.isReadOnly
)
```

- [ ] **Step 5: Remove feature flag — WeeklyLogDashboardView**

Apply the same removal in `src/updoc/WeeklyLogDashboardView.swift`.

- [ ] **Step 6: Remove Developer tab from SettingsView**

In `src/updoc/SettingsView.swift`:
- Delete `case developer` from the `Tab` enum
- Delete the `ToolbarButton(title: "Developer" ...)` entry
- Delete `case .developer: DeveloperSettingsView()` from the switch
- Delete the `DeveloperSettingsView` struct

- [ ] **Step 7: Delete legacy editor files**

```bash
rm src/updoc/EditorView.swift
rm src/updoc/MarkdownEngine.swift
rm src/updoc/EditorLayoutManager.swift
```

Remove the deleted files from the Xcode project in Xcode (right-click → Delete → Remove Reference).

- [ ] **Step 8: Delete MarkdownEngineTests**

The old regex-based engine tests are no longer valid. Delete:
```bash
rm tests/updocTests/MarkdownEngineTests.swift
```

Remove from Xcode target as above.

- [ ] **Step 9: Build cleanly**

```bash
xcodebuild -scheme updoc -configuration Debug build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED` with no references to removed types.

- [ ] **Step 10: Run all tests**

```bash
swift test 2>&1 | tail -20
```

Expected: all existing tests pass (AppMigrationManagerTests, ThemeCSSTests, and all others).

- [ ] **Step 11: Final commit**

```bash
git add -A
git commit -m "feat: remove feature flag and legacy editor; CM6 is now the only editor"
```

---

## Known Gap: Inline Image Rendering

The spec lists `![alt](url)` as requiring a CM6 widget decoration for inline rendering. This plan deliberately defers it. The current `EditorView.swift` has significant complexity around `RemoteImageAttachment`, `ImageLibraryManager`, drag-and-drop, and QuickLook editing — all of which would need new widget decorations and an async image loading pipeline in CM6.

Inline image rendering is tracked as a follow-up plan after this migration is complete and stable. Standard markdown image syntax (`![alt](url)`) will show as styled text in the CM6 editor until that plan is implemented.

---

## Appendix: Xcode Run Script Build Phase

To keep `editor.js` always in sync with `editor/src/editor.ts` during normal Xcode builds, add a Run Script phase:

1. In Xcode, select the `updoc` target → Build Phases → `+` → New Run Script Phase
2. Drag it to run **before** "Compile Sources"
3. Set the script body to:
```bash
"${SRCROOT}/scripts/build_editor.sh"
```
4. Check "Based on dependency analysis" OFF (always run) until the build is stable, then revisit.

This is a manual Xcode step and cannot be scripted from the command line reliably.
