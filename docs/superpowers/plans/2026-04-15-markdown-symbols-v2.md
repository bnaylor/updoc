# Markdown List Symbols (SF Symbols & Indent Fix) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the missing indentation when list markers are hidden and replace unicode characters with clean Apple SF Symbols (`square`, `checkmark.square`, `circle.fill`).

**Architecture:** We will modify `applyStyles` to NOT shrink the font for list markers (keeping them transparent but full-width). Then we will modify `EditorLayoutManager` to draw `NSImage(systemSymbolName:)` instead of `NSString.draw`.

**Tech Stack:** Swift, SwiftUI, AppKit (TextKit 1: `NSTextStorage`, `NSLayoutManager`, `NSTextContainer`, `NSTextView`)

---

### Task 1: Fix Indentation in applyStyles

**Files:**
- Modify: `src/updoc/EditorView.swift`

- [ ] **Step 1: Write the implementation**
In `src/updoc/EditorView.swift`, modify `Coordinator.applyStyles(to:)`.
Change the hidden logic so that non-list elements are shrunk to 0.1pt font, but list elements are ONLY made transparent. Change the `listMarkerReplacement` values to SF Symbol identifiers.

```swift
                    if !cursorIntersects {
                        for (index, syntaxRange) in markdownRange.syntaxRanges.enumerated() {
                            var isListMarker = false
                            var hiddenAttributes: [NSAttributedString.Key: Any] = [
                                .foregroundColor: NSColor.clear
                            ]
                            
                            // Apply replacement symbol only to the first syntax range of list items
                            if index == 0 {
                                switch markdownRange.style {
                                case .bullet:
                                    isListMarker = true
                                    hiddenAttributes[.listMarkerReplacement] = "circle.fill"
                                case .checklist(let done):
                                    isListMarker = true
                                    hiddenAttributes[.listMarkerReplacement] = done ? "checkmark.square" : "square"
                                default:
                                    break
                                }
                            }
                            
                            // Only shrink font for non-list markers so list markers preserve indentation
                            if !isListMarker {
                                hiddenAttributes[.font] = NSFont.systemFont(ofSize: 0.1)
                            }
                            
                            textStorage.addAttributes(hiddenAttributes, range: syntaxRange)
                        }
                    }
```

- [ ] **Step 2: Commit**

```bash
git add src/updoc/EditorView.swift
git commit -m "feat: preserve indentation for transparent list markers"
```

---

### Task 2: Draw SF Symbols in EditorLayoutManager

**Files:**
- Modify: `src/updoc/EditorLayoutManager.swift`

- [ ] **Step 1: Write the implementation**
Modify `EditorLayoutManager.swift` to draw SF Symbols instead of text. The symbols should be tinted with the theme's label color and centered in the bounding rect. We will draw them smaller than the full font bounding box.

```swift
import AppKit

class EditorLayoutManager: NSLayoutManager {
    var baseFont: NSFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
    
    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
        
        guard let textStorage = self.textStorage, let textContainer = self.textContainers.first else { return }
        let charRange = self.characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        
        textStorage.enumerateAttribute(.listMarkerReplacement, in: charRange, options: []) { value, range, _ in
            if let symbolName = value as? String {
                let glyphRange = self.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                var boundingRect = self.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                
                // Adjust for origin
                boundingRect.origin.x += origin.x
                boundingRect.origin.y += origin.y
                
                // Create the SF Symbol image
                let config = NSImage.SymbolConfiguration(font: baseFont)
                if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
                    // Tint the image with the label color
                    let tintedImage = NSImage(size: image.size)
                    tintedImage.lockFocus()
                    NSColor.labelColor.set()
                    let imageRect = NSRect(origin: .zero, size: image.size)
                    image.draw(in: imageRect, from: .zero, operation: .sourceOut, fraction: 1.0)
                    tintedImage.unlockFocus()
                    tintedImage.isTemplate = true
                    
                    // Center the symbol in the bounding rect vertically, but align left horizontally (with a tiny padding)
                    // The bounding rect is the size of the whole hidden markdown string (e.g. "[ ] ")
                    let yOffset = boundingRect.midY - (image.size.height / 2.0)
                    let xOffset = boundingRect.minX + 2.0 // Small left padding
                    let drawRect = NSRect(x: xOffset, y: yOffset, width: image.size.width, height: image.size.height)
                    
                    tintedImage.draw(in: drawRect)
                }
            }
        }
    }
}
```

- [ ] **Step 2: Build and Test**

Run: `swift build`
Expected: Success

- [ ] **Step 3: Commit**

```bash
git add src/updoc/EditorLayoutManager.swift
git commit -m "feat: render list symbols using SF Symbols"
```
