import Foundation

public enum MarkdownStyle: Equatable {
    case heading(level: Int)
    case bold
    case italic
    case code
    case link(url: String?)
    case checklist(done: Bool)
}

public struct MarkdownRange: Equatable {
    public let range: NSRange
    public let style: MarkdownStyle
    
    public init(range: NSRange, style: MarkdownStyle) {
        self.range = range
        self.style = style
    }
}

public struct MarkdownEngine {
    public init() {}
    
    public func parse(_ text: String) -> [MarkdownRange] {
        var ranges: [MarkdownRange] = []
        let fullRange = NSRange(text.startIndex..., in: text)
        
        // 1. Headings (e.g., # Heading)
        let headingRegex = try! NSRegularExpression(pattern: "^#{1,6}\\s+.*$", options: [.anchorsMatchLines])
        headingRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            if let matchRange = match?.range {
                // Determine level by counting # symbols
                let line = (text as NSString).substring(with: matchRange)
                let level = line.prefix { $0 == "#" }.count
                ranges.append(MarkdownRange(range: matchRange, style: .heading(level: level)))
            }
        }
        
        // 2. Bold (e.g., **bold**)
        let boldRegex = try! NSRegularExpression(pattern: "\\*\\*.*?\\*\\*", options: [])
        boldRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            if let matchRange = match?.range {
                ranges.append(MarkdownRange(range: matchRange, style: .bold))
            }
        }
        
        // 3. Italic (e.g., *italic*)
        // Note: We use a lookbehind/lookahead to avoid matching bold delimiters
        let italicRegex = try! NSRegularExpression(pattern: "(?<!\\*)\\*[^\\*]+?\\*(?!\\*)", options: [])
        italicRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            if let matchRange = match?.range {
                ranges.append(MarkdownRange(range: matchRange, style: .italic))
            }
        }
        
        // 4. Checklist (e.g., [ ], [x], or √)
        let checklistRegex = try! NSRegularExpression(pattern: "^(\\s*)(\\[[ x]\\]|√)\\s+.*$", options: [.anchorsMatchLines])
        checklistRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            if let matchRange = match?.range {
                let line = (text as NSString).substring(with: matchRange)
                let done = line.contains("[x]") || line.contains("√")
                ranges.append(MarkdownRange(range: matchRange, style: .checklist(done: done)))
            }
        }
        
        return ranges
    }
}
