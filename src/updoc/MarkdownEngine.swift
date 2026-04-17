import Foundation

public enum MarkdownStyle: Equatable {
    case heading(level: Int)
    case bold
    case italic
    case underline
    case code
    case link(url: String?)
    case checklist(done: Bool)
    case bullet
    case image(url: String, title: String?)
    case strikethrough
    case blockquote
    case horizontalRule
    case highlight
    case boldItalic
    case codeBlock
}

public struct MarkdownRange: Equatable {
    public let range: NSRange
    public let style: MarkdownStyle
    public let syntaxRanges: [NSRange]
    
    public init(range: NSRange, style: MarkdownStyle, syntaxRanges: [NSRange] = []) {
        self.range = range
        self.style = style
        self.syntaxRanges = syntaxRanges
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
                // Syntax is the '#'s plus the following space
                let syntaxRange = NSRange(location: matchRange.location, length: level + 1)
                ranges.append(MarkdownRange(range: matchRange, style: .heading(level: level), syntaxRanges: [syntaxRange]))
            }
        }
        
        // 2. Bold (e.g., **bold**)
        let boldRegex = try! NSRegularExpression(pattern: "\\*\\*.*?\\*\\*", options: [])
        boldRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            if let matchRange = match?.range {
                let startSyntax = NSRange(location: matchRange.location, length: 2)
                let endSyntax = NSRange(location: matchRange.location + matchRange.length - 2, length: 2)
                ranges.append(MarkdownRange(range: matchRange, style: .bold, syntaxRanges: [startSyntax, endSyntax]))
            }
        }
        
        // Bold with underscore (e.g., __bold__)
        let boldUnderscoreRegex = try! NSRegularExpression(pattern: "__.*?__", options: [])
        boldUnderscoreRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            if let matchRange = match?.range {
                let startSyntax = NSRange(location: matchRange.location, length: 2)
                let endSyntax = NSRange(location: matchRange.location + matchRange.length - 2, length: 2)
                ranges.append(MarkdownRange(range: matchRange, style: .bold, syntaxRanges: [startSyntax, endSyntax]))
            }
        }
        
        // Highlight (e.g., ==highlight==)
        let highlightRegex = try! NSRegularExpression(pattern: "==.*?==", options: [])
        highlightRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            if let matchRange = match?.range {
                let startSyntax = NSRange(location: matchRange.location, length: 2)
                let endSyntax = NSRange(location: matchRange.location + matchRange.length - 2, length: 2)
                ranges.append(MarkdownRange(range: matchRange, style: .highlight, syntaxRanges: [startSyntax, endSyntax]))
            }
        }
        
        // Strikethrough (e.g., ~~strikethrough~~)
        let strikethroughRegex = try! NSRegularExpression(pattern: "~~.*?~~", options: [])
        strikethroughRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            if let matchRange = match?.range {
                let startSyntax = NSRange(location: matchRange.location, length: 2)
                let endSyntax = NSRange(location: matchRange.location + matchRange.length - 2, length: 2)
                ranges.append(MarkdownRange(range: matchRange, style: .strikethrough, syntaxRanges: [startSyntax, endSyntax]))
            }
        }
        
        // 3. Italic (e.g., *italic*)
        // Note: We use a lookbehind/lookahead to avoid matching bold delimiters
        let italicRegex = try! NSRegularExpression(pattern: "(?<!\\*)\\*[^\\*\\n]+?\\*(?!\\*)", options: [])
        italicRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            if let matchRange = match?.range {
                let startSyntax = NSRange(location: matchRange.location, length: 1)
                let endSyntax = NSRange(location: matchRange.location + matchRange.length - 1, length: 1)
                ranges.append(MarkdownRange(range: matchRange, style: .italic, syntaxRanges: [startSyntax, endSyntax]))
            }
        }
        
        // Italic with underscore (e.g., _italic_)
        let italicUnderscoreRegex = try! NSRegularExpression(pattern: "(?<!_)_[^_\\n]+?_(?!_)", options: [])
        italicUnderscoreRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            if let matchRange = match?.range {
                let startSyntax = NSRange(location: matchRange.location, length: 1)
                let endSyntax = NSRange(location: matchRange.location + matchRange.length - 1, length: 1)
                ranges.append(MarkdownRange(range: matchRange, style: .italic, syntaxRanges: [startSyntax, endSyntax]))
            }
        }
        
        let underlineRegex = try! NSRegularExpression(pattern: "(?<!~)~[^~\\n]+?~(?!~)", options: [])
        underlineRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            if let matchRange = match?.range {
                let startSyntax = NSRange(location: matchRange.location, length: 1)
                let endSyntax = NSRange(location: matchRange.location + matchRange.length - 1, length: 1)
                ranges.append(MarkdownRange(range: matchRange, style: .underline, syntaxRanges: [startSyntax, endSyntax]))
            }
        }
        
        // Inline Code (e.g., `code`)
        let codeRegex = try! NSRegularExpression(pattern: "`.*?`", options: [])
        codeRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            if let matchRange = match?.range {
                let startSyntax = NSRange(location: matchRange.location, length: 1)
                let endSyntax = NSRange(location: matchRange.location + matchRange.length - 1, length: 1)
                ranges.append(MarkdownRange(range: matchRange, style: .code, syntaxRanges: [startSyntax, endSyntax]))
            }
        }
        
        // Code Block (e.g., ```code```)
        let codeBlockRegex = try! NSRegularExpression(pattern: "```[\\s\\S]*?```", options: [])
        codeBlockRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            if let matchRange = match?.range {
                let startSyntax = NSRange(location: matchRange.location, length: 3)
                let endSyntax = NSRange(location: matchRange.location + matchRange.length - 3, length: 3)
                ranges.append(MarkdownRange(range: matchRange, style: .codeBlock, syntaxRanges: [startSyntax, endSyntax]))
            }
        }
        
        // 4. Checklist (e.g., [ ], [x], or √)
        let checklistRegex = try! NSRegularExpression(pattern: "^(\\s*)(\\[[ x]\\]|√)\\s+(.*)$", options: [.anchorsMatchLines])
        checklistRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            if let match = match, match.numberOfRanges >= 3 {
                let markerRange = match.range(at: 2)
                let marker = (text as NSString).substring(with: markerRange)
                let done = marker == "[x]" || marker == "√"
                // Hide the marker plus the trailing space
                let syntaxRange = NSRange(location: markerRange.location, length: markerRange.length + 1)
                ranges.append(MarkdownRange(range: match.range, style: .checklist(done: done), syntaxRanges: [syntaxRange]))
            }
        }
        
        // Blockquote (e.g., > quote)
        let blockquoteRegex = try! NSRegularExpression(pattern: "^>\\s+.*$", options: [.anchorsMatchLines])
        blockquoteRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            if let matchRange = match?.range {
                let syntaxRange = NSRange(location: matchRange.location, length: 2) // "> "
                ranges.append(MarkdownRange(range: matchRange, style: .blockquote, syntaxRanges: [syntaxRange]))
            }
        }
        
        // Horizontal Rule (e.g., ---)
        let hrRegex = try! NSRegularExpression(pattern: "^---$|^-{3,}$", options: [.anchorsMatchLines])
        hrRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            if let matchRange = match?.range {
                ranges.append(MarkdownRange(range: matchRange, style: .horizontalRule))
            }
        }
        
        // Combined Bold/Italic (e.g., ***bold italic***)
        let boldItalicRegex = try! NSRegularExpression(pattern: "\\*\\*\\*.*?\\*\\*\\*", options: [])
        boldItalicRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            if let matchRange = match?.range {
                let startSyntax = NSRange(location: matchRange.location, length: 3)
                let endSyntax = NSRange(location: matchRange.location + matchRange.length - 3, length: 3)
                ranges.append(MarkdownRange(range: matchRange, style: .boldItalic, syntaxRanges: [startSyntax, endSyntax]))
            }
        }
        
        // 5. Images (e.g., ![title](url))
        let imageRegex = try! NSRegularExpression(pattern: "!\\[(.*?)\\]\\((.*?)\\)", options: [])
        imageRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            if let match = match, match.numberOfRanges >= 3 {
                let titleRange = match.range(at: 1)
                let urlRange = match.range(at: 2)
                let title = (text as NSString).substring(with: titleRange)
                let url = (text as NSString).substring(with: urlRange)
                
                let startSyntax = NSRange(location: match.range.location, length: 2) // "!["
                let endSyntax = NSRange(location: titleRange.location + titleRange.length, length: match.range.location + match.range.length - (titleRange.location + titleRange.length)) // "](url)"
                
                ranges.append(MarkdownRange(range: match.range, style: .image(url: url, title: title.isEmpty ? nil : title), syntaxRanges: [startSyntax, endSyntax]))
            }
        }
        
        // 6. Local Assets (e.g., ![[assetId]])
        let assetRegex = try! NSRegularExpression(pattern: "!\\[\\[(.*?)\\]\\]", options: [])
        assetRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            if let match = match, match.numberOfRanges >= 2 {
                let idRange = match.range(at: 1)
                let id = (text as NSString).substring(with: idRange)
                ranges.append(MarkdownRange(range: match.range, style: .image(url: "asset://\(id)", title: nil)))
            }
        }
        
        // Links (e.g., [title](url))
        let linkRegex = try! NSRegularExpression(pattern: "(?<!\\!)\\[(.*?)\\]\\((.*?)\\)", options: [])
        linkRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            if let match = match, match.numberOfRanges >= 3 {
                let titleRange = match.range(at: 1)
                let urlRange = match.range(at: 2)
                let url = (text as NSString).substring(with: urlRange)
                
                let startSyntax = NSRange(location: match.range.location, length: 1)
                let endSyntax = NSRange(location: titleRange.location + titleRange.length, length: match.range.location + match.range.length - (titleRange.location + titleRange.length))
                
                ranges.append(MarkdownRange(range: match.range, style: .link(url: url.isEmpty ? nil : url), syntaxRanges: [startSyntax, endSyntax]))
            }
        }
        
        // 7. Bullets (e.g., * Bullet)
        let bulletRegex = try! NSRegularExpression(pattern: "^(\\s*)[*+-]\\s+(.*)$", options: [.anchorsMatchLines])
        bulletRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            if let matchRange = match?.range, match!.numberOfRanges >= 3 {
                let spaceRange = match!.range(at: 1)
                let markerStart = matchRange.location + spaceRange.length
                // Syntax is just bullet character + trailing space
                let syntaxRange = NSRange(location: markerStart, length: 2)
                ranges.append(MarkdownRange(range: matchRange, style: .bullet, syntaxRanges: [syntaxRange]))
            }
        }
        
        // Raw URLs (e.g., http://foo.com)
        let rawUrlRegex = try! NSRegularExpression(pattern: "https?://[^\\s]+", options: [])
        let rawMatches = rawUrlRegex.matches(in: text, options: [], range: fullRange)
        
        for match in rawMatches {
            let matchRange = match.range
            // Check if this range overlaps with any existing range
            let overlaps = ranges.contains { existing in
                NSIntersectionRange(existing.range, matchRange).length > 0
            }
            if !overlaps {
                let url = (text as NSString).substring(with: matchRange)
                ranges.append(MarkdownRange(range: matchRange, style: .link(url: url)))
            }
        }
        
        return ranges
    }
}
