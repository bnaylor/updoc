import SwiftUI
import Observation

public enum AppTheme: String, CaseIterable, Identifiable, Codable, Sendable {
    case modern = "Modern"
    case serif = "Serif"
    case mono = "Mono"
    case cyberpunk = "Cyberpunk"
    case solarized = "Solarized"
    public var id: String { rawValue }
}

@Observable
@MainActor
public class ThemeManager {
    public static let shared = ThemeManager()
    public var currentThemeName: String = UserDefaults.standard.string(forKey: "currentThemeName") ?? AppTheme.modern.rawValue {
        didSet {
            UserDefaults.standard.set(currentThemeName, forKey: "currentThemeName")
        }
    }
    public var customThemes: [CustomTheme] = []
    
    public var allThemeNames: [String] {
        AppTheme.allCases.map { $0.rawValue } + customThemes.map { $0.name }
    }
    
    public init() {
        loadCustomThemes()
    }
    
    public func loadCustomThemes() {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let themesURL = appSupport.appendingPathComponent("updoc/Themes", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: themesURL.path) {
            do {
                try fileManager.createDirectory(at: themesURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Error creating themes directory in load: \(error)")
            }
            return // No themes to load yet
        }
        
        do {
            let files = try fileManager.contentsOfDirectory(at: themesURL, includingPropertiesForKeys: nil)
            let jsonFiles = files.filter { $0.pathExtension == "json" }
            
            var loadedThemes: [CustomTheme] = []
            let decoder = JSONDecoder()
            
            for file in jsonFiles {
                if let data = try? Data(contentsOf: file),
                   let theme = try? decoder.decode(CustomTheme.self, from: data) {
                    loadedThemes.append(theme)
                }
            }
            
            self.customThemes = loadedThemes
        } catch {
            print("Error loading custom themes: \(error)")
        }
    }
    
    public func customTheme(from preset: AppTheme) -> CustomTheme {
        let baseSize = bodyFontSize
        let textColor = textColor(for: preset)
        let backgroundColor = backgroundColor(for: preset)
        
        // Resolve heading color
        let headingColor: NSColor
        switch preset {
        case .modern: headingColor = textColor
        case .serif: headingColor = NSColor(calibratedRed: 0.4, green: 0.3, blue: 0.2, alpha: 1.0)
        case .mono: headingColor = textColor
        case .cyberpunk: headingColor = NSColor(calibratedRed: 1.0, green: 0.0, blue: 0.5, alpha: 1.0)
        case .solarized: headingColor = NSColor(calibratedRed: 0.79, green: 0.29, blue: 0.09, alpha: 1.0)
        }
        
        return CustomTheme(
            name: preset.rawValue,
            backgroundColor: backgroundColor.hexString,
            textColor: textColor.hexString,
            headingColor: headingColor.hexString,
            blockquoteColor: textColor.withAlphaComponent(0.7).hexString,
            highlightColor: NSColor.systemYellow.withAlphaComponent(0.3).hexString,
            linkColor: NSColor.systemBlue.hexString,
            fontFamily: preset == .serif ? "serif" : (preset == .mono ? "mono" : "system"),
            fontSize: baseSize,
            headingFontFamily: preset == .serif ? "serif" : (preset == .mono ? "mono" : "system"),
            headingFontSize: baseSize + 10,
            blockquoteFontFamily: preset == .serif ? "serif" : (preset == .mono ? "mono" : "system"),
            blockquoteFontSize: baseSize,
            codeColor: textColor.hexString,
            codeBackgroundColor: NSColor.quaternaryLabelColor.hexString,
            codeFontFamily: "mono",
            codeFontSize: baseSize - 1,
            bulletColor: NSColor.systemOrange.hexString,
            horizontalRuleColor: textColor.hexString
        )
    }
    
    public func getTheme(named name: String) -> CustomTheme? {
        if let custom = customThemes.first(where: { $0.name == name }) {
            return custom
        }
        if let preset = AppTheme(rawValue: name) {
            return customTheme(from: preset)
        }
        return nil
    }
    
    public func saveCustomTheme(_ theme: CustomTheme) {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let themesURL = appSupport.appendingPathComponent("updoc/Themes", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: themesURL.path) {
            do {
                try fileManager.createDirectory(at: themesURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Error creating themes directory: \(error)")
                return
            }
        }
        
        let fileURL = themesURL.appendingPathComponent("\(theme.name).json")
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(theme)
            try data.write(to: fileURL, options: .atomic)
            
            // Refresh list
            loadCustomThemes()
        } catch {
            print("Error saving custom theme: \(error)")
        }
    }
    
    public func deleteCustomTheme(named name: String) {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let themesURL = appSupport.appendingPathComponent("updoc/Themes", isDirectory: true)
        let fileURL = themesURL.appendingPathComponent("\(name).json")
        
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
                loadCustomThemes()
                
                if currentThemeName == name {
                    currentThemeName = AppTheme.modern.rawValue
                }
            }
        } catch {
            print("Error deleting custom theme: \(error)")
        }
    }
    
    public func themeName(for note: Note?) -> String {
        return note?.themeName ?? currentThemeName
    }
    
    public func backgroundColor(for theme: AppTheme) -> NSColor {
        switch theme {
        case .modern: return .textBackgroundColor
        case .serif: return NSColor(calibratedRed: 0.96, green: 0.94, blue: 0.90, alpha: 1.0)
        case .mono: return NSColor(calibratedRed: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        case .cyberpunk: return NSColor(calibratedRed: 0.05, green: 0.01, blue: 0.13, alpha: 1.0)
        case .solarized: return NSColor(calibratedRed: 0.0, green: 0.17, blue: 0.21, alpha: 1.0)
        }
    }
    
    public func backgroundColor(for themeName: String) -> NSColor {
        if let custom = customThemes.first(where: { $0.name == themeName }) {
            return NSColor(hex: custom.backgroundColor) ?? .textBackgroundColor
        }
        if let preset = AppTheme(rawValue: themeName) {
            return backgroundColor(for: preset)
        }
        return .textBackgroundColor
    }
    
    public func backgroundColor(for note: Note?) -> NSColor {
        return backgroundColor(for: themeName(for: note))
    }
    
    public func textColor(for theme: AppTheme) -> NSColor {
        switch theme {
        case .modern: return .textColor
        case .serif: return NSColor(calibratedRed: 0.2, green: 0.15, blue: 0.1, alpha: 1.0)
        case .mono: return NSColor(calibratedRed: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)
        case .cyberpunk: return NSColor(calibratedRed: 0.0, green: 1.0, blue: 1.0, alpha: 1.0)
        case .solarized: return NSColor(calibratedRed: 0.51, green: 0.58, blue: 0.59, alpha: 1.0)
        }
    }
    
    public func textColor(for themeName: String) -> NSColor {
        if let custom = customThemes.first(where: { $0.name == themeName }) {
            return NSColor(hex: custom.textColor) ?? .textColor
        }
        if let preset = AppTheme(rawValue: themeName) {
            return textColor(for: preset)
        }
        return .textColor
    }
    
    public func textColor(for note: Note?) -> NSColor {
        return textColor(for: themeName(for: note))
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
        case .cyberpunk:
            return .monospacedSystemFont(ofSize: bodyFontSize, weight: .regular)
        case .solarized:
            return .systemFont(ofSize: bodyFontSize)
        }
    }
    
    public func font(for themeName: String) -> NSFont {
        if let custom = customThemes.first(where: { $0.name == themeName }) {
            let size = custom.fontSize
            switch custom.fontFamily {
            case "serif": return NSFont.serifFont(ofSize: size)
            case "mono": return .monospacedSystemFont(ofSize: size, weight: .regular)
            default: return .systemFont(ofSize: size)
            }
        }
        if let preset = AppTheme(rawValue: themeName) {
            return font(for: preset)
        }
        return .systemFont(ofSize: bodyFontSize)
    }
    
    public func font(for note: Note?) -> NSFont {
        return font(for: themeName(for: note))
    }
    
    public var font: NSFont { font(for: nil) }
    public var backgroundColor: NSColor { backgroundColor(for: nil) }
    public var textColor: NSColor { textColor(for: nil) }
    
    public func swiftUIBackgroundColor(for note: Note?) -> Color { Color(backgroundColor(for: note)) }
    public func swiftUITextColor(for note: Note?) -> Color { Color(textColor(for: note)) }
    
    public var swiftUIBackgroundColor: Color { swiftUIBackgroundColor(for: nil) }
    public var swiftUITextColor: Color { swiftUITextColor(for: nil) }
    public func attributes(for style: MarkdownStyle, inCustomTheme custom: CustomTheme) -> [NSAttributedString.Key: Any] {
        let baseFont = font(for: custom.name)
        let baseSize = bodyFontSize
        let textColor = NSColor(hex: custom.textColor) ?? .textColor
        
        switch style {
        case .heading(let level):
            let baseHeadingSize = custom.headingFontSize ?? (baseSize + 10)
            let size = max(baseHeadingSize - CGFloat(level - 1) * 2, 12)
            
            let font: NSFont
            if let family = custom.headingFontFamily {
                switch family {
                case "serif": font = NSFont.serifFont(ofSize: size)
                case "mono": font = .monospacedSystemFont(ofSize: size, weight: .bold)
                default: font = .systemFont(ofSize: size, weight: .bold)
                }
            } else {
                let boldFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
                font = boldFont.withSize(size)
            }
            
            let headingColor = NSColor(hex: custom.headingColor) ?? textColor
            return [
                .font: font,
                .foregroundColor: headingColor
            ]
        case .blockquote:
            let size = custom.blockquoteFontSize ?? baseSize
            let font: NSFont
            if let family = custom.blockquoteFontFamily {
                switch family {
                case "serif": font = NSFont.serifFont(ofSize: size)
                case "mono": font = .monospacedSystemFont(ofSize: size, weight: .regular)
                default: font = .systemFont(ofSize: size)
                }
            } else {
                font = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask).withSize(size)
            }
            
            let quoteColor = NSColor(hex: custom.blockquoteColor) ?? textColor.withAlphaComponent(0.7)
            return [
                .font: font,
                .foregroundColor: quoteColor
            ]
        case .highlight:
            let highlightColor = NSColor(hex: custom.highlightColor) ?? NSColor.systemYellow.withAlphaComponent(0.3)
            return [
                .backgroundColor: highlightColor,
                .foregroundColor: textColor
            ]
        case .image(let url, let title):
            let linkColor = NSColor(hex: custom.linkColor) ?? NSColor.systemGreen
            return [
                .foregroundColor: linkColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .toolTip: title ?? url
            ]
        case .code, .codeBlock:
            let size = custom.codeFontSize ?? (baseSize - 1)
            let font: NSFont
            if let family = custom.codeFontFamily {
                switch family {
                case "serif": font = NSFont.serifFont(ofSize: size)
                case "mono": font = .monospacedSystemFont(ofSize: size, weight: .regular)
                default: font = .systemFont(ofSize: size)
                }
            } else {
                font = .monospacedSystemFont(ofSize: size, weight: .regular)
            }
            
            let cColor = custom.codeColor.flatMap { NSColor(hex: $0) } ?? textColor
            let bg = custom.codeBackgroundColor.flatMap { NSColor(hex: $0) } ?? NSColor.quaternaryLabelColor
            
            return [
                .font: font,
                .foregroundColor: cColor,
                .backgroundColor: bg
            ]
        case .bullet:
            let bColor = custom.bulletColor.flatMap { NSColor(hex: $0) } ?? textColor
            return [
                .font: baseFont,
                .foregroundColor: bColor
            ]
        case .horizontalRule:
            let hrColor = custom.horizontalRuleColor.flatMap { NSColor(hex: $0) } ?? textColor
            return [
                .foregroundColor: NSColor.clear,
                .horizontalRule: true,
                .horizontalRuleColor: hrColor
            ]
        default:
            var attrs = attributes(for: style, in: .modern) // Fallback to modern preset for base attributes!
            attrs[.foregroundColor] = textColor
            return attrs
        }
    }
    
    public func attributes(for style: MarkdownStyle, in themeName: String) -> [NSAttributedString.Key: Any] {
        if let custom = customThemes.first(where: { $0.name == themeName }) {
            return attributes(for: style, inCustomTheme: custom)
        }
        if let preset = AppTheme(rawValue: themeName) {
            return attributes(for: style, in: preset)
        }
        return attributes(for: style, in: .modern)
    }

    public func attributes(for style: MarkdownStyle, in theme: AppTheme) -> [NSAttributedString.Key: Any] {
        let baseFont = font(for: theme)
        let baseSize = bodyFontSize
        let textColor = textColor(for: theme)
        
        switch style {
        case .heading(let level):
            let size: CGFloat = level == 1 ? baseSize + 10 : (level == 2 ? baseSize + 6 : (level == 3 ? baseSize + 4 : (level == 4 ? baseSize + 2 : baseSize)))
            let boldFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
            
            let headingColor: NSColor
            switch theme {
            case .modern: headingColor = textColor
            case .serif: headingColor = NSColor(calibratedRed: 0.4, green: 0.3, blue: 0.2, alpha: 1.0)
            case .mono: headingColor = textColor
            case .cyberpunk: headingColor = NSColor(calibratedRed: 1.0, green: 0.0, blue: 0.5, alpha: 1.0) // Neon Pink
            case .solarized: headingColor = NSColor(calibratedRed: 0.79, green: 0.29, blue: 0.09, alpha: 1.0) // Solarized Orange
            }
            
            return [
                .font: boldFont.withSize(size),
                .foregroundColor: headingColor
            ]
        case .bold:
            let boldFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
            return [
                .font: boldFont,
                .foregroundColor: textColor
            ]
        case .italic:
            let italicFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
            return [
                .font: italicFont,
                .foregroundColor: textColor
            ]
        case .underline:
            return [
                .font: baseFont,
                .foregroundColor: textColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
        case .code:
            return [
                .font: NSFont.monospacedSystemFont(ofSize: baseSize - 1, weight: .regular),
                .foregroundColor: textColor,
                .backgroundColor: NSColor.quaternaryLabelColor
            ]
        case .codeBlock:
            return [
                .font: NSFont.monospacedSystemFont(ofSize: baseSize - 1, weight: .regular),
                .foregroundColor: textColor,
                .backgroundColor: NSColor.quaternaryLabelColor
            ]
        case .checklist(let done, let level):
            let style = NSMutableParagraphStyle()
            let baseIndent: CGFloat = 20
            let indentPerLevel: CGFloat = 20
            style.firstLineHeadIndent = baseIndent + CGFloat(level) * indentPerLevel
            style.headIndent = style.firstLineHeadIndent + 15
            
            var attrs: [NSAttributedString.Key: Any] = [
                .font: baseFont,
                .paragraphStyle: style
            ]
            
            if done {
                attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                attrs[.foregroundColor] = NSColor.secondaryLabelColor
            } else {
                attrs[.foregroundColor] = NSColor.labelColor
            }
            return attrs
            
        case .bullet(let level):
            let style = NSMutableParagraphStyle()
            let baseIndent: CGFloat = 20
            let indentPerLevel: CGFloat = 20
            style.firstLineHeadIndent = baseIndent + CGFloat(level) * indentPerLevel
            style.headIndent = style.firstLineHeadIndent + 15
            
            return [
                .font: baseFont,
                .foregroundColor: textColor,
                .paragraphStyle: style
            ]
        case .link(let urlString):
            if let urlString = urlString, urlString.hasPrefix("updoc://") {
                return [
                    .foregroundColor: NSColor.labelColor,
                    NSAttributedString.Key("smartChip"): true,
                    NSAttributedString.Key("smartChipColor"): NSColor.systemOrange,
                    NSAttributedString.Key("smartChipURL"): urlString
                ]
            }
            
            var attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.systemBlue,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
            if let urlString = urlString, let url = URL(string: urlString) {
                attrs[.link] = url
            }
            return attrs
        case .image(let url, let title):
            return [
                .foregroundColor: NSColor.systemGreen,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .toolTip: title ?? url
            ]
        case .strikethrough:
            return [
                .foregroundColor: textColor,
                .strikethroughStyle: NSUnderlineStyle.single.rawValue
            ]
        case .blockquote:
            let italicFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
            let quoteColor: NSColor
            switch theme {
            case .modern: quoteColor = NSColor.secondaryLabelColor
            case .serif: quoteColor = NSColor(calibratedRed: 0.4, green: 0.35, blue: 0.3, alpha: 1.0)
            case .mono: quoteColor = textColor.withAlphaComponent(0.7)
            case .cyberpunk: quoteColor = NSColor(calibratedRed: 0.5, green: 0.0, blue: 0.5, alpha: 1.0) // Purple
            case .solarized: quoteColor = NSColor(calibratedRed: 0.34, green: 0.43, blue: 0.45, alpha: 1.0) // Solarized Base01
            }
            return [
                .font: italicFont,
                .foregroundColor: quoteColor
            ]
        case .horizontalRule:
            return [
                .foregroundColor: NSColor.clear,
                .horizontalRule: true,
                .horizontalRuleColor: textColor
            ]
        case .highlight:
            let highlightColor: NSColor
            let highlightTextColor: NSColor
            switch theme {
            case .modern:
                highlightColor = NSColor.systemYellow.withAlphaComponent(0.3)
                highlightTextColor = textColor
            case .serif:
                highlightColor = NSColor.systemOrange.withAlphaComponent(0.2)
                highlightTextColor = textColor
            case .mono:
                highlightColor = textColor
                highlightTextColor = NSColor.black
            case .cyberpunk:
                highlightColor = NSColor(calibratedRed: 1.0, green: 1.0, blue: 0.0, alpha: 1.0) // Neon Yellow
                highlightTextColor = NSColor.black
            case .solarized:
                highlightColor = NSColor(calibratedRed: 0.71, green: 0.53, blue: 0.0, alpha: 1.0) // Solarized Yellow
                highlightTextColor = NSColor(calibratedRed: 0.0, green: 0.17, blue: 0.21, alpha: 1.0) // Base03
            }
            return [
                .backgroundColor: highlightColor,
                .foregroundColor: highlightTextColor
            ]
        case .boldItalic:
            let boldFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
            let boldItalicFont = NSFontManager.shared.convert(boldFont, toHaveTrait: .italicFontMask)
            return [
                .font: boldItalicFont,
                .foregroundColor: textColor
            ]
        }
    }
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

public struct CustomTheme: Codable, Sendable, Identifiable {
    public var id: String { name }
    public var name: String
    public var backgroundColor: String // Hex "#RRGGBB"
    public var textColor: String // Hex "#RRGGBB"
    
    public var headingColor: String // Hex "#RRGGBB"
    public var blockquoteColor: String // Hex "#RRGGBB"
    public var highlightColor: String // Hex "#RRGGBB"
    public var linkColor: String // Hex "#RRGGBB"
    
    public var fontFamily: String // "system", "serif", "mono"
    public var fontSize: CGFloat
    
    // Granular font overrides
    public var headingFontFamily: String?
    public var headingFontSize: CGFloat?
    public var blockquoteFontFamily: String?
    public var blockquoteFontSize: CGFloat?
    
    // Code formatting overrides
    public var codeColor: String?
    public var codeBackgroundColor: String?
    public var codeFontFamily: String?
    public var codeFontSize: CGFloat?
    
    // Additional element overrides
    public var bulletColor: String?
    public var horizontalRuleColor: String?
    
    public init(name: String, backgroundColor: String, textColor: String, headingColor: String, blockquoteColor: String, highlightColor: String, linkColor: String, fontFamily: String = "system", fontSize: CGFloat = 16, headingFontFamily: String? = nil, headingFontSize: CGFloat? = nil, blockquoteFontFamily: String? = nil, blockquoteFontSize: CGFloat? = nil, codeColor: String? = nil, codeBackgroundColor: String? = nil, codeFontFamily: String? = nil, codeFontSize: CGFloat? = nil, bulletColor: String? = nil, horizontalRuleColor: String? = nil) {
        self.name = name
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.headingColor = headingColor
        self.blockquoteColor = blockquoteColor
        self.highlightColor = highlightColor
        self.linkColor = linkColor
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.headingFontFamily = headingFontFamily
        self.headingFontSize = headingFontSize
        self.blockquoteFontFamily = blockquoteFontFamily
        self.blockquoteFontSize = blockquoteFontSize
        self.codeColor = codeColor
        self.codeBackgroundColor = codeBackgroundColor
        self.codeFontFamily = codeFontFamily
        self.codeFontSize = codeFontSize
        self.bulletColor = bulletColor
        self.horizontalRuleColor = horizontalRuleColor
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        backgroundColor = try container.decode(String.self, forKey: .backgroundColor)
        textColor = try container.decode(String.self, forKey: .textColor)
        headingColor = try container.decode(String.self, forKey: .headingColor)
        blockquoteColor = try container.decode(String.self, forKey: .blockquoteColor)
        highlightColor = try container.decode(String.self, forKey: .highlightColor)
        linkColor = try container.decode(String.self, forKey: .linkColor)
        
        fontFamily = try container.decodeIfPresent(String.self, forKey: .fontFamily) ?? "system"
        fontSize = try container.decodeIfPresent(CGFloat.self, forKey: .fontSize) ?? 16
        
        headingFontFamily = try container.decodeIfPresent(String.self, forKey: .headingFontFamily)
        headingFontSize = try container.decodeIfPresent(CGFloat.self, forKey: .headingFontSize)
        blockquoteFontFamily = try container.decodeIfPresent(String.self, forKey: .blockquoteFontFamily)
        blockquoteFontSize = try container.decodeIfPresent(CGFloat.self, forKey: .blockquoteFontSize)
        
        codeColor = try container.decodeIfPresent(String.self, forKey: .codeColor)
        codeBackgroundColor = try container.decodeIfPresent(String.self, forKey: .codeBackgroundColor)
        codeFontFamily = try container.decodeIfPresent(String.self, forKey: .codeFontFamily)
        codeFontSize = try container.decodeIfPresent(CGFloat.self, forKey: .codeFontSize)
        
        bulletColor = try container.decodeIfPresent(String.self, forKey: .bulletColor)
        horizontalRuleColor = try container.decodeIfPresent(String.self, forKey: .horizontalRuleColor)
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var cString: String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if cString.hasPrefix("#") {
            cString.remove(at: cString.startIndex)
        }

        if cString.count != 6 {
            return nil
        }

        var rgbValue: UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)

        self.init(
            calibratedRed: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }
    
    var hexString: String {
        guard let rgbColor = self.usingColorSpace(.deviceRGB) else {
            return "#000000"
        }
        let red = Int(rgbColor.redComponent * 255)
        let green = Int(rgbColor.greenComponent * 255)
        let blue = Int(rgbColor.blueComponent * 255)
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
