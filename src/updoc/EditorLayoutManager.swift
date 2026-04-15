import AppKit

class EditorLayoutManager: NSLayoutManager {
    var baseFont: NSFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
    
    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
        
        guard let textStorage = self.textStorage, let textContainer = self.textContainers.first else { return }
        let charRange = self.characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        
        textStorage.enumerateAttribute(.listMarkerReplacement, in: charRange, options: []) { value, range, _ in
            if let replacementString = value as? String {
                let glyphRange = self.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                var boundingRect = self.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                
                // Adjust for origin
                boundingRect.origin.x += origin.x
                boundingRect.origin.y += origin.y
                
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: baseFont,
                    .foregroundColor: NSColor.labelColor
                ]
                
                // Vertically center the replacement character roughly inside the bounding rect
                let stringSize = (replacementString as NSString).size(withAttributes: attributes)
                let drawPoint = NSPoint(
                    x: boundingRect.minX,
                    y: boundingRect.midY - (stringSize.height / 2.0)
                )
                
                (replacementString as NSString).draw(at: drawPoint, withAttributes: attributes)
            }
        }
    }
}
