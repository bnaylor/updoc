import Foundation

public struct GDocsDocument: Codable {
    public let documentId: String
    public let revisionId: String?
    public let title: String
    public let body: GDocsBody
    public let inlineObjects: [String: GDocsInlineObject]?
}

public struct GDocsInlineObject: Codable {
    public let objectId: String
    public let inlineObjectProperties: GDocsInlineObjectProperties
}

public struct GDocsInlineObjectProperties: Codable {
    public let embeddedObject: GDocsEmbeddedObject
}

public struct GDocsEmbeddedObject: Codable {
    public let title: String?
    public let description: String?
    public let imageProperties: GDocsImageProperties?
}

public struct GDocsImageProperties: Codable {
    public let contentUri: String?
}

public struct GDocsBody: Codable {
    public let content: [GDocsStructuralElement]
}

public struct GDocsStructuralElement: Codable {
    public let startIndex: Int?
    public let endIndex: Int?
    public let paragraph: GDocsParagraph?
}

public struct GDocsParagraph: Codable {
    public let elements: [GDocsParagraphElement]
    public let bullet: GDocsBullet?
    public let paragraphStyle: GDocsParagraphStyle?
    
    public init(elements: [GDocsParagraphElement], bullet: GDocsBullet? = nil, paragraphStyle: GDocsParagraphStyle? = nil) {
        self.elements = elements
        self.bullet = bullet
        self.paragraphStyle = paragraphStyle
    }
}

public struct GDocsBullet: Codable {
    public let listId: String?
    public let textStyle: GDocsTextStyle?
}

public struct GDocsParagraphElement: Codable {
    public let startIndex: Int?
    public let endIndex: Int?
    public let textRun: GDocsTextRun?
    public let inlineObjectElement: GDocsInlineObjectElement?
}

public struct GDocsInlineObjectElement: Codable {
    public let inlineObjectId: String
}

public struct GDocsTextRun: Codable {
    public let content: String?
    public let textStyle: GDocsTextStyle?
}

public struct GDocsTextStyle: Codable {
    public let bold: Bool?
    public let italic: Bool?
    public let underline: Bool?
    public let strikethrough: Bool?
    public let weightedFontFamily: GDocsWeightedFontFamily?
    public let link: GDocsLink?
    
    public init(bold: Bool? = nil, italic: Bool? = nil, underline: Bool? = nil, strikethrough: Bool? = nil, weightedFontFamily: GDocsWeightedFontFamily? = nil, link: GDocsLink? = nil) {
        self.bold = bold
        self.italic = italic
        self.underline = underline
        self.strikethrough = strikethrough
        self.weightedFontFamily = weightedFontFamily
        self.link = link
    }
}

public struct GDocsWeightedFontFamily: Codable {
    public let fontFamily: String
    public let weight: Int?
    
    public init(fontFamily: String, weight: Int? = nil) {
        self.fontFamily = fontFamily
        self.weight = weight
    }
}

public struct GDocsLink: Codable {
    public let url: String
    
    public init(url: String) {
        self.url = url
    }
}

public struct GDocsWriteControl: Codable {
    public let requiredRevisionId: String?
    
    public init(requiredRevisionId: String?) {
        self.requiredRevisionId = requiredRevisionId
    }
}

// Request models for batchUpdate
public struct GDocsBatchUpdateRequest: Codable {
    public let requests: [GDocsRequest]
    public let writeControl: GDocsWriteControl?

    public init(requests: [GDocsRequest], writeControl: GDocsWriteControl? = nil) {
        self.requests = requests
        self.writeControl = writeControl
    }
}

public struct GDocsRequest: Codable {
    public let insertText: GDocsInsertTextRequest?
    public let deleteContentRange: GDocsDeleteContentRangeRequest?
    public let insertInlineImage: GDocsInsertInlineImageRequest?
    public let updateEmbeddedObjectProperties: GDocsUpdateEmbeddedObjectPropertiesRequest?
    public let updateTextStyle: GDocsUpdateTextStyleRequest?
    public let updateParagraphStyle: GDocsUpdateParagraphStyleRequest?
    public let createParagraphBullets: GDocsCreateParagraphBulletsRequest?
    
    public init(insertText: GDocsInsertTextRequest? = nil, deleteContentRange: GDocsDeleteContentRangeRequest? = nil, insertInlineImage: GDocsInsertInlineImageRequest? = nil, updateEmbeddedObjectProperties: GDocsUpdateEmbeddedObjectPropertiesRequest? = nil, updateTextStyle: GDocsUpdateTextStyleRequest? = nil, updateParagraphStyle: GDocsUpdateParagraphStyleRequest? = nil, createParagraphBullets: GDocsCreateParagraphBulletsRequest? = nil) {
        self.insertText = insertText
        self.deleteContentRange = deleteContentRange
        self.insertInlineImage = insertInlineImage
        self.updateEmbeddedObjectProperties = updateEmbeddedObjectProperties
        self.updateTextStyle = updateTextStyle
        self.updateParagraphStyle = updateParagraphStyle
        self.createParagraphBullets = createParagraphBullets
    }
}

public struct GDocsCreateParagraphBulletsRequest: Codable {
    public let range: GDocsRange
    public let bulletPreset: String
    
    public init(range: GDocsRange, bulletPreset: String) {
        self.range = range
        self.bulletPreset = bulletPreset
    }
}

public struct GDocsUpdateTextStyleRequest: Codable {
    public let range: GDocsRange
    public let textStyle: GDocsTextStyle
    public let fields: String
    
    public init(range: GDocsRange, textStyle: GDocsTextStyle, fields: String) {
        self.range = range
        self.textStyle = textStyle
        self.fields = fields
    }
}

public struct GDocsUpdateParagraphStyleRequest: Codable {
    public let range: GDocsRange
    public let paragraphStyle: GDocsParagraphStyle
    public let fields: String
    
    public init(range: GDocsRange, paragraphStyle: GDocsParagraphStyle, fields: String) {
        self.range = range
        self.paragraphStyle = paragraphStyle
        self.fields = fields
    }
}

public struct GDocsParagraphStyle: Codable {
    public let namedStyleType: String?
    
    public init(namedStyleType: String?) {
        self.namedStyleType = namedStyleType
    }
}

public struct GDocsInsertInlineImageRequest: Codable {
    public let uri: String
    public let location: GDocsLocation
}

public struct GDocsUpdateEmbeddedObjectPropertiesRequest: Codable {
    public let objectId: String
    public let properties: GDocsEmbeddedObjectProperties
    public let fields: String
    
    public init(objectId: String, properties: GDocsEmbeddedObjectProperties, fields: String) {
        self.objectId = objectId
        self.properties = properties
        self.fields = fields
    }
}

public struct GDocsEmbeddedObjectProperties: Codable {
    public let description: String?
    
    public init(description: String?) {
        self.description = description
    }
}

public struct GDocsBatchUpdateResponse: Codable {
    public let replies: [GDocsReply]
}

public struct GDocsReply: Codable {
    public let insertInlineImage: GDocsInsertInlineImageReply?
}

public struct GDocsInsertInlineImageReply: Codable {
    public let objectId: String
}

public struct GDocsInsertTextRequest: Codable {
    public let text: String
    public let location: GDocsLocation
}

public struct GDocsDeleteContentRangeRequest: Codable {
    public let range: GDocsRange
}

public struct GDocsLocation: Codable {
    public let index: Int
}

public struct GDocsRange: Codable {
    public let startIndex: Int
    public let endIndex: Int
}
