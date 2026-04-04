import SwiftUI
import AppKit
import UniformTypeIdentifiers
@preconcurrency import QuickLookUI

@MainActor
class EditorTextView: NSTextView {
    var onFileDropped: ((URL, NSTextView) -> Void)?
    var onPromoteAction: ((String) -> Void)?
    var onEditRequested: ((RemoteImageAttachment) -> Void)?
    
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()
        
        let range = self.selectedRange()
        if range.length > 0 {
            let selectedText = (self.string as NSString).substring(with: range)
            let trimmed = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Check if it's a checklist item
            if trimmed.hasPrefix("[ ]") || trimmed.hasPrefix("[x]") || trimmed.hasPrefix("√") {
                menu.addItem(NSMenuItem.separator())
                let promoteItem = NSMenuItem(title: "⚡ Promote to Action Item", action: #selector(promoteToTask(_:)), keyEquivalent: "")
                promoteItem.target = self
                menu.addItem(promoteItem)
            }
        }
        
        // Find if there's an image at the click location
        let point = self.convert(event.locationInWindow, from: nil)
        let index = self.layoutManager?.characterIndex(for: point, in: self.textContainer!, fractionOfDistanceBetweenInsertionPoints: nil)
        
        if let index = index, index < self.textStorage?.length ?? 0 {
            if let attachment = self.textStorage?.attribute(.attachment, at: index, effectiveRange: nil) as? RemoteImageAttachment {
                menu.addItem(NSMenuItem.separator())
                let editItem = NSMenuItem(title: "✎ Edit Image...", action: #selector(editImageAction(_:)), keyEquivalent: "")
                editItem.target = self
                editItem.representedObject = attachment
                menu.addItem(editItem)
            }
        }
        
        return menu
    }
    
    @objc func editImageAction(_ sender: NSMenuItem) {
        if let attachment = sender.representedObject as? RemoteImageAttachment {
            onEditRequested?(attachment)
        }
    }
    
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
    
    @objc func promoteToTask(_ sender: Any) {
        let range = self.selectedRange()
        let selectedText = (self.string as NSString).substring(with: range)
        onPromoteAction?(selectedText)
    }
    
    // QuickLook support
    nonisolated override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        return true
    }
    
    nonisolated override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated {
            panel.delegate = (self.delegate as? QLPreviewPanelDelegate)
            panel.dataSource = (self.delegate as? QLPreviewPanelDataSource)
        }
    }
    
    nonisolated override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated {
            panel.delegate = nil
            panel.dataSource = nil
        }
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pboard = sender.draggingPasteboard
        if let urls = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in urls {
                onFileDropped?(url, self)
            }
            return true
        }
        return super.performDragOperation(sender)
    }
}

struct EditorView: NSViewRepresentable {
    @Binding var text: String
    @Binding var assetIds: [String]
    @Binding var selectionRange: NSRange?
    var onPromoteAction: ((String) -> Void)?
    var onEditRequested: ((RemoteImageAttachment) -> Void)?
    @Environment(ThemeManager.self) private var themeManager
    private let engine = MarkdownEngine()

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = EditorTextView(frame: .zero)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        
        scrollView.documentView = textView
        context.coordinator.textView = textView
        
        textView.delegate = context.coordinator
        textView.onFileDropped = { url, targetTextView in
            context.coordinator.handleFileDrop(url: url, in: targetTextView)
        }
        textView.onPromoteAction = { selectedText in
            self.onPromoteAction?(selectedText)
        }
        textView.onEditRequested = { [weak coordinator = context.coordinator] attachment in
            if let onEditRequested = self.onEditRequested {
                onEditRequested(attachment)
            } else {
                coordinator?.openEditor(for: attachment)
            }
        }
        textView.font = themeManager.font
        textView.isEditable = true
        textView.isSelectable = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isContinuousSpellCheckingEnabled = true
        textView.allowsUndo = true
        
