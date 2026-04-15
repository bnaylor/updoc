# Markdown List Symbols (Robust Ghost & Color Fix) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate "ghost" symbols appearing in the right margin, fix incorrect black coloring of symbols, and achieve pixel-perfect vertical alignment.

**Architecture:** Use a dedicated `.listMarkerColor` attribute to pass colors to the layout manager. Add intersection checks in `drawBackground` to prevent redundant drawing (ghosts). Use precise line baseline metrics for alignment.

**Tech Stack:** Swift, SwiftUI, AppKit (TextKit 1)

---

### Task 1: Update Attributes and Styles in EditorView

**Files:**
- Modify: `src/updoc/EditorView.swift`

- [ ] **Step 1: Write the implementation**
Update `EditorView.swift` to define `.listMarkerColor` and apply it in `applyStyles`.

```swift
extension NSAttributedString.Key {
    static let listMarkerReplacement = NSAttributedString.Key("listMarkerReplacement")
    static let listMarkerColor = NSAttributedString.Key("listMarkerColor") // New attribute
}
```

In `Coordinator.applyStyles(to:)`:
```swift
                            // Apply replacement symbol and color only to the first syntax range of list items
                            if index == 0 {
                                switch markdownRange.style {
                                case .bullet:
                                    isListMarker = true
                                    hiddenAttributes[.listMarkerReplacement] = "circle.fill"
                                    hiddenAttributes[.listMarkerColor] = NSColor.systemOrange // Pass the color
                                case .checklist(let done):
                                    isListMarker = true
                                    hiddenAttributes[.listMarkerReplacement] = done ? "checkmark.square" : "square"
                                    // Get color for checklist (gray if done, label if not)
                                    let checklistAttributes = attributes(for: markdownRange.style)
                                    hiddenAttributes[.listMarkerColor] = checklistAttributes[.foregroundColor] as? NSColor ?? NSColor.labelColor
                                default:
                                    break
                                }
                            }
```

- [ ] **Step 2: Commit**

```bash
git add src/updoc/EditorView.swift
git commit -m "feat: add listMarkerColor attribute to pass colors through transparent text"
```

---

### Task 2: Robust Drawing in EditorLayoutManager

**Files:**
- Modify: `src/updoc/EditorLayoutManager.swift`

- [ ] **Step 1: Write the implementation**
Update `EditorLayoutManager.swift` to use the new color attribute, implement the ghost fix, and refine alignment.

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
                
                // GHOST FIX: Only draw if the current pass actually contains the first glyph of the marker.
                // TextKit calls drawBackground multiple times per line (selection, extra space, etc.)
                guard glyphsToShow.contains(glyphRange.location) else { return }
                
                // 1. Get the dynamic color from our dedicated attribute
                let color = textStorage.attribute(.listMarkerColor, at: range.location, effectiveRange: nil) as? NSColor ?? .labelColor
                
                // 2. Get precise character position using the line baseline
                var lineRect = self.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
                let glyphLocation = self.location(forGlyphAt: glyphRange.location)
                
                // Adjust for origin
                lineRect.origin.x += origin.x
                lineRect.origin.y += origin.y
                
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
                    
                    // 3. Vertical Baseline Alignment
                    // The baseline is at lineRect.minY + baseFont.ascender.
                    // We center the symbol around the middle of the cap height of the font.
                    let baselineY = lineRect.minY + baseFont.ascender
                    let capHeightCenterY = baselineY - (baseFont.capHeight / 2.0)
                    let yOffset = capHeightCenterY - (image.size.height / 2.0)
                    
                    // 4. Horizontal Alignment
                    // The glyphLocation.x is the offset from the lineFragmentRect.minX.
                    // We center the symbol horizontally around that point + half the width of a typical char.
                    // Or just use the center of the first char's bounding box.
                    let firstCharGlyphRange = NSRange(location: glyphRange.location, length: 1)
                    let firstCharRect = self.boundingRect(forGlyphRange: firstCharGlyphRange, in: textContainer)
                    let xOffset = lineRect.minX + glyphLocation.x + (firstCharRect.width / 2.0) - (image.size.width / 2.0)
                    
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
git commit -m "fix: eliminate ghost symbols and achieve precise alignment/coloring"
```
