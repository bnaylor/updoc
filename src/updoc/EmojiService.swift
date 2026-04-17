import Foundation

public struct EmojiMatch: Identifiable {
    public let shortcode: String
    public let emoji: String
    public var id: String { shortcode }
}

public struct EmojiService {
    public static let mapping: [String: String] = [
        ":smile:": "😄",
        ":rofl:": "🤣",
        ":rocket:": "🚀",
        ":heart:": "❤️",
        ":thumbsup:": "👍",
        ":thumbsdown:": "👎",
        ":eyes:": "👀",
        ":fire:": "🔥",
        ":party:": "🎉",
        ":star:": "⭐",
        ":checked:": "✅",
        ":warning:": "⚠️",
        ":information:": "ℹ️",
        ":question:": "❓",
        ":bulb:": "💡",
        ":100:": "💯",
        ":money:": "💰",
        ":time:": "⏰",
        ":date:": "📅",
        ":note:": "📝"
    ]
    
    public static func findMatches(for query: String) -> [EmojiMatch] {
        let lowercaseQuery = query.lowercased()
        return mapping.compactMap { shortcode, emoji in
            let code = shortcode.replacingOccurrences(of: ":", with: "")
            if code.lowercased().hasPrefix(lowercaseQuery) || query.isEmpty {
                return EmojiMatch(shortcode: shortcode, emoji: emoji)
            }
            return nil
        }
        .sorted { $0.shortcode < $1.shortcode }
    }
}
