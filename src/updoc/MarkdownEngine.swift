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
        
        // 4. Underline (e.g., __underline__)
        let underlineRegex = try! NSRegularExpression(pattern: "__.*?__", options: [])
        underlineRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            if let matchRange = match?.range {
                let startSyntax = NSRange(location: matchRange.location, length: 2)
                let endSyntax = NSRange(location: matchRange.location + matchRange.length - 2, length: 2)
                ranges.append(MarkdownRange(range: matchRange, style: .underline, syntaxRanges: [startSyntax, endSyntax]))
            }
        }
        
        // 4. Checklist (e.g., [ ], [x], or √)
        let checklistRegex = try! NSRegularExpression(pattern: "^(\\s*)(\\[[ x]\\]|√)\\s+(.*)$", options: [.anchorsMatchLines])
        checklistRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            if let match = match, match.numberOfRanges >= 3 {
                let markerRange = match.range(at: 2)
                let marker = (text as NSString).substring(with: markerRange)
                let done = marker == "[x]" || marker == "√"
                // Hide up to the space after the marker
                let syntaxLen = (markerRange.location - match.range.location) + markerRange.length + 1
                let syntaxRange = NSRange(location: match.range.location, length: syntaxLen)
                ranges.append(MarkdownRange(range: match.range, style: .checklist(done: done), syntaxRanges: [syntaxRange]))
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
                // Images usually stay visible, but we can hide the ![]() syntax if we want.
                // For now, let's just leave images as they were since they are rendered as attachments.
                ranges.append(MarkdownRange(range: match.range, style: .image(url: url, title: title.isEmpty ? nil : title)))
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
        
        // 7. Bullets (e.g., * Bullet)
        let bulletRegex = try! NSRegularExpression(pattern: "^(\\s*)[*+-]\\s+(.*)$", options: [.anchorsMatchLines])
        bulletRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            if let matchRange = match?.range, match!.numberOfRanges >= 3 {
                let spaceRange = match!.range(at: 1)
                // Syntax is leading space + bullet character + trailing space
                let syntaxRange = NSRange(location: matchRange.location, length: spaceRange.length + 2)
                ranges.append(MarkdownRange(range: matchRange, style: .bullet, syntaxRanges: [syntaxRange]))
            }
        }
        
        return ranges
    }
}
