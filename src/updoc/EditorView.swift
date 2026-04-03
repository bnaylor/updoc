import SwiftUI
import AppKit
import UniformTypeIdentifiers

class EditorTextView: NSTextView {
    var onFileDropped: ((URL, NSTextView) -> Void)?
    var onPromoteAction: ((String) -> Void)?
    
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
        
        return menu
    }
    
    @objc func promoteToTask(_ sender: Any) {
        let range = self.selectedRange()
        let selectedText = (self.string as NSString).substring(with: range)
        onPromoteAction?(selectedText)
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
    var onPromoteAction: ((String) -> Void)?
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
        
        textView.delegate = context.coordinator
        textView.onFileDropped = { url, targetTextView in
            context.coordinator.handleFileDrop(url: url, in: targetTextView)
        }
        textView.onPromoteAction = { selectedText in
            self.onPromoteAction?(selectedText)
        }
        textView.font = themeManager.font
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isContinuousSpellCheckingEnabled = true
        textView.allowsUndo = true
        
        // Register for dropped image files
        textView.registerForDraggedTypes([.fileURL])
        
        // Use the theme's font as the base
        textView.typingAttributes = [.font: themeManager.font]
        
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
        
        if textView.string != text {
            textView.string = text
            context.coordinator.applyStyles(to: textView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    @MainActor
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditorView
        private let autocompleteManager = AutocompleteManager()
        private var syncTask: Task<Void, Never>?

        init(_ parent: EditorView) {
            self.parent = parent
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
            self.parent.text = textView.string
            
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
        
        private func checkForAutocompleteTrigger(in textView: NSTextView) {
            let selectedRange = textView.selectedRange()
            guard selectedRange.location > 0 else { return }
            
            let text = textView.string
            let lastCharRange = NSRange(location: selectedRange.location - 1, length: 1)
            let lastChar = (text as NSString).substring(with: lastCharRange)
            
            if lastChar == "@" {
                // In a real app, we'd wait for more characters to search, 
                // but for this demo we'll show a menu immediately or after a short delay.
                Task {
                    do {
                        // For demonstration, search for a default or empty query initially
                        let matches = try await autocompleteManager.findMatches(for: "today")
                        if !matches.isEmpty {
                            showAutocompleteMenu(for: matches, in: textView)
                        }
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
            
            // Reset styles using theme font
            textStorage.setAttributes([.font: parent.themeManager.font], range: NSRange(text.startIndex..., in: text))
            
            // Apply Markdown styles
            for markdownRange in ranges {
                let attributes = attributes(for: markdownRange.style)
                textStorage.addAttributes(attributes, range: markdownRange.range)
            }
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
            }
        }
    }
}
