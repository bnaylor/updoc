import Foundation
import SwiftData

public enum SyncError: Error, LocalizedError, Equatable {
    case conflict(local: String, remote: String, remoteRevision: String)
    case notAuthenticated
    
    public var errorDescription: String? {
        switch self {
        case .conflict: return "Conflict detected"
        case .notAuthenticated: return "Authentication required"
        }
    }
}

@MainActor
public class SyncCoordinator {
    public let gDocs = GDocsService()
    public let gDrive = GDriveService()
    
    public init() {}
    
    public func sync(noteId: PersistentIdentifier, in context: ModelContext) async throws {
        // First check authentication robustly
        _ = try await AuthManager.shared.getAccessToken()
        
        guard let note = context.model(for: noteId) as? Note, let docId = note.googleDocId else { return }
        
        // Capture local state BEFORE any network calls (like syncImages)
        // to ensure we are syncing exactly what we expect even if it changes during the process.
        let localContent = note.content
        let lastRevision = note.lastSyncedRevision
        
        // Sync images to Drive first
        try await syncImages(note: note, in: context)
        
        do {
            let remoteRev = try await gDrive.getFileRevision(fileId: docId)
            
            if remoteRev != lastRevision {
                // Pull and merge
                let remoteContent = try await gDocs.fetchDocContent(docId: docId)
                
                // ONLY throw if content is actually different
                if localContent != remoteContent {
                    throw SyncError.conflict(local: localContent, remote: remoteContent, remoteRevision: remoteRev)
                } else {
                    // Content is identical, just update revision
                    note.lastSyncedRevision = remoteRev
                    try context.save()
                }
            } else {
                // Push local changes
                let assetIds = extractAssetIds(from: localContent)
                var mappings: [String: String] = [:]
                for id in assetIds {
                    if let driveUrl = ImageLibraryManager.shared.getDriveUrl(for: id, in: context) {
                        mappings[id] = driveUrl
                    }
                }
                try await gDocs.updateDocContent(docId: docId, content: localContent, assetMappings: mappings)
            }
        } catch {
            if error is SyncError {
                throw error
            }
            print("Sync error for note \(docId): \(error)")
            throw error
        }
    }
    
    private func syncImages(note: Note, in context: ModelContext) async throws {
        let assetIds = extractAssetIds(from: note.content)
        guard !assetIds.isEmpty else { return }
        
        let folderId = try await gDrive.getOrCreateFolder(named: "updoc_assets")
        
        for assetId in assetIds {
            // Check if mapping exists
            if ImageLibraryManager.shared.getDriveId(for: assetId, in: context) == nil {
                // Not uploaded yet, so upload it
                if let localURL = await ImageLibraryManager.shared.getAssetURL(for: assetId),
                   let data = try? Data(contentsOf: localURL) {
                    
                    let driveFileId = try await gDrive.uploadFile(data: data, filename: assetId, parentId: folderId)
                    // Construct a direct viewing URL (placeholder format)
                    let driveUrl = "https://lh3.googleusercontent.com/u/0/d/\(driveFileId)"
                    
                    ImageLibraryManager.shared.saveMapping(assetId: assetId, driveFileId: driveFileId, driveUrl: driveUrl, in: context)
                }
            }
        }
    }
    
    private func extractAssetIds(from content: String) -> [String] {
        let pattern = #"!\[\[(.*?)\]\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        let matches = regex.matches(in: content, options: [], range: range)
        
        return matches.compactMap { match in
            guard match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: content) else { return nil }
            return String(content[range])
        }
    }
}
