import AppKit
import QuickLookUI

class RemoteImageAttachment: NSTextAttachment, QLPreviewItem {
    let url: URL
    let title: String?
    let originalMarkdown: String
    
    // QLPreviewItem conformance
    var previewItemURL: URL? { url }
    var previewItemTitle: String? { title }

    init(url: URL, title: String?, originalMarkdown: String) {
        self.url = url
        self.title = title
        self.originalMarkdown = originalMarkdown
        super.init(data: nil, ofType: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
