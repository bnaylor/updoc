# Markdown List Symbols Design

## Goal
Enhance the markdown syntax hiding behavior so that when list markers (bullets `*`, `+`, `-` and checkboxes `[ ]`, `[x]`, `√`) are hidden from the user (because the cursor is elsewhere), they are visually replaced by clean, single-character symbols (e.g., `•`, `☐`, `☑`). This creates a cleaner "rendered" look while preserving the exact underlying markdown text.

## Approach: Custom Layout Manager (Visual Overlay)
We will continue to hide the raw markdown syntax by applying a 0.1pt clear font to the `syntaxRanges`. However, we will introduce a custom `NSLayoutManager` that intercepts the drawing cycle to draw a replacement symbol over the hidden text.

### 1. Custom Attribute
We will define a custom text attribute key:
```swift
extension NSAttributedString.Key {
    static let listMarkerReplacement = NSAttributedString.Key("listMarkerReplacement")
}
```

### 2. Style Application
In `EditorView.Coordinator.applyStyles(to:)`:
- When processing `.bullet` or `.checklist` styles, if the cursor is outside the element, we hide the syntax as before.
- Additionally, we will apply the `.listMarkerReplacement` attribute to the first character of the `syntaxRange`.
  - For `.bullet`: we will pass the string `"•"`.
  - For `.checklist(let done)`: we will pass `"☑"` if `done`, else `"☐"`.

### 3. EditorLayoutManager
We will create a subclass of `NSLayoutManager` called `EditorLayoutManager`.
- We will override `drawBackground(forGlyphRange:at:)`.
- For each glyph in the range, we will query the text storage for the `.listMarkerReplacement` attribute.
- If a replacement string is found, we will compute the drawing point based on the glyph's bounding rect and draw the string using `NSString.draw(at:withAttributes:)` with the standard theme font and label color.

### 4. TextKit Stack Setup
In `EditorView.makeNSView(context:)`, the current implementation uses the convenience method `NSTextView.scrollableTextView()`. We need to manually construct the TextKit 1 stack to inject our layout manager:
```swift
let textStorage = NSTextStorage()
let layoutManager = EditorLayoutManager()
textStorage.addLayoutManager(layoutManager)
let textContainer = NSTextContainer(containerSize: NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude))
textContainer.widthTracksTextView = true
layoutManager.addTextContainer(textContainer)
let textView = EditorTextView(frame: .zero, textContainer: textContainer)
```
*Note:* We must ensure `textStorage.delegate` and other textView configurations remain intact during this refactor.

## Trade-offs
- This approach requires manual TextKit stack setup, bypassing some convenience initializers, but is fully supported and standard for advanced text rendering in macOS.
- Cursor movement remains smooth because the underlying text is untouched. The only anomaly is that navigating over a `☐` requires two arrow-key presses (for `[` and `]`), which is acceptable and consistent with the existing hiding behavior.