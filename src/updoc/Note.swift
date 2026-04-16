import Foundation
import SwiftData

@Model
public class Note {
    public var title: String
    public var content: String
    public var createdAt: Date
    public var googleDocId: String?
    public var lastSyncedRevision: String?
    public var lastSyncedLocalContent: String?
    public var assetIds: [String] = []
    public var categories: [String] = []
    public var meetingID: String?
    public var isWeeklyLog: Bool = false
    public var weeklyLogId: String?
    @Relationship(deleteRule: .nullify, inverse: \Folder.notes)
    public var folder: Folder?
    public var themeName: String?
    public var dragId: String = UUID().uuidString
    
    public init(title: String, content: String, createdAt: Date = .now, googleDocId: String? = nil, lastSyncedRevision: String? = nil, lastSyncedLocalContent: String? = nil, assetIds: [String] = [], categories: [String] = [], meetingID: String? = nil, isWeeklyLog: Bool = false, weeklyLogId: String? = nil, folder: Folder? = nil, dragId: String = UUID().uuidString, themeName: String? = nil) {
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.googleDocId = googleDocId
        self.lastSyncedRevision = lastSyncedRevision
        self.lastSyncedLocalContent = lastSyncedLocalContent
        self.assetIds = assetIds
        self.categories = categories
        self.meetingID = meetingID
        self.isWeeklyLog = isWeeklyLog
        self.weeklyLogId = weeklyLogId
        self.folder = folder
        self.dragId = dragId
        self.themeName = themeName
    }
    
    public var stableDragId: String {
        "\(createdAt.timeIntervalSince1970)-\(title)"
    }
}

// Add Hashable and Sendable conformance for SwiftUI navigation and concurrency
extension Note: Hashable, @unchecked Sendable {
    public static func == (lhs: Note, rhs: Note) -> Bool {
        lhs.id == rhs.id
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

import CoreTransferable

extension Note: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.stableDragId)
    }
}
