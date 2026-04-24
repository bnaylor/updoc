import Foundation

extension String {
    public func extractDocId() -> String? {
        let pattern = "document/d/([^/]+)"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let nsString = self as NSString
        let results = regex?.matches(in: self, options: [], range: NSRange(location: 0, length: nsString.length))
        
        if let match = results?.first, match.numberOfRanges > 1 {
            return nsString.substring(with: match.range(at: 1))
        }
        return nil
    }
}
