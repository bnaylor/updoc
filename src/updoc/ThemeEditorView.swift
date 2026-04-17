import SwiftUI

struct ThemeEditorView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var themeName: String = "New Theme"
    @State private var backgroundColor: Color = .white
    @State private var textColor: Color = .black
    @State private var headingColor: Color = .blue
    @State private var blockquoteColor: Color = .gray
    @State private var highlightColor: Color = .yellow
    @State private var linkColor: Color = .green
    @State private var fontFamily: String = "system"
    @State private var fontSize: CGFloat = 16
    
    @State private var headingFontFamily: String = "system"
    @State private var headingFontSize: CGFloat = 26
    @State private var blockquoteFontFamily: String = "system"
    @State private var blockquoteFontSize: CGFloat = 16
    
    @State private var codeColor: Color = .black
    @State private var codeBackgroundColor: Color = .gray.opacity(0.2)
    @State private var codeFontFamily: String = "mono"
    @State private var codeFontSize: CGFloat = 14
    
    @State private var bulletColor: Color = .orange
    @State private var horizontalRuleColor: Color = .gray
    
    init(theme: CustomTheme? = nil) {
        if let theme = theme {
            _themeName = State(initialValue: theme.name)
            _backgroundColor = State(initialValue: Color(NSColor(hex: theme.backgroundColor) ?? .white))
            _textColor = State(initialValue: Color(NSColor(hex: theme.textColor) ?? .black))
            _headingColor = State(initialValue: Color(NSColor(hex: theme.headingColor) ?? .blue))
            _blockquoteColor = State(initialValue: Color(NSColor(hex: theme.blockquoteColor) ?? .gray))
            _highlightColor = State(initialValue: Color(NSColor(hex: theme.highlightColor) ?? .yellow))
            _linkColor = State(initialValue: Color(NSColor(hex: theme.linkColor) ?? .green))
            _fontFamily = State(initialValue: theme.fontFamily)
            _fontSize = State(initialValue: theme.fontSize)
            
            _headingFontFamily = State(initialValue: theme.headingFontFamily ?? "system")
            _headingFontSize = State(initialValue: theme.headingFontSize ?? 26)
            _blockquoteFontFamily = State(initialValue: theme.blockquoteFontFamily ?? "system")
            _blockquoteFontSize = State(initialValue: theme.blockquoteFontSize ?? 16)
            
            _codeColor = State(initialValue: Color(theme.codeColor.flatMap { NSColor(hex: $0) } ?? NSColor.black))
            _codeBackgroundColor = State(initialValue: Color(theme.codeBackgroundColor.flatMap { NSColor(hex: $0) } ?? NSColor.gray.withAlphaComponent(0.2)))
            _codeFontFamily = State(initialValue: theme.codeFontFamily ?? "mono")
            _codeFontSize = State(initialValue: theme.codeFontSize ?? 14)
            
            _bulletColor = State(initialValue: Color(theme.bulletColor.flatMap { NSColor(hex: $0) } ?? NSColor.systemOrange))
            _horizontalRuleColor = State(initialValue: Color(theme.horizontalRuleColor.flatMap { NSColor(hex: $0) } ?? NSColor.gray))
        }
    }
    
    var body: some View {
        Form {
            Section(header: Text("Theme Info")) {
                TextField("Theme Name", text: $themeName)
            }
            
            Section(header: Text("Base Colors")) {
                ColorPicker("Background Color", selection: $backgroundColor)
                ColorPicker("Text Color", selection: $textColor)
            }
            
            Section(header: Text("Headings")) {
                ColorPicker("Color", selection: $headingColor)
                Picker("Font", selection: $headingFontFamily) {
                    Text("System").tag("system")
                    Text("Serif").tag("serif")
                    Text("Mono").tag("mono")
                }
                .pickerStyle(.segmented)
                HStack {
                    Text("Size (\(Int(headingFontSize))pt)")
                    Slider(value: $headingFontSize, in: 16...36, step: 1)
                }
            }
            
            Section(header: Text("Blockquote")) {
                ColorPicker("Color", selection: $blockquoteColor)
                Picker("Font", selection: $blockquoteFontFamily) {
                    Text("System").tag("system")
                    Text("Serif").tag("serif")
                    Text("Mono").tag("mono")
                }
                .pickerStyle(.segmented)
                HStack {
                    Text("Size (\(Int(blockquoteFontSize))pt)")
                    Slider(value: $blockquoteFontSize, in: 10...24, step: 1)
                }
            }
            
            Section(header: Text("Code")) {
                ColorPicker("Text Color", selection: $codeColor)
                ColorPicker("Background Color", selection: $codeBackgroundColor)
                Picker("Font", selection: $codeFontFamily) {
                    Text("System").tag("system")
                    Text("Serif").tag("serif")
                    Text("Mono").tag("mono")
                }
                .pickerStyle(.segmented)
                HStack {
                    Text("Size (\(Int(codeFontSize))pt)")
                    Slider(value: $codeFontSize, in: 10...24, step: 1)
                }
            }
            
            Section(header: Text("Other Elements")) {
                ColorPicker("Highlight Color", selection: $highlightColor)
                ColorPicker("Link Color", selection: $linkColor)
                ColorPicker("Bullet Color", selection: $bulletColor)
                ColorPicker("Horizontal Rule Color", selection: $horizontalRuleColor)
            }
            
            Section(header: Text("Fonts")) {
                Picker("Font Family", selection: $fontFamily) {
                    Text("System").tag("system")
                    Text("Serif").tag("serif")
                    Text("Monospaced").tag("mono")
                }
                .pickerStyle(.segmented)
                
                HStack {
                    Text("Font Size (\(Int(fontSize))pt)")
                    Slider(value: $fontSize, in: 10...24, step: 1)
                }
            }
        }
        .padding()
        .navigationTitle("Edit Theme")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveTheme()
                    dismiss()
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .frame(minWidth: 400, minHeight: 500)
    }
    
    private func saveTheme() {
        let customTheme = CustomTheme(
            name: themeName,
            backgroundColor: NSColor(backgroundColor).hexString,
            textColor: NSColor(textColor).hexString,
            headingColor: NSColor(headingColor).hexString,
            blockquoteColor: NSColor(blockquoteColor).hexString,
            highlightColor: NSColor(highlightColor).hexString,
            linkColor: NSColor(linkColor).hexString,
            fontFamily: fontFamily,
            fontSize: fontSize,
            headingFontFamily: headingFontFamily,
            headingFontSize: headingFontSize,
            blockquoteFontFamily: blockquoteFontFamily,
            blockquoteFontSize: blockquoteFontSize,
            codeColor: NSColor(codeColor).hexString,
            codeBackgroundColor: NSColor(codeBackgroundColor).hexString,
            codeFontFamily: codeFontFamily,
            codeFontSize: codeFontSize,
            bulletColor: NSColor(bulletColor).hexString,
            horizontalRuleColor: NSColor(horizontalRuleColor).hexString
        )
        themeManager.saveCustomTheme(customTheme)
    }
}
