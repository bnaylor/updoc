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
                var boundingRect = self.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                
                // Adjust for origin
                boundingRect.origin.x += origin.x
                boundingRect.origin.y += origin.y
                
                // For bullets, we want a slightly smaller font size than checkboxes
                let isBullet = symbolName == "circle.fill"
                let fontSize = isBullet ? baseFont.pointSize * 0.4 : baseFont.pointSize
                
                // Create the SF Symbol image
                let config = NSImage.SymbolConfiguration(pointSize: fontSize, weight: .regular)
                if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
                    // Tint the image with the label color
                    let tintedImage = NSImage(size: image.size)
                    tintedImage.lockFocus()
                    NSColor.labelColor.set()
                    let imageRect = NSRect(origin: .zero, size: image.size)
                    image.draw(in: imageRect, from: .zero, operation: .sourceOut, fraction: 1.0)
                    tintedImage.unlockFocus()
                    tintedImage.isTemplate = true
                    
                    // Center the symbol in the bounding rect vertically.
                    // For horizontal alignment, we put it slightly in from the left edge of the bounding rect.
                    let yOffset = boundingRect.midY - (image.size.height / 2.0)
                    
                    // If it's a bullet, center it horizontally in the space of a typical bullet, otherwise align left.
                    // Bullet syntax is `* `, so we center it. Checkbox syntax is `[ ] `, so left alignment looks ok.
                    // But actually, just aligning slightly right of the minX is very consistent.
                    let paddingX: CGFloat = isBullet ? 4.0 : 2.0
                    let xOffset = boundingRect.minX + paddingX
                    
                    let drawRect = NSRect(x: xOffset, y: yOffset, width: image.size.width, height: image.size.height)
                    
                    tintedImage.draw(in: drawRect)
                }
            }
        }
    }
}
