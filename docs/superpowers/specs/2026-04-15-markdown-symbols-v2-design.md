# Markdown List Symbols (SF Symbols & Indent Fix) Design

## Goal
Fix the missing indentation when list markers are hidden, and replace the basic unicode characters with clean Apple SF Symbols (`square`, `checkmark.square`, `circle.fill`) for a premium native look.

## Approach

### 1. Indent Fix: Stop Shrinking List Syntax
The reason indentation was lost is that `applyStyles` was setting the `NSFont.systemFont(ofSize: 0.1)` on the hidden list syntax `[ ] ` and `* `. Because it was shrunk to 0.1pt, it took up zero width, sliding the text to the left.
- We will modify `EditorView.Coordinator.applyStyles(to:)` so that for `.bullet` and `.checklist`, we apply `.foregroundColor: .clear` but we **DO NOT** shrink the font size. This preserves the exact horizontal spacing of the original markdown characters.
- Non-list syntax (like `**` for bold) will continue to be shrunk to 0.1pt to collapse horizontally as expected.

### 2. Draw SF Symbols in EditorLayoutManager
- In `EditorView.swift`, the `.listMarkerReplacement` attribute will now store a symbol name identifier instead of a literal string (e.g. `"bullet"`, `"checkbox_empty"`, `"checkbox_filled"`).
- In `EditorLayoutManager.swift`, we will look for this identifier. 
- We will load the corresponding SF Symbol using `NSImage(systemSymbolName:accessibilityDescription:)`:
  - `"bullet"` -> `"circle.fill"` (scaled down, or drawn with small bounds)
  - `"checkbox_empty"` -> `"square"`
  - `"checkbox_filled"` -> `"checkmark.square"`
- The layout manager will compute an appropriately sized square centered in the bounding rect of the transparent list marker string, and call `NSImage.draw(in:)` tinted with the theme's label color.

### Trade-offs
- Keeping the syntax characters at full width means cursor navigation through the transparent text requires pressing the arrow keys for each character (e.g. 4 times for `[ ] `). This is a standard and expected trade-off for preserving structural alignment without heavily modifying the `NSLayoutManager` glyph stream.