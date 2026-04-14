# Markdown Syntax Hiding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hide markdown syntax characters visually when the cursor is not actively focused on them.

**Architecture:** Extend `MarkdownEngine` to track the specific NSRanges of syntax characters (`syntaxRanges`). Then, update `EditorView.Coordinator` to monitor `textViewDidChangeSelection` and selectively apply a 0.1pt clear font to those syntax ranges when the cursor is outside the element's full range.

**Tech Stack:** Swift, SwiftUI, TextKit 1 (NSTextView, NSAttributedString).

---

### Task 1: Update MarkdownRange to support syntaxRanges

**Files:**
- Modify: `src/updoc/MarkdownEngine.swift`
- Modify: `tests/updocTests/MarkdownEngineTests.swift`

- [ ] **Step 1: Write the failing test**
Update `tests/updocTests/MarkdownEngineTests.swift` to assert `syntaxRanges`. Replace `detectsBoldText` with:

```swift
    @Test func detectsBoldText() throws {
        let text = "This is **bold** text"
        let ranges = engine.parse(text)
        
        let boldRange = try #require(ranges.first { $0.style == .bold })
        #expect(boldRange.range.length == 8)
        #expect(boldRange.syntaxRanges.count == 2)
        #expect(boldRange.syntaxRanges[0] == NSRange(location: 8, length: 2))
        #expect(boldRange.syntaxRanges[1] == NSRange(location: 14, length: 2))
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter MarkdownEngineTests`
Expected: Compilation failure because `syntaxRanges` does not exist on `MarkdownRange`.

- [ ] **Step 3: Write minimal implementation**
Modify `MarkdownRange` in `src/updoc/MarkdownEngine.swift`:

```swift
public struct MarkdownRange: Equatable {
    public let range: NSRange
    public let style: MarkdownStyle
    public let syntaxRanges: [NSRange]
    
    public init(range: NSRange, style: MarkdownStyle, syntaxRanges: [NSRange] = []) {
        self.range = range
        self.style = style
        self.syntaxRanges = syntaxRanges
    }
}
```

And update `parse` to populate it for bold text (replace the `boldRegex.enumerateMatches` block):

```swift
        // 2. Bold (e.g., **bold**)
        let boldRegex = try! NSRegularExpression(pattern: "\\*\\*.*?\\*\\*", options: [])
        boldRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            if let matchRange = match?.range {
                let startSyntax = NSRange(location: matchRange.location, length: 2)
                let endSyntax = NSRange(location: matchRange.location + matchRange.length - 2, length: 2)
                ranges.append(MarkdownRange(range: matchRange, style: .bold, syntaxRanges: [startSyntax, endSyntax]))
            }
        }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter MarkdownEngineTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/updoc/MarkdownEngine.swift tests/updocTests/MarkdownEngineTests.swift
git commit -m "feat: add syntaxRanges to MarkdownRange for bold text"
```

---

### Task 2: Populate syntaxRanges for all other Markdown Styles

**Files:**
- Modify: `src/updoc/MarkdownEngine.swift`

- [ ] **Step 1: Write the implementation**
Update the rest of the parsing blocks in `parse` in `src/updoc/MarkdownEngine.swift` to populate `syntaxRanges`.

```swift
        // 1. Headings (e.g., # Heading)
        let headingRegex = try! NSRegularExpression(pattern: "^#{1,6}\\s+.*$", options: [.anchorsMatchLines])
        headingRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            if let matchRange = match?.range {
                let line = (text as NSString).substring(with: matchRange)
                let level = line.prefix { $0 == "#" }.count
                // Syntax is the '#'s plus the following space
                let syntaxRange = NSRange(location: matchRange.location, length: level + 1)
                ranges.append(MarkdownRange(range: matchRange, style: .heading(level: level), syntaxRanges: [syntaxRange]))
            }
        }
```

```swift
        // 3. Italic (e.g., *italic*)
        let italicRegex = try! NSRegularExpression(pattern: "(?<!\\*)\\*[^\\*\\n]+?\\*(?!\\*)", options: [])
        italicRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            if let matchRange = match?.range {
                let startSyntax = NSRange(location: matchRange.location, length: 1)
                let endSyntax = NSRange(location: matchRange.location + matchRange.length - 1, length: 1)
                ranges.append(MarkdownRange(range: matchRange, style: .italic, syntaxRanges: [startSyntax, endSyntax]))
            }
        }
```

