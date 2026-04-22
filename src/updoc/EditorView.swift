import SwiftUI
import AppKit
import UniformTypeIdentifiers
@preconcurrency import QuickLookUI

extension NSAttributedString.Key {
    static let listMarkerReplacement = NSAttributedString.Key("listMarkerReplacement")
    static let listMarkerColor = NSAttributedString.Key("listMarkerColor")
    static let horizontalRule = NSAttributedString.Key("horizontalRule")
    static let horizontalRuleColor = NSAttributedString.Key("horizontalRuleColor")
}

@MainActor
class EditorTextView: NSTextView {
    var onFileDropped: ((URL, NSTextView) -> Void)?
    var onPromoteAction: ((String) -> Void)?
    var onEditRequested: ((RemoteImageAttachment) -> Void)?
    
    override func keyDown(with event: NSEvent) {
        if let coordinator = delegate as? EditorView.Coordinator {
            if coordinator.handleKeyDown(with: event) {
                return // Handled!
            }
        }
        super.keyDown(with: event)
    }
    
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()
        
        // Context menu items for images can go here.
        
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
    var theme: String
    var isReadOnly: Bool = false
    var onEditRequested: ((RemoteImageAttachment) -> Void)?
    @Environment(ThemeManager.self) private var themeManager
    private let engine = MarkdownEngine()
    
