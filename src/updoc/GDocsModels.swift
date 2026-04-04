import Foundation

public struct GDocsDocument: Codable {
    public let documentId: String
    public let title: String
    public let body: GDocsBody
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
}

public struct GDocsTextRun: Codable {
    public let content: String?
}

// Request models for batchUpdate
public struct GDocsBatchUpdateRequest: Codable {
    public let requests: [GDocsRequest]
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
