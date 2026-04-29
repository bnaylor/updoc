import Testing
import Foundation
@testable import updoc

struct ThemeCSSTests {
    @Test func modernThemeProducesRequiredCSSVars() {
        let theme = CustomTheme(
            name: "Modern",
            backgroundColor: "#FFFFFF",
            textColor: "#000000",
            headingColor: "#333333",
            blockquoteColor: "#666666",
            highlightColor: "#FFFF00",
            linkColor: "#0000FF",
            fontFamily: "system",
            fontSize: 16
        )
        let vars = theme.cssVariables()

        #expect(vars["--updoc-bg"] == "#FFFFFF")
        #expect(vars["--updoc-text"] == "#000000")
        #expect(vars["--updoc-heading"] == "#333333")
        #expect(vars["--updoc-blockquote"] == "#666666")
        #expect(vars["--updoc-highlight"] == "#FFFF00")
        #expect(vars["--updoc-link"] == "#0000FF")
        #expect(vars["--updoc-font-size"] == "16px")
        #expect(vars["--updoc-font-family"] == "-apple-system, sans-serif")
    }

    @Test func monoFontFamilyMapsToMonospace() {
        let theme = CustomTheme(
            name: "Mono",
            backgroundColor: "#111111",
            textColor: "#00FF00",
            headingColor: "#00FF00",
            blockquoteColor: "#00CC00",
            highlightColor: "#FFFF00",
            linkColor: "#00FFFF",
            fontFamily: "mono",
            fontSize: 14
        )
        let vars = theme.cssVariables()
        #expect(vars["--updoc-font-family"] == "'SF Mono', 'Menlo', monospace")
    }

    @Test func optionalCodeColorAppearsWhenSet() {
        var theme = CustomTheme(
            name: "Test",
            backgroundColor: "#FFF",
            textColor: "#000",
            headingColor: "#000",
            blockquoteColor: "#555",
            highlightColor: "#FF0",
            linkColor: "#00F",
            fontFamily: "system",
            fontSize: 16
        )
        theme.codeColor = "#CC0000"
        theme.codeBackgroundColor = "#F5F5F5"
        let vars = theme.cssVariables()
        #expect(vars["--updoc-code"] == "#CC0000")
        #expect(vars["--updoc-code-bg"] == "#F5F5F5")
    }
}