        // Ensure it can become first responder
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }
        
        // Register for dropped image files
        textView.registerForDraggedTypes([.fileURL])
        
        // Use the theme's font as the base
        textView.typingAttributes = [.font: themeManager.font]
        
        NotificationCenter.default.addObserver(forName: .focusEditor, object: nil, queue: .main) { _ in
            textView.window?.makeFirstResponder(textView)
        }
        
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        
        // Ensure theme font is applied
        if textView.font != themeManager.font {
            textView.font = themeManager.font
            textView.typingAttributes = [.font: themeManager.font]
            context.coordinator.applyStyles(to: textView)
        }
        
        let currentMarkdown = context.coordinator.convertToMarkdown(from: textView.textStorage ?? NSAttributedString())
        if currentMarkdown != text {
            textView.string = text
            context.coordinator.applyStyles(to: textView)
        }
        
        if let range = selectionRange {
            textView.setSelectedRange(range)
            textView.scrollRangeToVisible(range)
            
            // Dispatch to avoid "modifying state during view update"
            DispatchQueue.main.async {
                self.selectionRange = nil
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    @MainActor
    class Coordinator: NSObject, NSTextViewDelegate, @preconcurrency QLPreviewPanelDataSource, @preconcurrency QLPreviewPanelDelegate {
        var parent: EditorView
        private let autocompleteManager = AutocompleteManager()
        private var syncTask: Task<Void, Never>?
        var editingAttachment: RemoteImageAttachment?
        weak var textView: NSTextView?

        init(_ parent: EditorView) {
            self.parent = parent
        }

        func openEditor(for attachment: RemoteImageAttachment) {
            self.editingAttachment = attachment
            if let textView = self.textView {
                textView.window?.makeFirstResponder(textView)
            }
            if let panel = QLPreviewPanel.shared() {
                panel.dataSource = self
                panel.delegate = self
                panel.makeKeyAndOrderFront(nil)
            }
        }
        
        // MARK: - QLPreviewPanelDataSource
        func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
            editingAttachment != nil ? 1 : 0
        }
        
        func previewPanel(_ panel: QLPreviewPanel!) -> QLPreviewItem! {
            editingAttachment
        }
        
        func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
            editingAttachment
        }
        
        // MARK: - QLPreviewPanelDelegate
        func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
            false
        }
        
        func previewPanel(_ panel: QLPreviewPanel!, sourceFrameOnScreenFor item: QLPreviewItem!) -> NSRect {
            guard let attachment = item as? RemoteImageAttachment,
                  let textView = self.textView,
                  let textStorage = textView.textStorage else { return .zero }
            
            var frame: NSRect = .zero
            textStorage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: textStorage.length)) { value, range, stop in
                if let found = value as? RemoteImageAttachment, found === attachment {
                    let layoutManager = textView.layoutManager!
                    let textContainer = textView.textContainer!
                    let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                    let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                    let containerOrigin = textView.textContainerOrigin
                    let viewRect = rect.offsetBy(dx: containerOrigin.x, dy: containerOrigin.y)
                    let windowRect = textView.convert(viewRect, to: nil)
                    frame = textView.window?.convertToScreen(windowRect) ?? .zero
                    stop.pointee = true
                }
            }
            return frame
        }
        
        // Enable Markup
        func previewPanel(_ panel: QLPreviewPanel!, shouldManageEditingModeOf item: QLPreviewItem!) -> Bool {
            true
        }
        
        func previewPanel(_ panel: QLPreviewPanel!, didUpdateContentsOf item: QLPreviewItem!) {
            guard let attachment = item as? RemoteImageAttachment else { return }
            let url = attachment.url
            
            Task { @MainActor in
                RemoteImageCache.shared.clear(for: url)
                if let image = await RemoteImageCache.shared.image(for: url) {
                    attachment.image = image
                    // Find the attachment range in our text storage to redraw it
                    if let textView = self.textView, let textStorage = textView.textStorage {
                        textStorage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: textStorage.length)) { value, range, stop in
                            if let found = value as? RemoteImageAttachment, found === attachment {
                                textView.layoutManager?.invalidateDisplay(forCharacterRange: range)
                                stop.pointee = true
                            }
                        }
                    }
                }
            }
        }

        func handleFileDrop(url: URL, in textView: NSTextView) {
            // Check if it's an image using UTType
            let type = UTType(filenameExtension: url.pathExtension) ?? .data
            guard type.conforms(to: .image) else { return }
            
            Task {
                do {
                    let data = try Data(contentsOf: url)
                    let assetId = try await ImageLibraryManager.shared.saveImage(data, filename: url.lastPathComponent)
                    
                    // Update assetIds
                    await MainActor.run {
                        var currentAssets = self.parent.assetIds
                        currentAssets.append(assetId)
                        self.parent.assetIds = currentAssets
                        
                        // Insert placeholder at cursor or end
                        let placeholder = "\n![[\(assetId)]]\n"
                        let range = textView.selectedRange()
                        if textView.shouldChangeText(in: range, replacementString: placeholder) {
                            textView.insertText(placeholder, replacementRange: range)
                            textView.didChangeText()
                        }
                    }
                } catch {
                    print("Error saving dropped image: \(error)")
                }
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            // Handle √ shortcut
            checkForCheckmarkShortcut(in: textView)
            
            if let textStorage = textView.textStorage {
                self.parent.text = convertToMarkdown(from: textStorage)
            } else {
                self.parent.text = textView.string
            }
            
            // Basic trigger check
            checkForAutocompleteTrigger(in: textView)
            
            // Debounced style application
            syncTask?.cancel()
            syncTask = Task {
                try? await Task.sleep(for: .milliseconds(300))
                if !Task.isCancelled {
                    applyStyles(to: textView)
                }
            }
        }
        
        private func checkForCheckmarkShortcut(in textView: NSTextView) {
            let selectedRange = textView.selectedRange()
            guard selectedRange.location > 0 else { return }
            
            let text = textView.string as NSString
            let lineRange = text.lineRange(for: NSRange(location: selectedRange.location - 1, length: 1))
            let line = text.substring(with: lineRange)
            
            // Check if line starts with √ (ignoring leading whitespace)
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.hasPrefix("√") {
                // Find the range of √ in the actual text
                if let checkmarkRange = line.range(of: "√") {
                    let nsCheckmarkRange = NSRange(checkmarkRange, in: line)
                    let absoluteCheckmarkRange = NSRange(location: lineRange.location + nsCheckmarkRange.location, length: nsCheckmarkRange.length)
                    
                    // Use insertText to handle undo and cursor positioning correctly
                    // Convert √ to an unchecked placeholder "[ ] "
                    if textView.shouldChangeText(in: absoluteCheckmarkRange, replacementString: "[ ] ") {
                        textView.insertText("[ ] ", replacementRange: absoluteCheckmarkRange)
                        // After insertText, the cursor should be at the correct position.
                    }
                }
            }
        }
        
        private var autocompleteTask: Task<Void, Never>?

        private func checkForAutocompleteTrigger(in textView: NSTextView) {
            let selectedRange = textView.selectedRange()
            guard selectedRange.location > 0 else { return }
            
            let text = textView.string
            let lastCharRange = NSRange(location: selectedRange.location - 1, length: 1)
            let lastChar = (text as NSString).substring(with: lastCharRange)
            
            if lastChar == "@" {
                autocompleteTask?.cancel()
                autocompleteTask = Task {
                    do {
                        // findMatches now includes its own 300ms debounce
                        let matches = try await autocompleteManager.findMatches(for: "")
                        if !Task.isCancelled {
                            showAutocompleteMenu(for: matches, in: textView)
                        }
                    } catch is CancellationError {
                        // Superseded by a newer task
                    } catch {
                        print("Autocomplete error: \(error)")
                    }
                }
            }
        }

        private func showAutocompleteMenu(for matches: [AutocompleteMatch], in textView: NSTextView) {
            let menu = NSMenu(title: "Autocomplete")
            for match in matches {
                let title: String
                switch match {
                case .person(let person):
                    title = "Person: \(person.name)"
                case .date(let date):
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    title = "Date: \(formatter.string(from: date))"
                }
                
                let item = NSMenuItem(title: title, action: #selector(menuItemSelected(_:)), keyEquivalent: "")
                item.representedObject = match
                item.target = self
                menu.addItem(item)
            }
            
            // Get cursor position in view coordinates
            let layoutManager = textView.layoutManager!
            let textContainer = textView.textContainer!
            let selectedRange = textView.selectedRange()
            let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: selectedRange.location - 1, length: 1), actualCharacterRange: nil)
            let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            let containerOrigin = textView.textContainerOrigin
            let menuOrigin = NSPoint(x: rect.minX + containerOrigin.x, y: rect.maxY + containerOrigin.y)
            
            menu.popUp(positioning: nil, at: menuOrigin, in: textView)
        }

        @objc private func menuItemSelected(_ sender: NSMenuItem) {
            guard let match = sender.representedObject as? AutocompleteMatch,
                  let textView = NSApp.keyWindow?.firstResponder as? NSTextView else { return }
            
            insertChip(for: match, in: textView)
        }
        
        func insertChip(for match: AutocompleteMatch, in textView: NSTextView) {
            let attachment = NSTextAttachment()
            let label: String
            
            switch match {
            case .person(let person):
                label = "@\(person.name)"
            case .date(let date):
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                label = "@\(formatter.string(from: date))"
            }
            
            let attributedString = NSMutableAttributedString(attachment: attachment)
            attributedString.addAttribute(.link, value: "updoc://chip", range: NSRange(location: 0, length: attributedString.length))
            
            // For now, just insert the label as a placeholder if we don't have full chip UI
            let chipString = NSAttributedString(string: label, attributes: [
                .backgroundColor: NSColor.systemBlue.withAlphaComponent(0.2),
                .foregroundColor: NSColor.systemBlue,
                .font: NSFont.boldSystemFont(ofSize: 14)
            ])
            
            let selectedRange = textView.selectedRange()
            // Replace the "@" if it was just typed
            let replaceRange = NSRange(location: selectedRange.location - 1, length: 1)
            
            if textView.shouldChangeText(in: replaceRange, replacementString: chipString.string) {
                textView.textStorage?.replaceCharacters(in: replaceRange, with: chipString)
                textView.didChangeText()
            }
        }
        
        func applyStyles(to textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }
            let text = textView.string
            let ranges = parent.engine.parse(text)
            
            // 1. Convert back to pure Markdown before restyling
            // This ensures we have the correct source text for the engine
            let markdown = convertToMarkdown(from: textStorage)
            if markdown != text {
                // If the textStorage had attachments, we might need to sync back
                // but for now, let's assume 'text' is the source of truth
            }
            
            // Reset styles using theme font
            textStorage.setAttributes([.font: parent.themeManager.font], range: NSRange(text.startIndex..., in: text))
            
            // Apply Markdown styles in reverse to avoid shifting ranges when we replace text with attachments
            for markdownRange in ranges.reversed() {
                if case .image(let urlString, let title) = markdownRange.style, 
                   let url = URL(string: urlString) {
                    renderImage(url: url, title: title, range: markdownRange.range, in: textView)
                } else {
                    let attributes = attributes(for: markdownRange.style)
                    textStorage.addAttributes(attributes, range: markdownRange.range)
                }
            }
        }
        
        private func renderImage(url: URL, title: String?, range: NSRange, in textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }
            
            // Check if this range already has a RemoteImageAttachment
            var alreadyRendered = false
            textStorage.enumerateAttribute(.attachment, in: range, options: []) { value, _, stop in
                if value is RemoteImageAttachment {
                    alreadyRendered = true
                    stop.pointee = true
                }
            }
            if alreadyRendered { return }
            
            let originalMarkdown = (textView.string as NSString).substring(with: range)
            let attachment = RemoteImageAttachment(url: url, title: title, originalMarkdown: originalMarkdown)
            attachment.image = NSImage(systemSymbolName: "photo", accessibilityDescription: "Loading image...")
            
            // Use a specific character for the attachment
            let attachmentString = NSAttributedString(attachment: attachment)
            
            // Replace the Markdown text with the attachment
            // This will change the string, so we must be careful with ranges
            // But since applyStyles is called at the end of textDidChange, it should be fine
            // as long as we only do it once.
            
            // NOTE: Replacing text here will trigger another applyStyles if we are not careful.
            // But EditorView.updateNSView only calls applyStyles if text changed.
            
            // For now, let's try just adding the attachment attribute without replacing?
            // No, NSTextView only renders it for \u{FFFC}.
            
            // Let's use temporary attributes? No.
            
            // Okay, let's try replacing but we need to stop the loop.
            textStorage.replaceCharacters(in: range, with: attachmentString)
            
            // Load the image asynchronously
            Task {
                if let image = await RemoteImageCache.shared.image(for: url) {
                    attachment.image = image
                    // Invalidate layout to show the new image
                    await MainActor.run {
                        textView.layoutManager?.invalidateDisplay(forCharacterRange: NSRange(location: range.location, length: 1))
                    }
                }
            }
        }
        
        func convertToMarkdown(from attributedString: NSAttributedString) -> String {
            let result = NSMutableAttributedString(attributedString: attributedString)
            var offset = 0
            
            attributedString.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attributedString.length), options: []) { value, range, _ in
                if let attachment = value as? RemoteImageAttachment {
                    let replacementRange = NSRange(location: range.location + offset, length: range.length)
                    result.replaceCharacters(in: replacementRange, with: attachment.originalMarkdown)
                    offset += attachment.originalMarkdown.count - range.length
                }
            }
            return result.string
        }
        
        private func attributes(for style: MarkdownStyle) -> [NSAttributedString.Key: Any] {
            let baseFont = parent.themeManager.font
            let baseSize = parent.themeManager.bodyFontSize
            
            switch style {
            case .heading(let level):
                let size: CGFloat = level == 1 ? baseSize + 10 : (level == 2 ? baseSize + 6 : baseSize + 4)
                let boldFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
                return [
                    .font: boldFont.withSize(size),
                    .foregroundColor: NSColor.labelColor
                ]
            case .bold:
                let boldFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
                return [.font: boldFont]
            case .italic:
                let italicFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
                return [.font: italicFont]
            case .code:
                return [
                    .font: NSFont.monospacedSystemFont(ofSize: baseSize - 1, weight: .regular),
                    .backgroundColor: NSColor.quaternaryLabelColor
                ]
            case .checklist(let done):
                if done {
                    return [
                        .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                        .foregroundColor: NSColor.secondaryLabelColor
                    ]
                } else {
                    return [.foregroundColor: NSColor.labelColor]
                }
            case .link(_):
                return [
                    .foregroundColor: NSColor.systemBlue,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ]
            case .image(let url, let title):
                // For now, style as a link until we implement NSTextAttachment
                return [
                    .foregroundColor: NSColor.systemGreen,
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .toolTip: title ?? url
                ]
            }
        }
    }
}
