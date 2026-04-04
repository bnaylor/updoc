import Foundation

public struct TagManager {
    public init() {}
    
    public func extractTags(from content: String) -> Set<String> {
        let pattern = "(^|\\s)#([a-zA-Z0-9_\\-\\/]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        let matches = regex.matches(in: content, range: range)
        
        var tags = Set<String>()
        for match in matches {
            if match.numberOfRanges >= 3 {
                let tagRange = match.range(at: 2)
                if let swiftRange = Range(tagRange, in: content) {
                    let tag = String(content[swiftRange])
                    tags.insert(tag)
                }
            }
        }
        
        return tags
    }
    
    public func getAllTags(in notes: [Note]) -> [String] {
        var allTags = Set<String>()
        for note in notes {
            let tags = extractTags(from: note.content)
            allTags.formUnion(tags)
        }
        return allTags.sorted()
    }
}
