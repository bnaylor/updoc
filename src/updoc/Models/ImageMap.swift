import Foundation
import SwiftData

@Model
public class ImageMap {
    @Attribute(.unique) public var assetId: String
    public var driveFileId: String
    public var driveUrl: String
    public var lastSyncedAt: Date

    public init(assetId: String, driveFileId: String, driveUrl: String, lastSyncedAt: Date = Date()) {
        self.assetId = assetId
        self.driveFileId = driveFileId
        self.driveUrl = driveUrl
        self.lastSyncedAt = lastSyncedAt
    }
}
