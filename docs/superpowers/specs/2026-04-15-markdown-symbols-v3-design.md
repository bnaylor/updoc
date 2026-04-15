# Markdown List Symbols (Color & Alignment Fix) Design

## Goal
Fix the color and alignment of the SF Symbols used for list markers so that they dynamically match the text styling (e.g. orange bullets) and align perfectly with the adjacent text baseline/cap-height.

## Approach

### 1. Dynamic Foreground Color
Currently, `EditorLayoutManager` hardcodes `NSColor.labelColor` for tinting the SF Symbol images.
- We will modify `EditorLayoutManager.drawBackground(forGlyphRange:at:)` to query the `textStorage` for the `.foregroundColor` attribute at the `characterRange.location`.
- If a color is found (e.g. `.systemOrange` for bullets or `.secondaryLabelColor` for checked items), we will use that color to tint the `NSImage`. If no color is found, we fall back to `.labelColor`.

### 2. Vertical Cap-Height Alignment
Centering the symbol within the entire line's bounding rect (`boundingRect.midY`) includes line spacing and ascenders/descenders, pushing the symbol off-center relative to the text.
- We will calculate the vertical center using the `baseFont.capHeight` or simply align the symbol's frame such that its center matches the `baseFont`'s cap-height center relative to the bounding rect's baseline.
- `textContainer` padding or baseline offset can be derived from the `baseFont` metrics.
  - A simpler approach: use `layoutManager.lineFragmentRect` and align based on `baseFont.ascender` and `baseFont.descender` relative to the baseline.
  - `let baselineOffset = layoutManager.typesetterBehavior == .latest ? layoutManager.defaultLineHeight(for: baseFont) - baseFont.ascender : 0` // Or similar TextKit 1 baseline math.
  - Or, an empirical approach that is very robust: `let yCenter = boundingRect.minY + baseFont.ascender - (baseFont.capHeight / 2.0)` 

### 3. Horizontal Alignment
Currently, the symbol is aligned slightly to the right of the full `syntaxRange`'s bounding box (`[ ] ` or `* `).
- We will fetch the bounding rect for just the FIRST character of the `syntaxRange` (the `[` or `*`).
- `let firstCharGlyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: range.location, length: 1), actualCharacterRange: nil)`
- `let firstCharRect = layoutManager.boundingRect(forGlyphRange: firstCharGlyphRange, in: textContainer)`
- We will horizontally center the SF Symbol inside `firstCharRect`, so it perfectly replaces the original character visually.