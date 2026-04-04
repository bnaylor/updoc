import AppKit

class RemoteImageAttachment: NSTextAttachment {
    let url: URL
    let title: String?
    let originalMarkdown: String
    
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
