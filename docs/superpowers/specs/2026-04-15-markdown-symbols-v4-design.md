# Markdown List Symbols (Robust Ghost & Color Fix) Design

## Goal
Eliminate "ghost" symbols appearing in the right margin, fix incorrect black coloring of symbols, and achieve pixel-perfect vertical alignment.

## Approach

### 1. Fix Coloring with `.listMarkerColor`
The symbols were black because they were querying the `.foregroundColor` of the underlying text, which we set to `.clear` to hide the raw markdown. 
- In `EditorView.swift`, we will introduce `NSAttributedString.Key.listMarkerColor`.
- When applying styles, we will set this attribute to the original intended color (e.g., `.systemOrange` for bullets) *before* making the foreground clear.
- `EditorLayoutManager` will use this specific attribute to tint the SF Symbols.

### 2. Fix Ghosting (Drawing Redundancy)
TextKit 1 calls `drawBackground(forGlyphRange:at:)` multiple times for various reasons: drawing selection highlights, filling "extra" line space, or drawing the right-hand margin. 
- Our current `enumerateAttribute` code was finding the list marker attribute and re-drawing the symbol in every pass.
- **Fix:** In `EditorLayoutManager`, we will only execute the drawing code if `glyphsToShow.location <= range.location`. This ensures the symbol is only drawn during the pass that actually contains the start of the glyph range for that marker.

### 3. Precision Alignment
We will move away from `boundingRect.midY` and use more precise TextKit 1 metrics.
- We will fetch the `lineFragmentRect` for the glyph to get the stable vertical coordinate of the current line.
- We will use `layoutManager.location(forGlyphAt:)` to get the glyph's position relative to its line fragment.
- We will calculate the vertical center using the `baseFont.capHeight` and `baseFont.ascender` relative to the line's baseline.

## Implementation Details

### Attributes
```swift
extension NSAttributedString.Key {
    static let listMarkerReplacement = NSAttributedString.Key("listMarkerReplacement")
    static let listMarkerColor = NSAttributedString.Key("listMarkerColor")
}
```

### Layout Manager Drawing
```swift
textStorage.enumerateAttribute(.listMarkerReplacement, in: charRange, options: []) { value, range, _ in
    guard let symbolName = value as? String else { return }
    
    let glyphRange = self.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
    
    // GHOST FIX: Only draw if we are in the primary pass for this glyph range
    guard glyphsToShow.contains(glyphRange.location) else { return }
    
    // ... drawing logic ...
}
```