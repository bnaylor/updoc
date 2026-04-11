import Foundation

public struct GDocsFormattedContent {
    public let cleanText: String
    public let requests: [GDocsRequest]
    public let imageSegments: [GDocsMarkdownFormatter.ImageSegment]
}

public struct GDocsMarkdownFormatter {
    public typealias ImageSegment = (index: Int, uri: String, assetId: String)
    public init() {}
    
    private struct Match {
        let range: NSRange
        let content: String
        let style: MarkdownStyle?
        let isImage: Bool
        let assetId: String?
    }

    public func format(_ markdown: String, assetMappings: [String: String] = [:]) -> GDocsFormattedContent {
        var cleanText = ""
        var requests: [GDocsRequest] = []
        var imageSegments: [ImageSegment] = []
        
        let lines = markdown.components(separatedBy: .newlines)
        var currentOffset = 1 // Google Docs body starts at index 1
        
        for (idx, line) in lines.enumerated() {
            let isLastLine = idx == lines.count - 1
            
            // 1. List check
            var bulletPreset: String? = nil
            var isStrikethrough = false
            var lineContent = line
            
            if line.hasPrefix("* ") || line.hasPrefix("- ") || line.hasPrefix("+ ") {
                bulletPreset = "BULLET_DISC_CIRCLE_SQUARE"
                lineContent = String(line.dropFirst(2))
            } else if line.hasPrefix("[ ] ") {
                bulletPreset = "BULLET_CHECKBOX"
                lineContent = String(line.dropFirst(4))
            } else if line.hasPrefix("[x] ") {
                bulletPreset = "BULLET_CHECKBOX"
                isStrikethrough = true
                lineContent = String(line.dropFirst(4))
            }
            
            // 2. Heading check (can be combined with bullet, but markdown rarely does that)
            var headingLevel: Int? = nil
            
            let headingRegex = try! NSRegularExpression(pattern: "^(#{1,6})\\s+(.*)$")
            if let match = headingRegex.firstMatch(in: lineContent, options: [], range: NSRange(lineContent.startIndex..., in: lineContent)) {
                headingLevel = match.range(at: 1).length
                let contentRange = match.range(at: 2)
                if let contentSwiftRange = Range(contentRange, in: lineContent) {
                    lineContent = String(lineContent[contentSwiftRange])
                }
            }
            
            // 3. Parse inline styles
            let (cleanedLine, lineRequests, lineImages) = parseInline(lineContent, baseOffset: currentOffset, assetMappings: assetMappings)
            
            let lineWithNewline = cleanedLine + (isLastLine ? "" : "\n")
            cleanText += lineWithNewline
            requests.append(contentsOf: lineRequests)
            imageSegments.append(contentsOf: lineImages)
            
            let lineRange = GDocsRange(startIndex: currentOffset, endIndex: currentOffset + cleanedLine.utf16.count)
            
            // 4. Apply list formatting
            if let preset = bulletPreset {
                requests.append(GDocsRequest(createBullet: GDocsCreateBulletRequest(range: lineRange, bulletPreset: preset)))
            }
            
            // 5. Apply strikethrough for completed tasks
            if isStrikethrough {
                requests.append(GDocsRequest(updateTextStyle: GDocsUpdateTextStyleRequest(range: lineRange, textStyle: GDocsTextStyle(strikethrough: true), fields: "strikethrough")))
            }
            
            // 6. Apply heading style if needed
            if let level = headingLevel {
                let style = GDocsParagraphStyle(namedStyleType: "HEADING_\(level)")
                requests.append(GDocsRequest(updateParagraphStyle: GDocsUpdateParagraphStyleRequest(range: lineRange, paragraphStyle: style, fields: "namedStyleType")))
            }
            
            currentOffset += lineWithNewline.utf16.count
        }
        
        return GDocsFormattedContent(cleanText: cleanText, requests: requests, imageSegments: imageSegments)
    }
    
