import SwiftUI
import AppKit

struct EditorView: NSViewRepresentable {
    @Binding var text: String
    private let engine = MarkdownEngine()

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        textView.delegate = context.coordinator
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isContinuousSpellCheckingEnabled = true
        textView.allowsUndo = true
        
        // Use a standard body font as the base
        textView.typingAttributes = [.font: NSFont.systemFont(ofSize: 14)]
        
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
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

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            // Handle √ shortcut
            if checkForCheckmarkShortcut(in: textView) {
                // If we replaced text, textView.string changed, and we should refresh parent text
                self.parent.text = textView.string
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
        
        private func checkForCheckmarkShortcut(in textView: NSTextView) -> Bool {
            let selectedRange = textView.selectedRange()
            guard selectedRange.location > 0 else { return false }
            
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
                    
                    if textView.shouldChangeText(in: absoluteCheckmarkRange, replacementString: "[ ]") {
                        textView.textStorage?.replaceCharacters(in: absoluteCheckmarkRange, with: "[ ]")
                        textView.didChangeText()
                        return true
                    }
                }
            }
            return false
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
            
            // Reset styles
            textStorage.setAttributes([.font: NSFont.systemFont(ofSize: 14)], range: NSRange(text.startIndex..., in: text))
            
            // Apply Markdown styles
            for markdownRange in ranges {
                let attributes = attributes(for: markdownRange.style)
                textStorage.addAttributes(attributes, range: markdownRange.range)
            }
        }
        
        private func attributes(for style: MarkdownStyle) -> [NSAttributedString.Key: Any] {
            switch style {
            case .heading(let level):
                let size: CGFloat = level == 1 ? 24 : (level == 2 ? 20 : 18)
                return [
                    .font: NSFont.boldSystemFont(ofSize: size),
                    .foregroundColor: NSColor.labelColor
                ]
            case .bold:
                return [.font: NSFont.boldSystemFont(ofSize: 14)]
            case .italic:
                let font = NSFont.systemFont(ofSize: 14)
                let italicFont = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
                return [.font: italicFont]
            case .code:
                return [
                    .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
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
