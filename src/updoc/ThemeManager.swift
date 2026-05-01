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
        
        // Resolve code background
        let codeBg: NSColor
        switch preset {
        case .modern: codeBg = NSColor.quaternaryLabelColor
        case .serif: codeBg = NSColor(calibratedRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.05)
        case .mono: codeBg = NSColor(calibratedRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.1)
        case .cyberpunk: codeBg = NSColor(calibratedRed: 0.0, green: 1.0, blue: 1.0, alpha: 0.1)
        case .solarized: codeBg = NSColor(calibratedRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.2)
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
            codeBackgroundColor: codeBg.hexString,
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

extension CustomTheme {
    /// Returns a dictionary of CSS custom property names → values
    /// suitable for pushing to the CM6 editor via window.updoc.setTheme().
    public func cssVariables() -> [String: String] {
        var vars: [String: String] = [
            "--updoc-bg":          backgroundColor,
            "--updoc-text":        textColor,
            "--updoc-heading":     headingColor,
            "--updoc-blockquote":  blockquoteColor,
            "--updoc-highlight":   highlightColor,
            "--updoc-link":        linkColor,
            "--updoc-font-size":   "\(Int(fontSize))px",
            "--updoc-font-family": Self.cssFontStack(fontFamily),
        ]
        if let v = codeColor           { vars["--updoc-code"]         = v }
        if let v = codeBackgroundColor { vars["--updoc-code-bg"]      = v }
        if let v = codeFontFamily      { vars["--updoc-code-font"]    = Self.cssFontStack(v) }
        if let v = codeFontSize        { vars["--updoc-code-size"]    = "\(Int(v))px" }
        if let v = bulletColor         { vars["--updoc-bullet"]       = v }
        if let v = horizontalRuleColor { vars["--updoc-hr"]           = v }
        if let v = headingFontFamily   { vars["--updoc-heading-font"] = Self.cssFontStack(v) }
        if let v = headingFontSize     { vars["--updoc-heading-size"] = "\(Int(v))px" }
        return vars
    }

    private static func cssFontStack(_ family: String) -> String {
        switch family {
        case "serif": return "'New York', 'Times New Roman', serif"
        case "mono":  return "'SF Mono', 'Menlo', monospace"
        default:      return "-apple-system, sans-serif"
        }
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var cString: String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if cString.hasPrefix("#") {
            cString.remove(at: cString.startIndex)
        }

        if cString.count == 6 {
            var rgbValue: UInt64 = 0
            Scanner(string: cString).scanHexInt64(&rgbValue)
            self.init(
                calibratedRed: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
                green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
                blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
                alpha: 1.0
            )
            return
        }

        if cString.count == 8 {
            var rgbaValue: UInt64 = 0
            Scanner(string: cString).scanHexInt64(&rgbaValue)
            self.init(
                calibratedRed: CGFloat((rgbaValue & 0xFF000000) >> 24) / 255.0,
                green: CGFloat((rgbaValue & 0x00FF0000) >> 16) / 255.0,
                blue: CGFloat((rgbaValue & 0x0000FF00) >> 8) / 255.0,
                alpha: CGFloat(rgbaValue & 0x000000FF) / 255.0
            )
            return
        }

        return nil
    }
    
    var hexString: String {
        guard let rgbColor = self.usingColorSpace(.deviceRGB) else {
            return "#000000FF"
        }
        let red = Int(rgbColor.redComponent * 255)
        let green = Int(rgbColor.greenComponent * 255)
        let blue = Int(rgbColor.blueComponent * 255)
        let alpha = Int(rgbColor.alphaComponent * 255)
        return String(format: "#%02X%02X%02X%02X", red, green, blue, alpha)
    }
}
