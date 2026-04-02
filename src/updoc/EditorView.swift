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

        init(_ parent: EditorView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            self.parent.text = textView.string
            
            // Basic trigger check
            checkForAutocompleteTrigger(in: textView)
            
            applyStyles(to: textView)
        }
        
        private func checkForAutocompleteTrigger(in textView: NSTextView) {
            let selectedRange = textView.selectedRange()
            guard selectedRange.location > 0 else { return }
            
            let text = textView.string
            let lastCharRange = NSRange(location: selectedRange.location - 1, length: 1)
            let lastChar = (text as NSString).substring(with: lastCharRange)
            
            if lastChar == "@" {
                // Trigger autocomplete (UI would be shown here)
                print("Autocomplete triggered at: \(selectedRange.location)")
            }
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
            default:
                return [:]
            }
        }
    }
}
