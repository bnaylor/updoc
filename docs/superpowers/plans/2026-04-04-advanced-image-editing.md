# Advanced Image Editing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement native image editing in updoc using macOS Markup via `QLPreviewPanel`.

**Architecture:** 
The `EditorView.Coordinator` will act as the `QLPreviewPanelDataSource` and `QLPreviewPanelDelegate`. When a user double-clicks or selects "Edit Image..." from the context menu, the `QLPreviewPanel` will open the local asset file. Edits made in the panel will overwrite the local file, after which we will invalidate the cache and refresh the view.

**Tech Stack:** Swift, SwiftUI, AppKit, QuickLook (QLPreviewPanel).

---

### Task 1: Update RemoteImageCache to Support Local Refresh

**Files:**
- Modify: `src/updoc/RemoteImageCache.swift`

- [ ] **Step 1: Add a clear method to the cache**

```swift
    func clear(for url: URL) {
        cache.removeObject(forKey: url as NSURL)
        loadingTasks[url] = nil
    }
```

- [ ] **Step 2: Commit**

```bash
git add src/updoc/RemoteImageCache.swift
git commit -m "feat: add clear method to RemoteImageCache"
```

### Task 2: Enhance EditorTextView for Image Interaction

**Files:**
- Modify: `src/updoc/EditorView.swift`

- [ ] **Step 1: Add double-click handling for images**

Update `EditorTextView` to detect double-clicks on attachments and notify the coordinator.

```swift
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            let point = self.convert(event.locationInWindow, from: nil)
            let index = self.layoutManager?.characterIndex(for: point, in: self.textContainer!, fractionOfDistanceBetweenInsertionPoints: nil)
            
            if let index = index, index < self.textStorage?.length ?? 0 {
                if let attachment = self.textStorage?.attribute(.attachment, at: index, effectiveRange: nil) as? RemoteImageAttachment {
                    onEditRequested?(attachment)
                    return
                }
            }
        }
        super.mouseDown(with: event)
    }
```

- [ ] **Step 2: Add "Edit Image..." to context menu**

```swift
    // In menu(for:)
    if let attachment = self.textStorage?.attribute(.attachment, at: range.location, effectiveRange: nil) as? RemoteImageAttachment {
        menu.addItem(NSMenuItem.separator())
        let editItem = NSMenuItem(title: "✎ Edit Image...", action: #selector(editImageAction(_:)), keyEquivalent: "")
        editItem.target = self
        editItem.representedObject = attachment
        menu.addItem(editItem)
    }
```

- [ ] **Step 3: Commit**

```bash
git add src/updoc/EditorView.swift
git commit -m "feat: add double-click and context menu support for image editing"
```

### Task 3: Implement QLPreviewPanel Integration in Coordinator

**Files:**
- Modify: `src/updoc/EditorView.swift`

- [ ] **Step 1: Make Coordinator conform to QLPreviewPanel protocols**

```swift
    class Coordinator: NSObject, NSTextViewDelegate, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
        var editingAttachment: RemoteImageAttachment?
        
        // MARK: - QLPreviewPanelDataSource
        func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { 1 }
        func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
            editingAttachment?.url as NSURL?
        }
        
        // MARK: - QLPreviewPanelDelegate
        func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool { false }
        func previewPanel(_ panel: QLPreviewPanel!, sourceFrameOnScreenFor item: QLPreviewItem!) -> NSRect { .zero }
        
        // Enable Markup
        func previewPanel(_ panel: QLPreviewPanel!, shouldManageEditingModeOf item: QLPreviewItem!) -> Bool { true }
        func previewPanel(_ panel: QLPreviewPanel!, didUpdateContentsOf item: QLPreviewItem!) {
            guard let url = editingAttachment?.url else { return }
            Task {
                await RemoteImageCache.shared.clear(for: url)
                await MainActor.run {
                    // Trigger redraw
                    if let textView = NSApp.keyWindow?.firstResponder as? NSTextView {
                        applyStyles(to: textView)
                    }
                }
            }
        }
    }
```

- [ ] **Step 2: Add method to open the panel**

```swift
    func openEditor(for attachment: RemoteImageAttachment) {
        self.editingAttachment = attachment
        if let panel = QLPreviewPanel.shared() {
            panel.dataSource = self
            panel.delegate = self
            panel.makeKeyAndOrderFront(nil)
        }
    }
```

- [ ] **Step 3: Commit**

```bash
git add src/updoc/EditorView.swift
git commit -m "feat: implement QLPreviewPanel integration for image editing"
```

### Task 4: Final Glue and Verification

**Files:**
- Modify: `src/updoc/EditorView.swift`

- [ ] **Step 1: Connect EditorTextView's onEditRequested to Coordinator**

- [ ] **Step 2: Verify the feature**
  - Launch updoc
  - Drop an image into a note
  - Double-click the image
  - Verify Markup tools appear
  - Make an edit (e.g., draw an arrow)
  - Click "Done"
  - Verify the image updates in the editor

- [ ] **Step 3: Commit**

```bash
git add src/updoc/EditorView.swift
git commit -m "feat: finalize image editing integration"
```
