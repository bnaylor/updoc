# Markdown List Symbols Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Visually replace hidden markdown list markers (bullets and checkboxes) with single-character symbols like `•`, `☐`, `☑` using a custom layout manager.

**Architecture:** We will define a custom `NSAttributedString.Key` and subclass `NSLayoutManager` to draw these replacement strings over the hidden text. We will manually construct the TextKit 1 stack in `EditorView` to use our custom layout manager.

**Tech Stack:** Swift, SwiftUI, AppKit (TextKit 1: `NSTextStorage`, `NSLayoutManager`, `NSTextContainer`, `NSTextView`)

---

### Task 1: Define Custom Attribute

**Files:**
- Modify: `src/updoc/EditorView.swift`

- [ ] **Step 1: Write the implementation**
Open `src/updoc/EditorView.swift` and add the custom attribute key at the top of the file (after imports):

```swift
extension NSAttributedString.Key {
    static let listMarkerReplacement = NSAttributedString.Key("listMarkerReplacement")
}
```

- [ ] **Step 2: Commit**

```bash
git add src/updoc/EditorView.swift
git commit -m "feat: define listMarkerReplacement attribute key"
```

---

### Task 2: Create EditorLayoutManager

**Files:**
- Create: `src/updoc/EditorLayoutManager.swift`

- [ ] **Step 1: Write the implementation**
Create `src/updoc/EditorLayoutManager.swift` with the custom drawing logic. It needs to know the base font size to draw the symbols correctly, so we'll give it a property for the base font.

```swift
import AppKit

class EditorLayoutManager: NSLayoutManager {
    var baseFont: NSFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
    
    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
        
        guard let textStorage = self.textStorage, let textContainer = self.textContainers.first else { return }
        let charRange = self.characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        
        textStorage.enumerateAttribute(.listMarkerReplacement, in: charRange, options: []) { value, range, _ in
            if let replacementString = value as? String {
                let glyphRange = self.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                var boundingRect = self.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                
                // Adjust for origin
                boundingRect.origin.x += origin.x
                boundingRect.origin.y += origin.y
                
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: baseFont,
                    .foregroundColor: NSColor.labelColor
                ]
                
                // Vertically center the replacement character roughly inside the bounding rect
                let stringSize = (replacementString as NSString).size(withAttributes: attributes)
                let drawPoint = NSPoint(
                    x: boundingRect.minX,
                    y: boundingRect.midY - (stringSize.height / 2.0)
                )
                
                (replacementString as NSString).draw(at: drawPoint, withAttributes: attributes)
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add src/updoc/EditorLayoutManager.swift
git commit -m "feat: implement EditorLayoutManager for drawing custom list symbols"
```

---

### Task 3: Setup TextKit 1 Stack in EditorView

**Files:**
- Modify: `src/updoc/EditorView.swift`

- [ ] **Step 1: Write the implementation**
In `src/updoc/EditorView.swift`, modify `makeNSView(context:)` to manually build the TextKit stack so we can use our `EditorLayoutManager`.

Find this block:
```swift
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        // ... background setup ...
        
        let textView = EditorTextView(frame: .zero)
        // ... text view setup ...
```

Replace it with:
```swift
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]
        
        let textStorage = NSTextStorage()
        let layoutManager = EditorLayoutManager()
        layoutManager.baseFont = themeManager.font
        textStorage.addLayoutManager(layoutManager)
        
        let contentSize = scrollView.contentSize
        let textContainer = NSTextContainer(containerSize: NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)
        
        let textView = EditorTextView(frame: CGRect(origin: .zero, size: contentSize), textContainer: textContainer)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.isRichText = false
        
        // Add some padding
        textView.textContainerInset = NSSize(width: 20, height: 20)
        
        scrollView.documentView = textView
```

Also, update `updateNSView` to ensure `baseFont` is updated if the theme changes:
```swift
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        
        // Update layout manager's base font
        if let layoutManager = textView.layoutManager as? EditorLayoutManager {
            layoutManager.baseFont = themeManager.font
        }
        
        // ... rest of updateNSView
```

- [ ] **Step 2: Build to verify compilation**

Run: `swift build`
Expected: Success

- [ ] **Step 3: Commit**

```bash
git add src/updoc/EditorView.swift
git commit -m "feat: manually construct TextKit stack to use EditorLayoutManager"
```

---

### Task 4: Apply listMarkerReplacement in applyStyles

**Files:**
- Modify: `src/updoc/EditorView.swift`

- [ ] **Step 1: Write the implementation**
In `src/updoc/EditorView.swift`, inside `Coordinator.applyStyles(to:)`, we need to apply `.listMarkerReplacement` to the hidden syntax when it's a bullet or checklist.

Find the block where we hide syntax:
```swift
                    if !cursorIntersects {
                        for syntaxRange in markdownRange.syntaxRanges {
                            textStorage.addAttributes([
                                .font: NSFont.systemFont(ofSize: 0.1),
                                .foregroundColor: NSColor.clear
                            ], range: syntaxRange)
                        }
                    }
```

Update it to check the style and add the replacement character to the FIRST syntax range:
```swift
                    if !cursorIntersects {
                        for (index, syntaxRange) in markdownRange.syntaxRanges.enumerated() {
                            var hiddenAttributes: [NSAttributedString.Key: Any] = [
                                .font: NSFont.systemFont(ofSize: 0.1),
                                .foregroundColor: NSColor.clear
                            ]
                            
                            // Apply replacement symbol only to the first syntax range of list items
                            if index == 0 {
                                switch markdownRange.style {
                                case .bullet:
                                    hiddenAttributes[.listMarkerReplacement] = "•"
                                case .checklist(let done):
                                    hiddenAttributes[.listMarkerReplacement] = done ? "☑" : "☐"
                                default:
                                    break
                                }
                            }
                            
                            textStorage.addAttributes(hiddenAttributes, range: syntaxRange)
                        }
                    }
```

- [ ] **Step 2: Build and Test**

Run: `swift build`
Expected: Success

- [ ] **Step 3: Commit**

```bash
git add src/updoc/EditorView.swift
git commit -m "feat: apply listMarkerReplacement attribute for hidden bullets and checklists"
```
