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
    
    public func theme(for note: Note?) -> AppTheme {
        if let themeName = note?.themeName, let theme = AppTheme(rawValue: themeName) {
            return theme
        }
        return currentTheme
    }
    
    public func backgroundColor(for theme: AppTheme) -> NSColor {
        switch theme {
        case .modern: return .textBackgroundColor
        case .serif: return NSColor(calibratedRed: 0.96, green: 0.94, blue: 0.90, alpha: 1.0)
        case .mono: return NSColor(calibratedRed: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        }
    }
    
    public func backgroundColor(for note: Note?) -> NSColor {
        return backgroundColor(for: theme(for: note))
    }
    
    public func textColor(for theme: AppTheme) -> NSColor {
        switch theme {
        case .modern: return .textColor
        case .serif: return NSColor(calibratedRed: 0.2, green: 0.15, blue: 0.1, alpha: 1.0)
        case .mono: return NSColor(calibratedRed: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)
        }
    }
    
    public func textColor(for note: Note?) -> NSColor {
        return textColor(for: theme(for: note))
    }
    
    public var bodyFontSize: CGFloat { 16 }
    
    public func font(for theme: AppTheme) -> NSFont {
        switch theme {
        case .modern:
            return .systemFont(ofSize: bodyFontSize)
        case .serif:
            return NSFont.serifFont(ofSize: bodyFontSize)
        case .mono:
            return .monospacedSystemFont(ofSize: bodyFontSize, weight: .regular)
        }
    }
    
    public func font(for note: Note?) -> NSFont {
        return font(for: theme(for: note))
    }
    
    public var font: NSFont { font(for: nil) }
    public var backgroundColor: NSColor { backgroundColor(for: nil) }
    public var textColor: NSColor { textColor(for: nil) }
    
    public func swiftUIBackgroundColor(for note: Note?) -> Color { Color(backgroundColor(for: note)) }
    public func swiftUITextColor(for note: Note?) -> Color { Color(textColor(for: note)) }
    
    public var swiftUIBackgroundColor: Color { swiftUIBackgroundColor(for: nil) }
    public var swiftUITextColor: Color { swiftUITextColor(for: nil) }
}

extension NSFont {
    static func serifFont(ofSize size: CGFloat) -> NSFont {
        // Try New York first (macOS system serif)
        if let font = NSFont(name: "New York", size: size) {
            return font
        }
        if let font = NSFont(name: "Times New Roman", size: size) {
            return font
        }
        return .systemFont(ofSize: size)
    }
}
