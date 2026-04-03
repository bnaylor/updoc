import Foundation
import SwiftData

@MainActor
public class SyncCoordinator {
    private let gDocs = GDocsService()
    private let gDrive = GDriveService()
    
    public init() {}
    
    public func sync(noteId: PersistentIdentifier, in context: ModelContext) async throws {
        // First check authentication
        guard AuthManager.shared.isAuthenticated() else {
            throw NSError(domain: "SyncCoordinator", code: 401, userInfo: [NSLocalizedDescriptionKey: "User is not authenticated with Google"])
        }
        
        guard let note = context.model(for: noteId) as? Note, let docId = note.googleDocId else { return }
        
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
                try await gDocs.updateDocContent(docId: docId, content: localContent)
            }
        } catch {
            print("Sync error for note \(docId): \(error)")
            throw error
        }
    }
    
    public func merge(local: String, remote: String) -> String {
        if local == remote { return local }
        return local + "\n\n--- Remote Changes ---\n\n" + remote
    }
}
