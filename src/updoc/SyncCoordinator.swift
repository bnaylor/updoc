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
        do {
            _ = try await AuthManager.shared.getAccessToken()
        } catch {
            throw SyncError.notAuthenticated
        }
        
        guard let note = context.model(for: noteId) as? Note, let docId = note.googleDocId else { return }
        
        // Capture local state BEFORE any network calls
        let localContent = note.content
        print("Syncing note \(docId): localContent length = \(localContent.count)")
        
        // Sync images to Drive first
        try await syncImages(note: note, in: context)
        
        do {
            // Fetch current document state
            let (remoteContent, baseDoc) = try await gDocs.fetchDocContent(docId: docId)
            let remoteRev = baseDoc.revisionId ?? ""
            print("Syncing note \(docId): remoteContent length = \(remoteContent.count), revision = \(remoteRev)")
            
            let isLocalUnchanged = (note.lastSyncedLocalContent == localContent)
            let isRemoteUnchanged = (note.lastSyncedRevision == remoteRev)
            
            if isLocalUnchanged && !isRemoteUnchanged {
                print("Syncing note \(docId): Remote content has changed and local is unmodified. Pulling updates.")
                
                await MainActor.run {
                    note.content = remoteContent
                    note.lastSyncedRevision = remoteRev
                    note.lastSyncedLocalContent = remoteContent
                }
                try context.save()
                
                // Notify the UI that an external sync just modified the note
                NotificationCenter.default.post(name: .noteDidSyncRemotely, object: note)
                
            } else if isLocalUnchanged {
                print("Syncing note \(docId): Local content unchanged since last sync, skipping push.")
                if note.lastSyncedRevision != remoteRev {
                    // Update revision tracking if we see a new revision (or ignore if it's an eventually consistent older one)
                    note.lastSyncedRevision = remoteRev
                    try context.save()
                }
            } else if localContent == remoteContent {
                print("Syncing note \(docId): Content identical to remote, skipping update.")
                if note.lastSyncedRevision != remoteRev {
                    note.lastSyncedRevision = remoteRev
                    note.lastSyncedLocalContent = localContent
                    try context.save()
                }
            } else {
                print("Syncing note \(docId): Content differs, updating doc...")
                // If content differs, attempt a seamless push.
                // GDocsService will handle the 3-way merge (rebase) internally
                // using WriteControl to ensure safety.
                let assetIds = extractAssetIds(from: localContent)
                var mappings: [String: String] = [:]
                for id in assetIds {
                    if let driveUrl = ImageLibraryManager.shared.getDriveUrl(for: id, in: context) {
                        mappings[id] = driveUrl
                    }
                }
                
                let (newRev, mergedContent) = try await gDocs.updateDocContent(docId: docId, content: localContent, baseDocument: baseDoc, assetMappings: mappings)
                print("Syncing note \(docId): Update successful. New revision = \(newRev)")
                note.lastSyncedRevision = newRev
                note.lastSyncedLocalContent = localContent
                if let merged = mergedContent {
                    print("Syncing note \(docId): Content was merged during update.")
                    note.content = merged
                    note.lastSyncedLocalContent = merged
                }
                try context.save()
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
            if ImageLibraryManager.shared.getDriveId(for: assetId, in: context) == nil {
                if let localURL = await ImageLibraryManager.shared.getAssetURL(for: assetId),
                   let data = try? Data(contentsOf: localURL) {
                    
                    let driveFileId = try await gDrive.uploadFile(data: data, filename: assetId, parentId: folderId)
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
