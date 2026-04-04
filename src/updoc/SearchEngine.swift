import Foundation

public struct SearchResult: Identifiable, Sendable {
    public let id = UUID()
    public let note: Note
    public let snippets: [SearchSnippet]
    
    public init(note: Note, snippets: [SearchSnippet]) {
        self.note = note
        self.snippets = snippets
    }
}

public struct SearchSnippet: Identifiable, Sendable {
    public let id = UUID()
    public let text: String
    public let matchRange: NSRange // Range of the match within 'text'
    public let absoluteRange: NSRange // Range of the match within the original content
    
    public init(text: String, matchRange: NSRange, absoluteRange: NSRange) {
        self.text = text
        self.matchRange = matchRange
        self.absoluteRange = absoluteRange
    }
}

public struct SearchEngine {
    public init() {}
    
    public func search(query: String, in notes: [Note]) -> [SearchResult] {
        guard !query.isEmpty else { return [] }
        
        return notes.compactMap { note in
            let snippets = generateSnippets(for: query, in: note.content)
            let titleMatches = note.title.localizedCaseInsensitiveContains(query)
            
            guard titleMatches || !snippets.isEmpty else { return nil }
            return SearchResult(note: note, snippets: snippets)
        }
    }
    
    private func generateSnippets(for query: String, in content: String) -> [SearchSnippet] {
        guard !query.isEmpty else { return [] }
        
        var snippets: [SearchSnippet] = []
        let snippetLength = 40
        
        let nsContent = content as NSString
        var searchRange = NSRange(location: 0, length: nsContent.length)
        
        while searchRange.location < nsContent.length {
            let matchRange = nsContent.range(of: query, options: .caseInsensitive, range: searchRange)
            guard matchRange.location != NSNotFound else { break }
            
            let start = max(0, matchRange.location - snippetLength)
            let end = min(nsContent.length, matchRange.location + matchRange.length + snippetLength)
            let length = end - start
            
            let snippetText = nsContent.substring(with: NSRange(location: start, length: length))
            let relativeMatchRange = NSRange(location: matchRange.location - start, length: matchRange.length)
            
            snippets.append(SearchSnippet(text: snippetText, matchRange: relativeMatchRange, absoluteRange: matchRange))
            
            searchRange.location = matchRange.location + matchRange.length
            searchRange.length = nsContent.length - searchRange.location
        }
        
        return snippets
    }
}