    @AppStorage("spellcheckEnabled") private var spellcheckEnabled = true
    @AppStorage("autocorrectEnabled") private var autocorrectEnabled = true

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = true
        scrollView.backgroundColor = themeManager.backgroundColor(for: theme)
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]
        
        let textStorage = NSTextStorage()
        let layoutManager = EditorLayoutManager()
        layoutManager.baseFont = themeManager.font
        textStorage.addLayoutManager(layoutManager)
        
        let contentSize = scrollView.contentSize
        let textContainer = NSTextContainer(containerSize: NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)
        
        let textView = EditorTextView(frame: CGRect(origin: .zero, size: contentSize), textContainer: textContainer)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.drawsBackground = true
        textView.backgroundColor = themeManager.backgroundColor(for: theme)
        textView.isRichText = false
        textView.isAutomaticDashSubstitutionEnabled = false
        
        textView.isContinuousSpellCheckingEnabled = spellcheckEnabled
        textView.isAutomaticSpellingCorrectionEnabled = autocorrectEnabled
        
        // Add some padding
        textView.textContainerInset = NSSize(width: 20, height: 20)
        
        scrollView.documentView = textView
        context.coordinator.textView = textView
        
        textView.delegate = context.coordinator
        textView.onFileDropped = { url, targetTextView in
            context.coordinator.handleFileDrop(url: url, in: targetTextView)
        }
        textView.onEditRequested = { [weak coordinator = context.coordinator] attachment in
            if let onEditRequested = self.onEditRequested {
                onEditRequested(attachment)
            } else {
                coordinator?.openEditor(for: attachment)
            }
        }
        textView.font = themeManager.font(for: theme)
        textView.textColor = themeManager.textColor(for: theme)
        textView.isEditable = !isReadOnly
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
        textView.typingAttributes = [
            .font: themeManager.font,
            .foregroundColor: NSColor.labelColor
        ]
        
        NotificationCenter.default.addObserver(forName: .focusEditor, object: nil, queue: .main) { _ in
            Task { @MainActor in
                @MainActor func attemptFocus(retries: Int) {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    if let window = textView.window {
                        window.makeKeyAndOrderFront(nil)
                        if window.firstResponder != textView {
                            window.makeFirstResponder(textView)
                        }
                    } else if retries > 0 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            Task { @MainActor in
                                attemptFocus(retries: retries - 1)
                            }
                        }
                    }
                }
                attemptFocus(retries: 10)
            }
        }
        
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        
        // Update layout manager's base font
        if let layoutManager = textView.layoutManager as? EditorLayoutManager {
            layoutManager.baseFont = themeManager.font(for: theme)
        }
        
        // CRITICAL: Update coordinator's reference to parent to avoid stale bindings
        // and "cross-document bleed" when switching notes.
        context.coordinator.parent = self
        
        // Update preferences
        if textView.isContinuousSpellCheckingEnabled != spellcheckEnabled {
            textView.isContinuousSpellCheckingEnabled = spellcheckEnabled
        }
        if textView.isAutomaticSpellingCorrectionEnabled != autocorrectEnabled {
            textView.isAutomaticSpellingCorrectionEnabled = autocorrectEnabled
        }
        
        // Update colors if needed
        let newBgColor = themeManager.backgroundColor(for: theme)
        if textView.backgroundColor != newBgColor {
            textView.backgroundColor = newBgColor
            nsView.backgroundColor = newBgColor
        }
        
        let newTextColor = themeManager.textColor(for: theme)
        if textView.textColor != newTextColor {
            textView.textColor = newTextColor
        }
        
        // Ensure theme font is applied
        if textView.font != themeManager.font(for: theme) {
            textView.font = themeManager.font(for: theme)
            textView.typingAttributes = [
                .font: themeManager.font(for: theme),
                .foregroundColor: themeManager.textColor(for: theme)
            ]
            context.coordinator.applyStyles(to: textView)
        }
        
        // Only update textView if the parent's text is DIFFERENT from the last version 
        // the coordinator sent, AND different from the current textView content.
        // This prevents "flapping" or "reverting" during rapid typing/syncs.
        let currentMarkdown = context.coordinator.convertToMarkdown(from: textView.textStorage ?? NSAttributedString())
        if text != context.coordinator.lastSentText && currentMarkdown != text {
            // Check if this is a remote update (where we didn't just type this text)
            let isRemoteUpdate = currentMarkdown != context.coordinator.lastSentText
            
            textView.string = text
            context.coordinator.applyStyles(to: textView)
            context.coordinator.lastSentText = text
            
            // If it was a remote update, ensure we scroll to keep the cursor visible
            if isRemoteUpdate, let range = selectionRange {
                textView.scrollRangeToVisible(range)
            }
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
        var lastSentText: String?
        private let autocompleteManager = AutocompleteManager()
        private var syncTask: Task<Void, Never>?
        var editingAttachment: RemoteImageAttachment?
        weak var textView: NSTextView?

        init(_ parent: EditorView) {
            self.parent = parent
            self.lastSentText = nil
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                if handleListBehavior(keyCode: 48, modifierFlags: [], in: textView) {
                    return true
                }
            } else if commandSelector == #selector(NSResponder.insertBacktab(_:)) {
                if handleListBehavior(keyCode: 48, modifierFlags: [.shift], in: textView) {
                    return true
                }
            }
            return false
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

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            // Handle √ shortcut
            checkForCheckmarkShortcut(in: textView)
            
            // Handle Emoji shortcodes
            checkForEmojiShortcodes(in: textView)
            
            // Live Emoji Search
            if let query = detectEmojiQuery(in: textView) {
                let matches = EmojiService.findMatches(for: query)
                if !matches.isEmpty {
                    if query != currentEmojiQuery {
                        emojiSelectedIndex = 0
                    }
                    showEmojiWindow(matches: matches, in: textView, for: query)
                } else {
                    closeEmojiWindow()
                }
            } else {
                closeEmojiWindow()
            }
            
            let currentMarkdown: String
            if let textStorage = textView.textStorage {
                currentMarkdown = convertToMarkdown(from: textStorage)
            } else {
                currentMarkdown = textView.string
            }
            
            // Update lastSentText so updateNSView doesn't revert us
            self.lastSentText = currentMarkdown
            self.parent.text = currentMarkdown
            
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
        
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            // Trigger a restyle so we can hide/show syntax based on the new cursor position.
            // Using a very short debounce (50ms) to ensure smooth cursor movement.
            syncTask?.cancel()
            syncTask = Task {
                try? await Task.sleep(for: .milliseconds(50))
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
        
        private var emojiWindow: NSWindow?
        private var emojiSelectedIndex: Int = 0
        private var currentEmojiMatches: [EmojiMatch] = []
        private var currentEmojiQuery: String = ""
        
        private var autocompleteWindow: NSWindow?
        
        private func checkForEmojiShortcodes(in textView: NSTextView) {
            let selectedRange = textView.selectedRange()
            guard selectedRange.location > 0 else { return }
            
            let text = textView.string as NSString
            let lineRange = text.lineRange(for: NSRange(location: selectedRange.location - 1, length: 1))
            let line = text.substring(with: lineRange)
            
            let regex = try! NSRegularExpression(pattern: ":([a-zA-Z0-9_+-]+):", options: [])
            let matches = regex.matches(in: line, options: [], range: NSRange(location: 0, length: line.count))
            
            for match in matches.reversed() {
                let fullRange = match.range(at: 0)
                let codeRange = match.range(at: 1)
                let shortcode = ":" + (line as NSString).substring(with: codeRange) + ":"
                
                if let emoji = EmojiService.mapping[shortcode] {
                    let absoluteRange = NSRange(location: lineRange.location + fullRange.location, length: fullRange.length)
                    
                    if textView.shouldChangeText(in: absoluteRange, replacementString: emoji) {
                        textView.insertText(emoji, replacementRange: absoluteRange)
                    }
                }
            }
        }
        
        private func detectEmojiQuery(in textView: NSTextView) -> String? {
            let selectedRange = textView.selectedRange()
            guard selectedRange.location > 0 else { return nil }
            
            guard let textStorage = textView.textStorage else { return nil }
            
            let cursorLoc = selectedRange.location
            let startLoc = max(0, cursorLoc - 20)
            let scanRange = NSRange(location: startLoc, length: cursorLoc - startLoc)
            
            let scanString = textStorage.attributedSubstring(from: scanRange).string
            
            if let colonIndex = scanString.range(of: ":", options: .backwards) {
                let queryRange = Range(uncheckedBounds: (lower: colonIndex.upperBound, upper: scanString.endIndex))
                let query = String(scanString[queryRange])
                
                // Verify no whitespace in query
                if query.contains(where: { $0.isWhitespace }) { return nil }
                
                // Check if preceded by non-alphanumeric
                let colonIndexInScanString = colonIndex.lowerBound
                if colonIndexInScanString == scanString.startIndex {
                    if startLoc == 0 { return query }
                    let prevCharRange = NSRange(location: startLoc - 1, length: 1)
                    let prevChar = textStorage.attributedSubstring(from: prevCharRange).string
                    if let character = prevChar.first, !character.isLetter && !character.isNumber {
                        return query
                    }
                } else {
                    let prevIndex = scanString.index(before: colonIndexInScanString)
                    let character = scanString[prevIndex]
                    if !character.isLetter && !character.isNumber {
                        return query
                    }
                }
                
                return query
            }
            
            return nil
        }
        
        private func detectMentionQuery(in textView: NSTextView) -> String? {
            let selectedRange = textView.selectedRange()
            guard selectedRange.location > 0 else { return nil }
            
            // Access textStorage to avoid full string bridging copy on huge docs
            guard let textStorage = textView.textStorage else { return nil }
            
            let cursorLoc = selectedRange.location
            let startLoc = max(0, cursorLoc - 50)
            let scanRange = NSRange(location: startLoc, length: cursorLoc - startLoc)
            
            let scanString = textStorage.attributedSubstring(from: scanRange).string
            
            // Search from right to left for '@'
            if let atIndex = scanString.range(of: "@", options: .backwards) {
                let queryRange = Range(uncheckedBounds: (lower: atIndex.upperBound, upper: scanString.endIndex))
                let query = String(scanString[queryRange])
                
                // Verify no newline in between
                if query.contains("\n") { return nil }
                
                // Verify allowed characters
                for character in query {
                    if !character.isLetter && !character.isNumber && !character.isWhitespace && character != "," {
                        return nil
                    }
                }
                
                // Check if '@' is at start or preceded by non-alphanumeric
                let atIndexInScanString = atIndex.lowerBound
                if atIndexInScanString == scanString.startIndex {
                    if startLoc == 0 { return query }
                    // If startLoc > 0, we need to check character before startLoc in full text
                    let prevCharRange = NSRange(location: startLoc - 1, length: 1)
                    let prevChar = textStorage.attributedSubstring(from: prevCharRange).string
                    if let character = prevChar.first, !character.isLetter && !character.isNumber {
                        return query
                    }
                } else {
                    let prevIndex = scanString.index(before: atIndexInScanString)
                    let character = scanString[prevIndex]
                    if !character.isLetter && !character.isNumber {
                        return query
                    }
                }
                
                return query
            }
            
            return nil
        }
        
        private func showEmojiWindow(matches: [EmojiMatch], in textView: NSTextView, for query: String) {
            self.currentEmojiMatches = matches
            self.currentEmojiQuery = query
            
            let contentView = EmojiAutocompleteView(matches: matches, selectedIndex: emojiSelectedIndex) { [weak self] match in
                self?.insertEmoji(match, in: textView, for: query)
            }
            
            if emojiWindow == nil {
                let window = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 200, height: 150),
                    styleMask: [.borderless],
                    backing: .buffered,
                    defer: false
                )
                window.level = .popUpMenu
                window.isReleasedWhenClosed = false
                window.ignoresMouseEvents = false
                window.contentView = NSHostingView(rootView: contentView)
                emojiWindow = window
            } else {
                if let hostingView = emojiWindow?.contentView as? NSHostingView<EmojiAutocompleteView> {
                    hostingView.rootView = contentView
                }
            }
            
            // Position window
            let selectedRange = textView.selectedRange()
            let screenRect = textView.firstRect(forCharacterRange: selectedRange, actualRange: nil)
            
            var windowFrame = emojiWindow!.frame
            // Place it below the cursor
            windowFrame.origin = NSPoint(x: screenRect.minX, y: screenRect.minY - windowFrame.height)
            emojiWindow?.setFrame(windowFrame, display: true)
            
            if !(emojiWindow?.isVisible ?? false) {
                emojiWindow?.orderFront(nil)
            }
        }
        
        private func closeEmojiWindow() {
            emojiWindow?.orderOut(nil)
            currentEmojiMatches = []
            currentEmojiQuery = ""
        }
        
        private func insertEmoji(_ match: EmojiMatch, in textView: NSTextView, for query: String) {
            let selectedRange = textView.selectedRange()
            let queryLength = query.count + 1
            let replacementRange = NSRange(location: selectedRange.location - queryLength, length: queryLength)
            
            if textView.shouldChangeText(in: replacementRange, replacementString: match.emoji) {
                textView.insertText(match.emoji, replacementRange: replacementRange)
                closeEmojiWindow()
            }
        }
        
        public func handleKeyDown(with event: NSEvent) -> Bool {
            if let textView = self.textView {
                if handleListBehavior(keyCode: event.keyCode, modifierFlags: event.modifierFlags, in: textView) {
                    return true
                }
            }

            guard let emojiWindow = emojiWindow, emojiWindow.isVisible else { return false }
            
            switch event.keyCode {
            case 125: // Down Arrow
                if !currentEmojiMatches.isEmpty {
                    emojiSelectedIndex = (emojiSelectedIndex + 1) % currentEmojiMatches.count
                    updateEmojiWindowContent()
                    return true
                }
            case 126: // Up Arrow
                if !currentEmojiMatches.isEmpty {
                    emojiSelectedIndex = (emojiSelectedIndex - 1 + currentEmojiMatches.count) % currentEmojiMatches.count
                    updateEmojiWindowContent()
                    return true
                }
            case 36: // Return
                if emojiSelectedIndex < currentEmojiMatches.count {
                    let match = currentEmojiMatches[emojiSelectedIndex]
                    if let textView = self.textView {
                        insertEmoji(match, in: textView, for: currentEmojiQuery)
                    }
                    return true
                }
            case 53: // Escape
                closeEmojiWindow()
                return true
            default:
                break
            }
            return false
        }
        
        private func handleListBehavior(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags, in textView: NSTextView) -> Bool {
            guard keyCode == 36 || keyCode == 51 || keyCode == 48 else { return false } // Return, Backspace, or Tab
            
            let selectedRange = textView.selectedRange()
            guard let textStorage = textView.textStorage else { return false }
            
            let text = textStorage.string as NSString
            let lineRange = text.lineRange(for: NSRange(location: selectedRange.location, length: 0))
            let line = text.substring(with: lineRange)
            
            // Check if line is a bulleted list item
            let pattern = "^(\\s*)([*+-])(\\s+)(.*)"
            let regex = try? NSRegularExpression(pattern: pattern, options: [])
            let nsString = line as NSString
            let results = regex?.matches(in: line, options: [], range: NSRange(location: 0, length: nsString.length))
            
            guard let match = results?.first else { return false }
            
            let indentRange = match.range(at: 1)
            let markerRange = match.range(at: 2)
            let spaceRange = match.range(at: 3)
            let contentRange = match.range(at: 4)
            
            let indent = nsString.substring(with: indentRange)
            let marker = nsString.substring(with: markerRange)
            let content = nsString.substring(with: contentRange)
            
            if keyCode == 36 { // Return
                // First enter: Create new line with same indent
                // Subsequent enter: Decrease indent
                // No bullet left -> remove bullet
                
                if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Empty content on line
                    if indent.isEmpty {
                        // No indent, remove bullet
                        let absoluteRange = NSRange(location: lineRange.location, length: lineRange.length)
                        if textView.shouldChangeText(in: absoluteRange, replacementString: "") {
                            textView.insertText("", replacementRange: absoluteRange)
                            return true
                        }
                    } else {
                        // Decrease indent
                        let absoluteRange = NSRange(location: lineRange.location, length: lineRange.length)
                        let newIndent = String(indent.dropLast(4)) // Assume 4 spaces per level
                        let newLine = "\(newIndent)\(marker) "
                        if textView.shouldChangeText(in: absoluteRange, replacementString: newLine) {
                            textView.insertText(newLine, replacementRange: absoluteRange)
                            return true
                        }
                    }
                } else {
                    // Content exists, normal return (but with auto-indent)
                    let absoluteRange = NSRange(location: selectedRange.location, length: 0)
                    let newLine = "\n\(indent)\(marker) "
                    if textView.shouldChangeText(in: absoluteRange, replacementString: newLine) {
                        textView.insertText(newLine, replacementRange: absoluteRange)
                        return true
                    }
                }
            } else if keyCode == 48 { // Tab
                // Tab on empty bullet: Increase bullet indent
                // Shift+Tab: Decrease indent
                
                if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let absoluteRange = NSRange(location: lineRange.location, length: lineRange.length)
                    if modifierFlags.contains(.shift) { // Shift+Tab
                        if !indent.isEmpty {
                            let newIndent = String(indent.dropLast(4))
                            let newLine = "\(newIndent)\(marker) "
                            if textView.shouldChangeText(in: absoluteRange, replacementString: newLine) {
                                textView.insertText(newLine, replacementRange: absoluteRange)
                                return true
                            }
                        }
                    } else { // Tab
                        let newIndent = indent + "    " // Assume 4 spaces per level
                        let newLine = "\(newIndent)\(marker) "
                        if textView.shouldChangeText(in: absoluteRange, replacementString: newLine) {
                            textView.insertText(newLine, replacementRange: absoluteRange)
                            return true
                        }
                    }
                }
            } else if keyCode == 51 { // Backspace
                // Backspace with no text: Remove bullets and indentation
                // Backspace with text: normal behavior
                
                if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let absoluteRange = NSRange(location: lineRange.location, length: lineRange.length)
                    if textView.shouldChangeText(in: absoluteRange, replacementString: "") {
                        textView.insertText("", replacementRange: absoluteRange)
                        return true
                    }
                }
            }
            
            return false
        }
        
        private func updateEmojiWindowContent() {
            let contentView = EmojiAutocompleteView(matches: currentEmojiMatches, selectedIndex: emojiSelectedIndex) { [weak self] match in
                if let textView = self?.textView {
                    self?.insertEmoji(match, in: textView, for: self?.currentEmojiQuery ?? "")
                }
            }
            if let hostingView = emojiWindow?.contentView as? NSHostingView<EmojiAutocompleteView> {
                hostingView.rootView = contentView
            }
        }
        
        private var autocompleteTask: Task<Void, Never>?

        private func checkForAutocompleteTrigger(in textView: NSTextView) {
            let selectedRange = textView.selectedRange()
            guard selectedRange.location > 0 else { return }
            
            if let query = detectMentionQuery(in: textView) {
                autocompleteTask?.cancel()
                autocompleteTask = Task {
                    do {
                        let matches = try await autocompleteManager.findMatches(for: query)
                        if !Task.isCancelled && !matches.isEmpty {
                            showAutocompleteWindow(for: matches, in: textView, for: query)
                        }
                    } catch is CancellationError {
                    } catch {
                        print("Autocomplete error: \(error)")
                    }
                }
            }
        }

        private func showAutocompleteWindow(for matches: [AutocompleteMatch], in textView: NSTextView, for query: String) {
            let items = matches.map { match -> String in
                switch match {
                case .person(let person): return "@\(person.name)"
                case .date(let date):
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    return "@\(formatter.string(from: date))"
                }
            }
            
            let contentView = MentionAutocompleteView(items: items) { [weak self] index in
                let match = matches[index]
                let selectedRange = textView.selectedRange()
                let replaceRange = NSRange(location: selectedRange.location - query.count - 1, length: query.count + 1)
                self?.insertChip(for: match, in: textView, replaceRange: replaceRange)
                self?.closeAutocompleteWindow()
            }
            
            if autocompleteWindow == nil {
                let window = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 250, height: 150),
                    styleMask: [.borderless],
                    backing: .buffered,
                    defer: false
                )
                window.level = .popUpMenu
                window.isReleasedWhenClosed = false
                window.ignoresMouseEvents = false
                window.contentView = NSHostingView(rootView: contentView)
                autocompleteWindow = window
            } else {
                if let hostingView = autocompleteWindow?.contentView as? NSHostingView<MentionAutocompleteView> {
                    hostingView.rootView = contentView
                }
            }
            
            // Position window
            let selectedRange = textView.selectedRange()
            let screenRect = textView.firstRect(forCharacterRange: selectedRange, actualRange: nil)
            
            var windowFrame = autocompleteWindow!.frame
            // Place it below the cursor
            windowFrame.origin = NSPoint(x: screenRect.minX, y: screenRect.minY - windowFrame.height)
            autocompleteWindow?.setFrame(windowFrame, display: true)
            
            if !(autocompleteWindow?.isVisible ?? false) {
                autocompleteWindow?.orderFront(nil)
            }
        }
        
        private func closeAutocompleteWindow() {
            autocompleteWindow?.orderOut(nil)
        }
        
        func insertChip(for match: AutocompleteMatch, in textView: NSTextView, replaceRange: NSRange) {
            let replacementText: String
            switch match {
            case .person(let person):
                replacementText = "[@\(person.name)](mailto:\(person.email))"
            case .date(let date):
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                replacementText = "[@\(formatter.string(from: date))](updoc://date)"
            }
            
            let chipString = NSAttributedString(string: replacementText, attributes: [
                .foregroundColor: NSColor.systemBlue,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ])
            
            if textView.shouldChangeText(in: replaceRange, replacementString: chipString.string) {
                textView.textStorage?.replaceCharacters(in: replaceRange, with: chipString)
                textView.didChangeText()
            }
        }
        
        func applyStyles(to textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }
            let text = textView.string
            let ranges = parent.engine.parse(text)
            let selectedRange = textView.selectedRange()
            
            // Reset styles using theme font and label color
            textStorage.setAttributes([
                .font: parent.themeManager.font(for: parent.theme),
                .foregroundColor: parent.themeManager.textColor(for: parent.theme)
            ], range: NSRange(text.startIndex..., in: text))
            
            // Apply Markdown styles sorted by location descending to avoid shifting ranges when we replace text with attachments
            let sortedRanges = ranges.sorted {
                if $0.range.location != $1.range.location {
                    return $0.range.location < $1.range.location
                }
                return $0.range.length > $1.range.length
            }
            for markdownRange in sortedRanges {
                let styleAttributes = attributes(for: markdownRange.style)
                textStorage.addAttributes(styleAttributes, range: markdownRange.range)
                
                if markdownRange.style == .codeBlock {
                    applySyntaxHighlighting(to: textView, in: markdownRange.range)
                }
                
                // Hide syntax if the cursor does NOT intersect the full markdownRange
                let cursorIntersects = NSIntersectionRange(selectedRange, markdownRange.range).length > 0 || 
                                       (selectedRange.length == 0 && NSLocationInRange(selectedRange.location, markdownRange.range))

                if !cursorIntersects {
                    for (index, syntaxRange) in markdownRange.syntaxRanges.enumerated() {
                        var isListMarker = false
                        var hiddenAttributes: [NSAttributedString.Key: Any] = [
                            .foregroundColor: NSColor.clear
                        ]
                        
                        // Apply replacement symbol only to the first syntax range of list items
                        if index == 0 {
                            switch markdownRange.style {
                            case .bullet(let level):
                                isListMarker = true
                                hiddenAttributes[.listMarkerReplacement] = "circle.fill"
                                let bulletAttributes = attributes(for: .bullet(level: level))
                                hiddenAttributes[.listMarkerColor] = bulletAttributes[NSAttributedString.Key.foregroundColor] as? NSColor ?? NSColor.systemOrange
                            case .checklist(let done, let level):
                                isListMarker = true
                                hiddenAttributes[.listMarkerReplacement] = done ? "checkmark.square" : "square"
                                let bulletAttributes = attributes(for: .bullet(level: level))
                                hiddenAttributes[.listMarkerColor] = bulletAttributes[NSAttributedString.Key.foregroundColor] as? NSColor ?? NSColor.systemOrange
                            default:
                                break
                            }
                        }
                        
                        // Only shrink font for non-list markers so list markers preserve indentation
                        if !isListMarker {
                            hiddenAttributes[.font] = NSFont.systemFont(ofSize: 0.1)
                        }
                        
                        textStorage.addAttributes(hiddenAttributes, range: syntaxRange)
                        textStorage.removeAttribute(.link, range: syntaxRange)
                    }
                }
            }
        }
        
        private func attributes(for style: MarkdownStyle) -> [NSAttributedString.Key: Any] {
            return parent.themeManager.attributes(for: style, in: parent.theme)
        }
        
        private func applySyntaxHighlighting(to textView: NSTextView, in range: NSRange) {
            guard let textStorage = textView.textStorage else { return }
            let text = (textView.string as NSString).substring(with: range)
            
            // Find the first line to detect language
            let lines = text.components(separatedBy: .newlines)
            guard let firstLine = lines.first else { return }
            
            let language = firstLine.trimmingCharacters(in: CharacterSet(charactersIn: "`")).trimmingCharacters(in: .whitespaces)
            
            let keywords: [String]
            let commentPattern: String
            
            switch language.lowercased() {
            case "swift":
                keywords = ["func", "var", "let", "if", "else", "return", "class", "struct", "enum", "import", "guard", "switch", "case"]
                commentPattern = "//.*$"
            case "python":
                keywords = ["def", "class", "if", "elif", "else", "return", "import", "from", "as", "for", "in", "while", "try", "except", "print"]
                commentPattern = "#.*$"
            case "golang", "go":
                keywords = ["func", "var", "if", "else", "return", "type", "struct", "package", "import", "range", "for", "switch", "case"]
                commentPattern = "//.*$"
            case "c", "cpp", "c++":
                keywords = ["int", "float", "double", "char", "void", "if", "else", "return", "class", "struct", "enum", "include", "for", "while", "switch", "case"]
                commentPattern = "//.*$"
            case "bash", "sh":
                keywords = ["if", "then", "else", "fi", "for", "in", "do", "done", "while", "case", "esac", "function", "return"]
                commentPattern = "#.*$"
            default:
                keywords = ["func", "var", "let", "if", "else", "return", "class", "struct", "enum", "import"]
                commentPattern = "//.*$"
            }
            
            let keywordRegex = try! NSRegularExpression(pattern: "\\b(\(keywords.joined(separator: "|")))\\b", options: [])
            let stringRegex = try! NSRegularExpression(pattern: "\".*?\"", options: [])
            let commentRegex = try! NSRegularExpression(pattern: commentPattern, options: [.anchorsMatchLines])
            let typeRegex = try! NSRegularExpression(pattern: "\\b[A-Z][a-zA-Z0-9]*\\b", options: [])
            
            // Softer color palette
            let keywordColor = NSColor(red: 0.87, green: 0.54, blue: 0.74, alpha: 1.0) // Soft pink/purple
            let typeColor = NSColor(red: 0.40, green: 0.70, blue: 0.85, alpha: 1.0) // Soft blue
            let stringColor = NSColor(red: 0.85, green: 0.50, blue: 0.40, alpha: 1.0) // Soft red/orange
            let commentColor = NSColor(red: 0.50, green: 0.70, blue: 0.50, alpha: 1.0) // Soft green
            
            // Apply types first so keywords can override them if needed
            typeRegex.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: text.count)) { match, _, _ in
                if let matchRange = match?.range {
                    let absoluteRange = NSRange(location: range.location + matchRange.location, length: matchRange.length)
                    textStorage.addAttribute(.foregroundColor, value: typeColor, range: absoluteRange)
                }
            }
            
            keywordRegex.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: text.count)) { match, _, _ in
                if let matchRange = match?.range {
                    let absoluteRange = NSRange(location: range.location + matchRange.location, length: matchRange.length)
                    textStorage.addAttribute(.foregroundColor, value: keywordColor, range: absoluteRange)
                }
            }
            
            stringRegex.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: text.count)) { match, _, _ in
                if let matchRange = match?.range {
                    let absoluteRange = NSRange(location: range.location + matchRange.location, length: matchRange.length)
                    textStorage.addAttribute(.foregroundColor, value: stringColor, range: absoluteRange)
                }
            }
            
            commentRegex.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: text.count)) { match, _, _ in
                if let matchRange = match?.range {
                    let absoluteRange = NSRange(location: range.location + matchRange.location, length: matchRange.length)
                    textStorage.addAttribute(.foregroundColor, value: commentColor, range: absoluteRange)
                }
            }
        }
    }
}
