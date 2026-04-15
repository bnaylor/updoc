# Markdown List Symbols (Color & Alignment Fix) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the color and alignment of the SF Symbols used for list markers so that they dynamically match the text styling and align perfectly with the adjacent text.

**Architecture:** Modify `EditorLayoutManager` to fetch the `.foregroundColor` attribute for tinting. Calculate the vertical center using the `baseFont.ascender` and `baseFont.capHeight` to perfectly align with text, and center horizontally based on the bounding rect of just the first character.

**Tech Stack:** Swift, SwiftUI, AppKit (TextKit 1: `NSTextStorage`, `NSLayoutManager`, `NSTextContainer`, `NSTextView`)

---

### Task 1: Fix Symbol Color and Alignment

**Files:**
- Modify: `src/updoc/EditorLayoutManager.swift`

- [ ] **Step 1: Write the implementation**
In `src/updoc/EditorLayoutManager.swift`, update `drawBackground(forGlyphRange:at:)`.

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
                // 1. Get the dynamic color from the text attribute (fallback to labelColor)
                let color = textStorage.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? NSColor ?? .labelColor
                
                // 2. Get the bounding rect for just the FIRST character of the syntax (e.g. the '*' or '[')
                // This ensures horizontal alignment matches the start of the list item perfectly.
                let firstCharRange = NSRange(location: range.location, length: 1)
                let firstCharGlyphRange = self.glyphRange(forCharacterRange: firstCharRange, actualCharacterRange: nil)
                var firstCharRect = self.boundingRect(forGlyphRange: firstCharGlyphRange, in: textContainer)
                
                // Adjust for origin
                firstCharRect.origin.x += origin.x
                firstCharRect.origin.y += origin.y
                
                // Get the full line rect to help with baseline calculations if needed,
                // but the bounding rect of the first char is usually sufficient.
                
                // For bullets, we want a slightly smaller font size than checkboxes
                let isBullet = symbolName == "circle.fill"
                let fontSize = isBullet ? baseFont.pointSize * 0.4 : baseFont.pointSize
                
                // Create the SF Symbol image
                let config = NSImage.SymbolConfiguration(pointSize: fontSize, weight: .regular)
                if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
                    // Tint the image with the dynamic color
                    let tintedImage = NSImage(size: image.size)
                    tintedImage.lockFocus()
                    color.set()
                    let imageRect = NSRect(origin: .zero, size: image.size)
                    image.draw(in: imageRect, from: .zero, operation: .sourceOut, fraction: 1.0)
                    tintedImage.unlockFocus()
                    tintedImage.isTemplate = true
                    
                    // 3. Vertical Cap-Height Alignment
                    // The bounding rect's minY is usually the top of the line fragment.
                    // We want to center the symbol around the middle of the cap-height of the font.
                    // The cap-height center is located at: baseline - (capHeight / 2).
                    // In TextKit 1 macOS, `firstCharRect.minY + baseFont.ascender` gives the baseline.
                    let baselineY = firstCharRect.minY + baseFont.ascender
                    let capHeightCenterY = baselineY - (baseFont.capHeight / 2.0)
                    let yOffset = capHeightCenterY - (image.size.height / 2.0)
                    
                    // 4. Horizontal Alignment
                    // Center the symbol exactly in the middle of the first character's bounding box.
                    let xOffset = firstCharRect.midX - (image.size.width / 2.0)
                    
                    let drawRect = NSRect(x: xOffset, y: yOffset, width: image.size.width, height: image.size.height)
                    
                    tintedImage.draw(in: drawRect)
                }
            }
        }
    }
}
```

- [ ] **Step 2: Build and verify compilation**

Run: `swift build`
Expected: Success

- [ ] **Step 3: Commit**

```bash
git add src/updoc/EditorLayoutManager.swift
git commit -m "fix: dynamically color and align markdown list symbols"
```
