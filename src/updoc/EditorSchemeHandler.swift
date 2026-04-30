import WebKit

/// Serves files from the app bundle's Resources/editor/ directory
/// in response to editor:// URL requests from WKWebView.
final class EditorSchemeHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url else {
            task.didFailWithError(URLError(.badURL))
            return
        }

        let fileName = url.lastPathComponent
        let nameWithoutExt = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension

        guard let resourceURL = Bundle.module.url(
            forResource: nameWithoutExt,
            withExtension: ext,
            subdirectory: "editor"
        ) else {
            task.didFailWithError(URLError(.fileDoesNotExist))
            return
        }

        do {
            let data = try Data(contentsOf: resourceURL)
            let mimeType: String
            switch ext {
            case "js":  mimeType = "application/javascript"
            case "css": mimeType = "text/css"
            default:    mimeType = "text/html"
            }
            let response = URLResponse(
                url: url,
                mimeType: mimeType,
                expectedContentLength: data.count,
                textEncodingName: "utf-8"
            )
            task.didReceive(response)
            task.didReceive(data)
            task.didFinish()
        } catch {
            task.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}
