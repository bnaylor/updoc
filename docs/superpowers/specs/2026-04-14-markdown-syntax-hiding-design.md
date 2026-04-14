# Markdown Syntax Hiding Design

## Goal
Implement a NotePlan-like editing experience where markdown syntax characters (e.g., `**`, `#`, `[ ]`) are visually hidden when the cursor is not actively on or inside the element. When the cursor enters the element, the syntax characters reappear to allow editing.

## Approach: Attribute-based Font Shrinking
We will dynamically apply a very small, transparent font to the specific syntax character ranges when the cursor is not actively focused on the markdown element. 

### 1. Syntax Range Identification
Currently, `MarkdownEngine.swift` parses the full text and returns `MarkdownRange` objects containing the full element range and its `MarkdownStyle`. 

We will modify `MarkdownRange` to include `syntaxRanges: [NSRange]`, which define the exact positions of the formatting characters within the full element. For example, for the bold string `**text**`, the `syntaxRanges` would be `[NSRange(location: 0, length: 2), NSRange(location: 6, length: 2)]`.

### 2. Dynamic Styling based on Selection
In `EditorView.swift` (`Coordinator.applyStyles(to:)`):
- We will fetch the current cursor selection (`textView.selectedRange()`).
- When applying styles to each `MarkdownRange`:
  - If the cursor intersects the full `range` of the element, we apply normal styles, rendering the syntax characters visible.
  - If the cursor does NOT intersect the full `range`, we apply a "hidden" style (e.g., `NSFont.systemFont(ofSize: 0.1)` and `.foregroundColor: .clear`) to all ranges specified in `syntaxRanges`, while keeping the element content styled normally.

### 3. Cursor Tracking
We must ensure that cursor movement triggers a restyle.
- We will implement `textViewDidChangeSelection(_:)` in `EditorView.Coordinator`.
- Inside this delegate method, we will trigger a style update. To maintain performance, this should be slightly debounced, similar to the existing text change debounce, but fast enough to feel instantaneous (e.g., 50ms-100ms or synchronous for selection changes alone if lightweight).

### 4. Trade-offs and Considerations
- **Copy/Paste:** Copying the text will still copy the full markdown string, as the characters remain in the `NSTextStorage`.
- **Undo History:** Using attributes for visual hiding does not modify the raw text, avoiding any disruption to the built-in macOS undo manager.
- **Cursor Navigation:** Moving the cursor through a hidden element might require an extra arrow key press (as it navigates over the 0.1pt font character). This matches typical behavior for this approach and is generally acceptable.
