import SwiftUI
import WebKit
import AppKit
import SwiftData

struct CodeMirrorEditorView: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectionRange: NSRange?
    var theme: String
    var isReadOnly: Bool

    @AppStorage("spellcheckEnabled") private var spellcheckEnabled: Bool = true
    @AppStorage("autocorrectEnabled") private var autocorrectEnabled: Bool = true
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(EditorSchemeHandler(), forURLScheme: "editor")

        let controller = config.userContentController
        controller.add(context.coordinator, name: "contentChanged")
        controller.add(context.coordinator, name: "checkboxToggled")
        controller.add(context.coordinator, name: "linkClicked")
        controller.add(context.coordinator, name: "logging")
        controller.add(context.coordinator, name: "showAutocomplete")
        controller.add(context.coordinator, name: "hideAutocomplete")
        controller.add(context.coordinator, name: "autocompleteKeyEvent")

        // Inject script to capture console.log
        let script = WKUserScript(
            source: "console.log = (msg) => window.webkit.messageHandlers.logging.postMessage(msg); " +
                    "window.onerror = (msg, url, line, col, error) => window.webkit.messageHandlers.logging.postMessage('ERROR: ' + msg + ' at ' + url + ':' + line);",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        controller.addUserScript(script)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        context.coordinator.parent = self

        webView.load(URLRequest(url: URL(string: "editor://host/editor.html")!))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self

        // Push content if it changed externally (sync, template apply, etc.)
        if coordinator.lastKnownText != text {
            coordinator.loadContent(text)
        }
        
        // Push theme if it changed
        if coordinator.lastThemeName != theme {
            coordinator.applyTheme()
        }

        // Handle search result navigation
        if let range = selectionRange {
            coordinator.scrollToRange(from: range.location, to: range.location + range.length)
            DispatchQueue.main.async { self.selectionRange = nil }
        }
    }

    // MARK: – Coordinator

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: CodeMirrorEditorView
        weak var webView: WKWebView?

        /// The last text value we sent to the editor (or received from it).
        /// Used to suppress round-trip echoes in updateNSView.
        var lastKnownText: String = ""
        
        /// The last theme name applied to the editor.
        var lastThemeName: String?

        private var isEditorReady = false
        private var pendingContent: String?
        
        // Autocomplete state
        private var popover: NSPopover?
        private var autocompleteType: String?
        private var autocompleteQuery: String?
        private var selectedIndex: Int = 0
        private var currentMentionMatches: [AutocompleteItem] = []
        private var currentEmojiMatches: [EmojiMatch] = []

        init(_ parent: CodeMirrorEditorView) {
            self.parent = parent
        }

        deinit {
            let controller = webView?.configuration.userContentController
            DispatchQueue.main.async {
                controller?.removeAllScriptMessageHandlers()
            }
        }

        // MARK: WKNavigationDelegate

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isEditorReady = true
            applyTheme()
            let autocorrect = parent.autocorrectEnabled
            webView.evaluateJavaScript(
                "document.querySelector('.cm-content')?.setAttribute('autocorrect', '\(autocorrect ? "on" : "off")')"
            )
            webView.evaluateJavaScript(
                "document.querySelector('.cm-content')?.setAttribute('spellcheck', '\(parent.spellcheckEnabled ? "true" : "false")')"
            )
            setReadOnly(parent.isReadOnly)
            if let pending = pendingContent {
                loadContent(pending)
                pendingContent = nil
            } else {
                loadContent(parent.text)
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("[WKWebView] didFailProvisionalNavigation: \(error.localizedDescription)")
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("[WKWebView] didFail: \(error.localizedDescription)")
        }

        // MARK: WKScriptMessageHandler

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            if message.name == "logging" {
                if let msg = message.body as? String {
                    print("[JS] \(msg)")
                } else {
                    print("[JS] \(message.body)")
                }
                return
            }

            guard let body = message.body as? [String: Any] else { return }
            
            switch message.name {
            case "contentChanged":
                if let text = body["text"] as? String {
                    // The editor sends an empty string on initialization.
                    // If the note already has content, ignore this to avoid clearing it.
                    if text.isEmpty && !parent.text.isEmpty {
                        return
                    }
                    lastKnownText = text
                    parent.text = text
                }
            case "checkboxToggled":
                // CM6 widget already updated its own state; the subsequent
                // contentChanged message delivers the updated text.
                break
            case "linkClicked":
                if let urlString = body["url"] as? String,
                   let url = URL(string: urlString) {
                    NSWorkspace.shared.open(url)
                }
            case "showAutocomplete":
                if let type = body["type"] as? String,
                   let query = body["query"] as? String,
                   let x = body["x"] as? CGFloat,
                   let y = body["y"] as? CGFloat,
                   let bottom = body["bottom"] as? CGFloat {
                    showAutocomplete(type: type, query: query, rect: NSRect(x: x, y: y, width: 1, height: bottom - y))
                }
            case "hideAutocomplete":
                hideAutocomplete()
            case "autocompleteKeyEvent":
                if let key = body["key"] as? String {
                    handleAutocompleteKey(key)
                }
            default:
                break
            }
        }

        // MARK: Autocomplete

        private func handleAutocompleteKey(_ key: String) {
            let maxCount: Int
            if autocompleteType == "mention" {
                maxCount = currentMentionMatches.count
            } else {
                maxCount = currentEmojiMatches.count
            }
            
            guard maxCount > 0 else { return }
            
            switch key {
            case "ArrowDown":
                selectedIndex = min(selectedIndex + 1, maxCount - 1)
                updatePopoverContent()
            case "ArrowUp":
                selectedIndex = max(selectedIndex - 1, 0)
                updatePopoverContent()
            case "Enter":
                if autocompleteType == "mention" {
                    let match = currentMentionMatches[selectedIndex].match
                    hideAutocomplete()
                    insertAutocomplete(match: match)
                } else {
                    let match = currentEmojiMatches[selectedIndex]
                    hideAutocomplete()
                    insertEmoji(match: match)
                }
            default:
                break
            }
        }
        
        private func updatePopoverContent() {
            let contentView: AnyView
            if autocompleteType == "mention" {
                contentView = AnyView(ContactAutocompleteView(
                    items: currentMentionMatches,
                    selectedIndex: selectedIndex,
                    onSelect: { match in
                        self.hideAutocomplete()
                        self.insertAutocomplete(match: match)
                    },
                    onAddNewContact: {
                        self.hideAutocomplete()
                        NotificationCenter.default.post(name: .openAddContactDialog, object: nil)
                    }
                ))
            } else {
                contentView = AnyView(EmojiAutocompleteView(
                    matches: currentEmojiMatches,
                    selectedIndex: selectedIndex,
                    onSelect: { match in
                        self.hideAutocomplete()
                        self.insertEmoji(match: match)
                    }
                ))
            }
            
            if let controller = popover?.contentViewController as? NSHostingController<AnyView> {
                controller.rootView = contentView
            }
        }

        private func showAutocomplete(type: String, query: String, rect: NSRect) {
            guard let webView = self.webView else { return }
            
            // If query changed, reset selection
            if self.autocompleteQuery != query {
                self.selectedIndex = 0
            }
            
            self.autocompleteType = type
            self.autocompleteQuery = query
            
            // Pre-calculate matches
            if type == "mention" {
                let descriptor = FetchDescriptor<Contact>(
                    predicate: #Predicate { $0.name.contains(query) || $0.username.contains(query) || $0.email.contains(query) },
                    sortBy: [SortDescriptor(\Contact.name)]
                )
                let contacts = (try? parent.modelContext.fetch(descriptor)) ?? []
                var items = contacts.map { AutocompleteItem(match: .person(Person(id: $0.email, name: $0.name, email: $0.email))) }
                if let date = DateService.parse(query) {
                    items.insert(AutocompleteItem(match: .date(date)), at: 0)
                }
                self.currentMentionMatches = items
            } else {
                self.currentEmojiMatches = EmojiService.findMatches(for: query)
            }
            
            let contentView: AnyView
            if type == "mention" {
                contentView = AnyView(ContactAutocompleteView(
                    items: currentMentionMatches,
                    selectedIndex: selectedIndex,
                    onSelect: { match in
                        self.hideAutocomplete()
                        self.insertAutocomplete(match: match)
                    },
                    onAddNewContact: {
                        self.hideAutocomplete()
                        NotificationCenter.default.post(name: .openAddContactDialog, object: nil)
                    }
                ))
            } else {
                contentView = AnyView(EmojiAutocompleteView(
                    matches: currentEmojiMatches,
                    selectedIndex: selectedIndex,
                    onSelect: { match in
                        self.hideAutocomplete()
                        self.insertEmoji(match: match)
                    }
                ))
            }
            
            if popover == nil {
                popover = NSPopover()
                popover?.behavior = .transient
                popover?.contentViewController = NSHostingController(rootView: contentView)
            } else {
                // Update existing popover's view to avoid jumps
                if let controller = popover?.contentViewController as? NSHostingController<AnyView> {
                    controller.rootView = contentView
                }
            }
            
            // WKWebView is a flipped view (0,0 at top-left), just like the JS viewport.
            // So we can use the coordinates from JS directly.
            // We anchor to the bottom edge of the cursor (maxY) to show the popover below.
            let anchorRect = rect
            
            // Fixed preferred size to prevent jumps during typing
            popover?.contentSize = NSSize(width: type == "mention" ? 250 : 200, height: 200)
            
            if !(popover?.isShown ?? false) {
                popover?.show(relativeTo: anchorRect, of: webView, preferredEdge: .maxY)
            } else {
                // Reposition if the anchor changed
                popover?.show(relativeTo: anchorRect, of: webView, preferredEdge: .maxY)
            }
            
            // Re-focus the webView immediately but on the next run loop to ensure 
            // the popover has finished its initial appearance logic.
            DispatchQueue.main.async {
                webView.window?.makeFirstResponder(webView)
            }
        }
        
        private func hideAutocomplete() {
            popover?.performClose(nil)
            popover = nil
            currentMentionMatches = []
            currentEmojiMatches = []
            selectedIndex = 0
        }
        
        private func mentionAutocompleteView(query: String) -> some View {
            let descriptor = FetchDescriptor<Contact>(
                predicate: #Predicate { $0.name.contains(query) || $0.username.contains(query) || $0.email.contains(query) },
                sortBy: [SortDescriptor(\Contact.name)]
            )
            let contacts = (try? parent.modelContext.fetch(descriptor)) ?? []
            let items = contacts.map { AutocompleteItem(match: .person(Person(id: $0.email, name: $0.name, email: $0.email))) }
            
            // Add date option if it matches
            var finalItems = items
            if let date = DateService.parse(query) {
                finalItems.insert(AutocompleteItem(match: .date(date)), at: 0)
            }
            
            return ContactAutocompleteView(
                items: finalItems,
                selectedIndex: 0,
                onSelect: { match in
                    self.hideAutocomplete()
                    self.insertAutocomplete(match: match)
                },
                onAddNewContact: {
                    self.hideAutocomplete()
                    NotificationCenter.default.post(name: .openAddContactDialog, object: nil)
                }
            )
        }
        
        private func emojiAutocompleteView(query: String) -> some View {
            let matches = EmojiService.findMatches(for: query)
            return EmojiAutocompleteView(
                matches: matches,
                selectedIndex: 0,
                onSelect: { match in
                    self.hideAutocomplete()
                    self.insertEmoji(match: match)
                }
            )
        }
        
        private func insertAutocomplete(match: AutocompleteMatch) {
            let text: String
            switch match {
            case .person(let person):
                text = "[@\(person.name)](mailto:\(person.email))"
            case .date(let date):
                text = "[@\(date.formatted(date: .abbreviated, time: .omitted))](updoc://date)"
            }
            
            // We need to replace the trigger char (@query)
            let queryLen = (autocompleteQuery?.count ?? 0) + 1 // +1 for @
            
            // MUST focus webview first because popover has focus
            webView?.becomeFirstResponder()
            self.replaceText(with: text, back: queryLen)
        }
        
        private func insertEmoji(match: EmojiMatch) {
            let text = match.emoji
            let queryLen = (autocompleteQuery?.count ?? 0) + 1 // +1 for :
            
            // MUST focus webview first
            webView?.becomeFirstResponder()
            self.replaceText(with: text, back: queryLen)
        }
        
        private func replaceText(with text: String, back: Int) {
            guard let webView else { return }
            
            // Better: call insertText with the current position - back
            webView.evaluateJavaScript("""
                (function() {
                    const view = window.updoc.getEditorView();
                    if (!view) return;
                    view.focus();
                    const pos = view.state.selection.main.head;
                    window.updoc.insertText(`\(text)`, pos - \(back), pos);
                })()
            """)
        }

        // MARK: Bridge helpers

        func loadContent(_ text: String) {
            guard isEditorReady, let webView else {
                pendingContent = text
                return
            }
            lastKnownText = text
            let escaped = text
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
            webView.evaluateJavaScript("window.updoc.loadContent(`\(escaped)`)")
        }

        func scrollToRange(from: Int, to: Int) {
            guard isEditorReady, let webView else { return }
            webView.evaluateJavaScript("window.updoc.scrollToRange(\(from), \(to))")
        }

        func setReadOnly(_ readOnly: Bool) {
            guard isEditorReady, let webView else { return }
            webView.evaluateJavaScript("window.updoc.setReadOnly(\(readOnly))")
        }

        func applyTheme() {
            guard isEditorReady, let webView else { return }
            guard let theme = ThemeManager.shared.getTheme(named: parent.theme) else { return }
            let vars = theme.cssVariables()
            guard let data = try? JSONSerialization.data(withJSONObject: vars),
                  let json = String(data: data, encoding: .utf8) else { return }
            webView.evaluateJavaScript("window.updoc.setTheme(\(json))")
            lastThemeName = parent.theme
        }
    }
}

private extension WKWebView {
    @discardableResult
    func evaluateJavaScript(_ script: String) -> WKWebView {
        evaluateJavaScript(script, completionHandler: nil)
        return self
    }
}
