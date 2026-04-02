import Foundation
import SwiftData

public actor SyncCoordinator {
    private let gDocs = GDocsService()
    private let gDrive = GDriveService()
    
    public init() {}
    
    @MainActor
    public func sync(noteId: PersistentIdentifier, in context: ModelContext) async throws {
        guard let note = context.model(for: noteId) as? Note, let docId = note.googleDocId else { return }
        
        let remoteRev = try await gDrive.getFileRevision(fileId: docId)
        if remoteRev != note.lastSyncedRevision {
            // Pull and merge
            let remoteContent = try await gDocs.fetchDocContent(docId: docId)
            let mergedContent = merge(local: note.content, remote: remoteContent)
            note.content = mergedContent
            note.lastSyncedRevision = remoteRev
        } else {
            // Push local changes (simplified: only push if we have a revision)
            try await gDocs.updateDocContent(docId: docId, content: note.content)
            // Ideally the update call would return the new revision, for now we mock it
            // note.lastSyncedRevision = remoteRev // Actually, we'd need to fetch the new one
        }
        
        try context.save()
    }
    
    public nonisolated func merge(local: String, remote: String) -> String {
        // Simple resolution: if they differ, we'll just append for now as a "safe-merge"
        if local == remote { return local }
        return local + "\n\n--- Remote Changes ---\n\n" + remote
    }
}
