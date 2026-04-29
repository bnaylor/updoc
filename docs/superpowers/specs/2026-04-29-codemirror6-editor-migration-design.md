# Design: CodeMirror 6 Editor Migration

_Date: 2026-04-29_

## Summary

Replace the custom `NSTextView` / TextKit 2 editor and regex-based `MarkdownEngine` with a [CodeMirror 6](https://codemirror.net/) editor hosted in a `WKWebView`. The change is surgical: only the editor view component and markdown engine are replaced. All other app infrastructure (SwiftData models, Google sync, navigation, search, templates, themes, calendar integration) is untouched.

---

## Motivation

The current `EditorView.swift` + `MarkdownEngine.swift` stack is an accumulating set of edge cases. Bullet indentation, list continuation, syntax hiding (making `**` disappear when the cursor leaves), and custom glyph rendering all fight against TextKit 2's own layout model. This is not a core competency — it is a solved problem elsewhere.

CodeMirror 6 is the editor Obsidian chose for exactly this reason. Its Lezer incremental parser and decoration system are purpose-built for live markdown rendering with syntax hiding. It eliminates the edge-case accumulation without touching any other part of the app.

---

## Scope

### Replaced
| File | Replacement |
|---|---|
| `EditorView.swift` | New `CodeMirrorEditorView.swift` wrapping `WKWebView` |
| `MarkdownEngine.swift` | CM6 Lezer parser + decoration extensions (JavaScript) |

### Untouched
- All SwiftData models (`Note.swift`, etc.)
- `SyncCoordinator`, `AuthManager`, all Google service layers
- `SidebarView`, `NoteListView`, `ContentView`, `NoteDetailView`
- Search (operates on raw text in SwiftData, not the editor widget)
- Templates, themes, calendar integration, conflict UI, image sync

---

## Architecture

### JavaScript Bundle

CodeMirror 6 is bundled at build time into a single `editor.js` file using `esbuild`. The bundle is committed to the Xcode project as a resource. A companion `editor.html` loads it.

**CM6 packages included:**
- `@codemirror/view` + `@codemirror/state` — core editor
- `@codemirror/lang-markdown` with the GFM extension (includes task list parsing)
- `@codemirror/commands` — standard keybindings
- `@codemirror/language` + highlight styles — code block syntax highlighting
- Custom extension: `updocDecorations` — syntax hiding, checkbox widgets, theme CSS variables

The bundle is loaded via a `WKURLSchemeHandler` registered for the `editor://` scheme. This avoids the `file://` restriction that would block web workers, works fully offline, and requires no localhost server.

### `CodeMirrorEditorView.swift`

An `NSViewRepresentable` wrapping `WKWebView`. The `Coordinator` class implements `WKScriptMessageHandler` and `WKNavigationDelegate`, replacing the current `NSTextViewDelegate`-based coordinator.

```
CodeMirrorEditorView (NSViewRepresentable)
├── makeNSView → WKWebView configured with WKWebViewConfiguration
│   └── registers message handlers: contentChanged, checkboxToggled, linkClicked
├── updateNSView → calls loadContent() when note changes
└── Coordinator : WKScriptMessageHandler
    ├── userContentController(_:didReceive:) — handles JS→Swift messages
    └── bridge helpers: loadContent, setTheme, scrollToRange, setReadOnly
```

---

## Swift ↔ JavaScript Bridge

### Swift → Editor

Called via `webView.evaluateJavaScript(...)`.

| Function | When called | Payload |
|---|---|---|
| `updoc.loadContent(text)` | Note selection changes | Raw markdown string |
| `updoc.setTheme(vars)` | Theme changes | JSON object of CSS variable name → value |
| `updoc.scrollToRange(from, to)` | Search result selected | UTF-16 code unit offsets (matches CM6's internal position model) |
| `updoc.setReadOnly(bool)` | Note lock state changes | Boolean |

### Editor → Swift

Sent via `window.webkit.messageHandlers.<name>.postMessage(...)`.

| Message | When sent | Payload |
|---|---|---|
| `contentChanged` | Text changes (debounced 300ms) | `{ text: String }` |
| `checkboxToggled` | User clicks a checkbox widget | `{ lineIndex: Int, checked: Bool }` |
| `linkClicked` | User clicks a `[label](url)` link | `{ url: String }` |

`contentChanged` maps to the existing SwiftData save path. `checkboxToggled` maps to the existing checkbox sync logic. `linkClicked` is passed to the app's existing URL handler.

---

## Markdown Feature Parity

All syntax in `docs/MARKDOWN.md` is supported.

| Feature | Implementation |
|---|---|
| Headings H1–H6 | CM6 lang-markdown built-in |
| Bold, italic, bold+italic | CM6 lang-markdown built-in |
| Underline `~text~` | Custom decoration in `updocDecorations` |
| Strikethrough `~~text~~` | CM6 GFM extension |
| Highlight `==text==` | Custom decoration in `updocDecorations` |
| Inline code `` `text` `` | CM6 lang-markdown built-in |
| Code blocks ` ``` ` | CM6 lang-markdown + highlight styles |
| Blockquote `>` | CM6 lang-markdown built-in |
| Horizontal rule `---` | CM6 lang-markdown built-in |
| Links `[label](url)` | CM6 lang-markdown built-in + click handler |
| Images `![alt](url)` | CM6 lang-markdown + widget decoration for inline rendering |
| Syntax hiding | Lezer decoration extension (show markers only when cursor is on line) |
| **Task lists** | GFM `TaskList` extension (see below) |

### Task List Syntax

Updoc adopts standard GFM task list syntax:

```markdown
- [ ] unchecked item
- [x] checked item
```

The `√` shortcut inserts `- [ ] ` (with trailing space) instead of the current `[ ] `.

**One-time migration:** Existing notes using the bare `[ ] Task` format (no leading `- `) are migrated at first launch after the update. A migration function in `AppMigrationManager` scans all `Note.content` strings, applies a regex replacement (`^(\s*)\[ \]` → `$1- [ ]` and `^(\s*)\[x\]` → `$1- [x]`), and saves. This runs once, guarded by a SwiftData migration version flag.

### Theme Integration

Themes currently define colors and styles as Swift values. These are translated to CSS custom properties (e.g., `--updoc-heading-color: #E06C75`) and pushed to the editor via `updoc.setTheme(vars)` on load and on theme change. The `updocDecorations` extension reads these properties for all styled elements.

---

## Feature Flag

During development, `NoteDetailView` selects between `EditorView` and `CodeMirrorEditorView` via a boolean in `AppSettings`:

```swift
if appSettings.useCodeMirrorEditor {
    CodeMirrorEditorView(note: note)
} else {
    EditorView(note: note) // legacy
}
```

The flag is stored as `@AppStorage("useCodeMirrorEditor")` (consistent with the existing `spellcheckEnabled`/`autocorrectEnabled` pattern) and exposed in Settings > Developer for easy toggling. It is removed (and legacy code deleted) once the new editor reaches parity.

The existing `spellcheckEnabled` and `autocorrectEnabled` `@AppStorage` values must be forwarded to the `WKWebView` via `configuration.preferences` and the CM6 extension config, so those Settings controls continue to work.

---

## Build System

A `scripts/build_editor.sh` script runs `esbuild` to produce `editor.js` from the TypeScript source in `editor/src/`. The output goes to `updoc/Resources/editor/`. This script is called from a Run Script build phase in Xcode, before compilation, so the bundle is always current.

`editor/src/` lives in the repo alongside the Swift source. `node_modules/` is gitignored; `package.json` and `package-lock.json` are committed.

---

## Testing

- **Bridge round-trip:** Unit test that `loadContent` → `contentChanged` returns the same string.
- **Checkbox toggle:** Insert a `- [ ] item`, simulate click, verify `checkboxToggled` message and that the underlying note content updates to `- [x] item`.
- **Theme application:** Verify that CSS variable values pushed via `setTheme` appear in `getComputedStyle` queries from the test harness.
- **Migration:** Unit test `AppMigrationManager` against known-bad content strings to verify correct `[ ] Task` → `- [ ] Task` transformation.
- **Manual parity checklist:** Run through `docs/MARKDOWN.md` syntax in both editors before removing the feature flag.

---

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| WKWebView spell check / autocorrect behavior differs from NSTextView | `WKWebView` supports `isGrammarCheckingEnabled` and respects system spell check; test early |
| Font rendering subtly different from native CoreText | Use system font stack (`-apple-system`) in CSS; acceptable tradeoff |
| `evaluateJavaScript` is async — could cause content race on rapid note switching | Debounce note switches; cancel in-flight JS calls on note change |
| Build dependency on Node.js/esbuild for the editor bundle | Document in README; `editor.js` pre-built artifact can be committed for contributors without Node |
| Existing note content with bare `[ ] Task` syntax | One-time migration function (described above) |
