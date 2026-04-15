import AppKit

class EditorLayoutManager: NSLayoutManager {
    var baseFont: NSFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
    
    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
        
        guard let textStorage = self.textStorage, let textContainer = self.textContainers.first else { return }
        let charRange = self.characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        
        textStorage.enumerateAttribute(.listMarkerReplacement, in: charRange, options: []) { value, range, _ in
            if let symbolName = value as? String {
                let glyphRange = self.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                
                // GHOST FIX: Only draw if the current pass actually contains the first glyph of the marker.
                // TextKit calls drawBackground multiple times per line (selection, extra space, etc.)
                guard glyphsToShow.contains(glyphRange.location) else { return }
                
                // 1. Get the dynamic color from our dedicated attribute
                let color = textStorage.attribute(.listMarkerColor, at: range.location, effectiveRange: nil) as? NSColor ?? .labelColor
                
                // 2. Get precise character position using the line baseline
                var lineRect = self.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
                let glyphLocation = self.location(forGlyphAt: glyphRange.location)
                
                // Adjust for origin
                lineRect.origin.x += origin.x
                lineRect.origin.y += origin.y
                
                // For bullets, we want a slightly smaller font size than checkboxes
                let isBullet = symbolName == "circle.fill"
                let fontSize = isBullet ? baseFont.pointSize * 0.4 : baseFont.pointSize
                
                // Create the SF Symbol image
                let config = NSImage.SymbolConfiguration(pointSize: fontSize, weight: .regular)
                if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
                    // Tint the image with the dynamic color
                    let tintedImage = NSImage(size: image.size)
                    tintedImage.lockFocus()
                    color.set()
                    let imageRect = NSRect(origin: .zero, size: image.size)
                    image.draw(in: imageRect, from: .zero, operation: .sourceOut, fraction: 1.0)
                    tintedImage.unlockFocus()
                    tintedImage.isTemplate = true
                    
                    // 3. Vertical Baseline Alignment
                    // The baseline is at lineRect.minY + baseFont.ascender.
                    // We center the symbol around the middle of the cap height of the font.
                    let baselineY = lineRect.minY + baseFont.ascender
                    let capHeightCenterY = baselineY - (baseFont.capHeight / 2.0)
                    let yOffset = capHeightCenterY - (image.size.height / 2.0)
                    
                    // 4. Horizontal Alignment
                    // Center the symbol exactly in the middle of the first character's bounding box.
                    let firstCharGlyphRange = NSRange(location: glyphRange.location, length: 1)
                    let firstCharRect = self.boundingRect(forGlyphRange: firstCharGlyphRange, in: textContainer)
                    let xOffset = lineRect.minX + glyphLocation.x + (firstCharRect.width / 2.0) - (image.size.width / 2.0)
                    
                    let drawRect = NSRect(x: xOffset, y: yOffset, width: image.size.width, height: image.size.height)
                    
                    tintedImage.draw(in: drawRect)
                }
            }
        }
    }
}