```swift
        // 4. Underline (e.g., __underline__)
        let underlineRegex = try! NSRegularExpression(pattern: "__.*?__", options: [])
        underlineRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            if let matchRange = match?.range {
                let startSyntax = NSRange(location: matchRange.location, length: 2)
                let endSyntax = NSRange(location: matchRange.location + matchRange.length - 2, length: 2)
                ranges.append(MarkdownRange(range: matchRange, style: .underline, syntaxRanges: [startSyntax, endSyntax]))
            }
        }
```

```swift
        // 4. Checklist (e.g., [ ], [x], or √)
        let checklistRegex = try! NSRegularExpression(pattern: "^(\\s*)(\\[[ x]\\]|√)\\s+(.*)$", options: [.anchorsMatchLines])
        checklistRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            if let match = match, match.numberOfRanges >= 3 {
                let markerRange = match.range(at: 2)
                let marker = (text as NSString).substring(with: markerRange)
                let done = marker == "[x]" || marker == "√"
                // Hide up to the space after the marker
                let syntaxLen = (markerRange.location - match.range.location) + markerRange.length + 1
                let syntaxRange = NSRange(location: match.range.location, length: syntaxLen)
                ranges.append(MarkdownRange(range: match.range, style: .checklist(done: done), syntaxRanges: [syntaxRange]))
            }
        }
```

```swift
        // 7. Bullets (e.g., * Bullet)
        let bulletRegex = try! NSRegularExpression(pattern: "^(\\s*)[*+-]\\s+(.*)$", options: [.anchorsMatchLines])
        bulletRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            if let matchRange = match?.range, match?.numberOfRanges >= 3 {
                let spaceRange = match!.range(at: 1)
                // Syntax is leading space + bullet character + trailing space
                let syntaxRange = NSRange(location: matchRange.location, length: spaceRange.length + 2)
                ranges.append(MarkdownRange(range: matchRange, style: .bullet, syntaxRanges: [syntaxRange]))
            }
        }
```

- [ ] **Step 2: Run test to verify it passes**

Run: `swift test --filter MarkdownEngineTests`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add src/updoc/MarkdownEngine.swift
git commit -m "feat: populate syntaxRanges for all markdown elements"
```

---

### Task 3: Trigger applyStyles on Selection Change

**Files:**
- Modify: `src/updoc/EditorView.swift`

- [ ] **Step 1: Write the implementation**
Update `EditorView.Coordinator` in `src/updoc/EditorView.swift` to handle selection changes. Add the following method inside the `Coordinator` class:

```swift
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            // Trigger a restyle so we can hide/show syntax based on the new cursor position.
            // Using a very short debounce (50ms) to ensure smooth cursor movement.
            syncTask?.cancel()
            syncTask = Task {
                try? await Task.sleep(for: .milliseconds(50))
                if !Task.isCancelled {
                    applyStyles(to: textView)
                }
            }
        }
```

- [ ] **Step 2: Commit**

```bash
git add src/updoc/EditorView.swift
git commit -m "feat: restyle text on selection change to update syntax visibility"
```

---

### Task 4: Hide syntax characters conditionally in applyStyles

**Files:**
- Modify: `src/updoc/EditorView.swift`

- [ ] **Step 1: Write the implementation**
In `src/updoc/EditorView.swift`, modify `Coordinator.applyStyles(to:)` to conditionally hide the `syntaxRanges`.

Update the loop inside `applyStyles`:

```swift
            let selectedRange = textView.selectedRange()

            // Apply Markdown styles in reverse to avoid shifting ranges when we replace text with attachments
            for markdownRange in ranges.reversed() {
                if case .image(let urlString, let title) = markdownRange.style, 
                   let url = URL(string: urlString) {
                    renderImage(url: url, title: title, range: markdownRange.range, in: textView)
                } else {
                    let attributes = attributes(for: markdownRange.style)
                    textStorage.addAttributes(attributes, range: markdownRange.range)
                    
                    // Hide syntax if the cursor does NOT intersect the full markdownRange
                    let cursorIntersects = NSIntersectionRange(selectedRange, markdownRange.range).length > 0 || 
                                           (selectedRange.length == 0 && NSLocationInRange(selectedRange.location, markdownRange.range)) ||
                                           selectedRange.location == markdownRange.range.location + markdownRange.range.length // cursor right after element

                    if !cursorIntersects {
                        for syntaxRange in markdownRange.syntaxRanges {
                            textStorage.addAttributes([
                                .font: NSFont.systemFont(ofSize: 0.1),
                                .foregroundColor: NSColor.clear
                            ], range: syntaxRange)
                        }
                    }
                }
            }
```

- [ ] **Step 2: Build the project to verify it compiles**

Run: `swift build`
Expected: Successful build.

- [ ] **Step 3: Commit**

```bash
git add src/updoc/EditorView.swift
git commit -m "feat: hide markdown syntax dynamically based on cursor position"
```
