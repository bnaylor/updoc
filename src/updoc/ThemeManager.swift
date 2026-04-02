import SwiftUI
import Observation

public enum AppTheme: String, CaseIterable, Identifiable, Codable, Sendable {
    case modern = "Modern"
    case serif = "Serif"
    case mono = "Mono"
    public var id: String { rawValue }
}

@Observable
@MainActor
public class ThemeManager {
    public static let shared = ThemeManager()
    public var currentTheme: AppTheme = .modern
    
    public init() {}
    
    public var fontName: String {
        switch currentTheme {
        case .modern: return "SF Pro"
        case .serif: return "New York"
        case .mono: return "SF Mono"
        }
    }
    
    public var bodyFontSize: CGFloat { 14 }
    
    public var font: NSFont {
        switch currentTheme {
        case .modern:
            return .systemFont(ofSize: bodyFontSize)
        case .serif:
            return NSFont.serifFont(ofSize: bodyFontSize)
        case .mono:
            return .monospacedSystemFont(ofSize: bodyFontSize, weight: .regular)
        }
    }
}

extension NSFont {
    static func serifFont(ofSize size: CGFloat) -> NSFont {
        if let font = NSFont(name: "Times New Roman", size: size) {
            return font
        }
        return .systemFont(ofSize: size)
    }
}
