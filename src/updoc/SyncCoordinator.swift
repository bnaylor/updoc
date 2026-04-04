import Foundation
import SwiftData

@MainActor
public class SyncCoordinator {
    public let gDocs = GDocsService()
    public let gDrive = GDriveService()
    
    public init() {}
    
    public func sync(noteId: PersistentIdentifier, in context: ModelContext) async throws {
        // First check authentication
        guard AuthManager.shared.isAuthenticated() else {
            throw NSError(domain: "SyncCoordinator", code: 401, userInfo: [NSLocalizedDescriptionKey: "User is not authenticated with Google"])
        }
        
        guard let note = context.model(for: noteId) as? Note, let docId = note.googleDocId else { return }
        
        // Sync images to Drive first
        try await syncImages(note: note, in: context)
        
        let localContent = note.content
        let lastRevision = note.lastSyncedRevision
        
        do {
            let remoteRev = try await gDrive.getFileRevision(fileId: docId)
            
            if remoteRev != lastRevision {
                // Pull and merge
                let remoteContent = try await gDocs.fetchDocContent(docId: docId)
                let mergedContent = merge(local: localContent, remote: remoteContent)
                
                note.content = mergedContent
                note.lastSyncedRevision = remoteRev
                try context.save()
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
    
    public func merge(local: String, remote: String) -> String {
        if local == remote { return local }
        return local + "\n\n--- Remote Changes ---\n\n" + remote
    }
}
