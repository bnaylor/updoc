import SwiftUI
import WebKit
import AppKit

struct CodeMirrorEditorView: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectionRange: NSRange?
    var theme: String
    var isReadOnly: Bool

    @AppStorage("spellcheckEnabled") private var spellcheckEnabled: Bool = true
    @AppStorage("autocorrectEnabled") private var autocorrectEnabled: Bool = true
    @Environment(ThemeManager.self) private var themeManager

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

        private var isEditorReady = false
        private var pendingContent: String?

        init(_ parent: CodeMirrorEditorView) {
            self.parent = parent
        }

        deinit {
            webView?.configuration.userContentController.removeAllScriptMessageHandlers()
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
            case "logging":
                if let msg = message.body as? String {
                    print("[JS] \(msg)")
                } else {
                    print("[JS] \(message.body)")
                }
            default:
                break
            }
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
