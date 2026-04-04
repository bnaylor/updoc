import Foundation
import SwiftData

public actor ImageLibraryManager {
    public static let shared = ImageLibraryManager()
    private let assetsDir: URL
    
    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        assetsDir = appSupport.appendingPathComponent("updoc/assets", isDirectory: true)
        try? FileManager.default.createDirectory(at: assetsDir, withIntermediateDirectories: true)
    }
    
    public func saveImage(_ data: Data, filename: String) async throws -> String {
        guard !data.isEmpty else {
            throw NSError(domain: "ImageLibraryManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Empty image data"])
        }
        
        let id = UUID().uuidString
        let fileExtension = (filename as NSString).pathExtension
        let safeFilename = fileExtension.isEmpty ? id : "\(id).\(fileExtension)"
        let fileURL = assetsDir.appendingPathComponent(safeFilename)
        
        do {
            try data.write(to: fileURL)
        } catch {
            throw NSError(domain: "ImageLibraryManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to save image: \(error.localizedDescription)"])
        }
        
        return safeFilename
    }
    
    public func getAssetURL(for id: String) -> URL? {
        // Construct URL directly since ID is now the safeFilename
        let fileURL = assetsDir.appendingPathComponent(id)
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }

    public nonisolated func getDriveId(for assetId: String, in context: ModelContext) -> String? {
        let descriptor = FetchDescriptor<ImageMap>(
            predicate: #Predicate<ImageMap> { $0.assetId == assetId }
        )
        return (try? context.fetch(descriptor))?.first?.driveFileId
    }

    public nonisolated func getDriveUrl(for assetId: String, in context: ModelContext) -> String? {
        let descriptor = FetchDescriptor<ImageMap>(
            predicate: #Predicate<ImageMap> { $0.assetId == assetId }
        )
        return (try? context.fetch(descriptor))?.first?.driveUrl
    }

    public nonisolated func saveMapping(assetId: String, driveFileId: String, driveUrl: String, in context: ModelContext) {
        let descriptor = FetchDescriptor<ImageMap>(
            predicate: #Predicate<ImageMap> { $0.assetId == assetId }
        )
        
        if let existing = (try? context.fetch(descriptor))?.first {
            existing.driveFileId = driveFileId
            existing.driveUrl = driveUrl
            existing.lastSyncedAt = Date()
        } else {
            let newMap = ImageMap(assetId: assetId, driveFileId: driveFileId, driveUrl: driveUrl)
            context.insert(newMap)
        }
        
        try? context.save()
    }
}
