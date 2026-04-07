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
}

public struct GDocsInsertInlineImageRequest: Codable {
    public let uri: String
    public let location: GDocsLocation
}

public struct GDocsUpdateEmbeddedObjectPropertiesRequest: Codable {
    public let objectId: String
    public let properties: GDocsEmbeddedObjectProperties
    public let fields: String
}

public struct GDocsEmbeddedObjectProperties: Codable {
    public let description: String?
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