    private func parseInline(_ text: String, baseOffset: Int, assetMappings: [String: String]) -> (String, [GDocsRequest], [ImageSegment]) {
        var matches: [Match] = []
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        
        // Find all matches for all supported styles
        
        // Bold **text**
        let boldRegex = try! NSRegularExpression(pattern: "\\*\\*(.*?)\\*\\*")
        boldRegex.enumerateMatches(in: text, options: [], range: fullRange) { m, _, _ in
            if let m = m {
                matches.append(Match(range: m.range(at: 0), content: nsText.substring(with: m.range(at: 1)), style: .bold, isImage: false, assetId: nil))
            }
        }
        
        // Italic *text* (try to avoid bold markers by checking around)
        let italicRegex = try! NSRegularExpression(pattern: "(?<!\\*)\\*([^\\*]+?)\\*(?!\\*)")
        italicRegex.enumerateMatches(in: text, options: [], range: fullRange) { m, _, _ in
            if let m = m {
                matches.append(Match(range: m.range(at: 0), content: nsText.substring(with: m.range(at: 1)), style: .italic, isImage: false, assetId: nil))
            }
        }
        
        // Underline __text__
        let underlineRegex = try! NSRegularExpression(pattern: "__(.*?)__")
        underlineRegex.enumerateMatches(in: text, options: [], range: fullRange) { m, _, _ in
            if let m = m {
                matches.append(Match(range: m.range(at: 0), content: nsText.substring(with: m.range(at: 1)), style: .underline, isImage: false, assetId: nil))
            }
        }
        
        // Code `text`
        let codeRegex = try! NSRegularExpression(pattern: "`(.*?)`")
        codeRegex.enumerateMatches(in: text, options: [], range: fullRange) { m, _, _ in
            if let m = m {
                matches.append(Match(range: m.range(at: 0), content: nsText.substring(with: m.range(at: 1)), style: .code, isImage: false, assetId: nil))
            }
        }
        
        // Links [text](url)
        let linkRegex = try! NSRegularExpression(pattern: "\\[(.*?)\\]\\((.*?)\\)")
        linkRegex.enumerateMatches(in: text, options: [], range: fullRange) { m, _, _ in
            if let m = m {
                let content = nsText.substring(with: m.range(at: 1))
                let url = nsText.substring(with: m.range(at: 2))
                matches.append(Match(range: m.range(at: 0), content: content, style: .link(url: url), isImage: false, assetId: nil))
            }
        }
        
        // Assets ![[id]]
        let assetRegex = try! NSRegularExpression(pattern: "!\\[\\[(.*?)\\]\\]")
        assetRegex.enumerateMatches(in: text, options: [], range: fullRange) { m, _, _ in
            if let m = m {
                let id = nsText.substring(with: m.range(at: 1))
                matches.append(Match(range: m.range(at: 0), content: " ", style: nil, isImage: true, assetId: id))
            }
        }
        
        // Sort matches by location to process left-to-right correctly while building clean string
        let sortedMatches = matches.sorted { $0.range.location < $1.range.location }
        
        var cleanedText = ""
        var requests: [GDocsRequest] = []
        var images: [ImageSegment] = []
        var lastOriginalIndex = 0
        var currentCleanOffset = 0
        
        for m in sortedMatches {
            if m.range.location < lastOriginalIndex { continue } // Skip overlapping matches
            
            // Add text before the match
            let prefixRange = NSRange(location: lastOriginalIndex, length: m.range.location - lastOriginalIndex)
            let prefix = nsText.substring(with: prefixRange)
            cleanedText += prefix
            currentCleanOffset += prefix.utf16.count
            
            let cleanStart = baseOffset + currentCleanOffset
            
            if m.isImage, let id = m.assetId, let uri = assetMappings[id] {
                images.append((cleanStart, uri, id))
                cleanedText += " " // Placeholder space for the image
                currentCleanOffset += 1
            } else {
                cleanedText += m.content
                let cleanEnd = cleanStart + m.content.utf16.count
                currentCleanOffset += m.content.utf16.count
                
                if let style = m.style {
                    let range = GDocsRange(startIndex: cleanStart, endIndex: cleanEnd)
                    switch style {
                    case .bold:
                        requests.append(GDocsRequest(updateTextStyle: GDocsUpdateTextStyleRequest(range: range, textStyle: GDocsTextStyle(bold: true), fields: "bold")))
                    case .italic:
                        requests.append(GDocsRequest(updateTextStyle: GDocsUpdateTextStyleRequest(range: range, textStyle: GDocsTextStyle(italic: true), fields: "italic")))
                    case .underline:
                        requests.append(GDocsRequest(updateTextStyle: GDocsUpdateTextStyleRequest(range: range, textStyle: GDocsTextStyle(underline: true), fields: "underline")))
                    case .code:
                        requests.append(GDocsRequest(updateTextStyle: GDocsUpdateTextStyleRequest(range: range, textStyle: GDocsTextStyle(weightedFontFamily: GDocsWeightedFontFamily(fontFamily: "Courier New")), fields: "weightedFontFamily")))
                    case .link(let url):
                        if let url = url {
                            requests.append(GDocsRequest(updateTextStyle: GDocsUpdateTextStyleRequest(range: range, textStyle: GDocsTextStyle(link: GDocsLink(url: url)), fields: "link")))
                        }
                    default: break
                    }
                }
            }
            
            lastOriginalIndex = m.range.location + m.range.length
        }
        
        // Add remaining text after last match
        if lastOriginalIndex < nsText.length {
            cleanedText += nsText.substring(with: NSRange(location: lastOriginalIndex, length: nsText.length - lastOriginalIndex))
        }
        
        return (cleanedText, requests, images)
    }
}
