import SwiftUI
import SwiftData

@Observable
@MainActor
public class DeletionManager {
    public var showDeleteConfirmation = false
    public var pendingNote: Note?
    public var isOwnedByMe = false
    public var isDeleting = false
    
    private let gDrive = GDriveService()
    
    public init() {}
    
    public func prepareDeletion(for note: Note) {
        self.pendingNote = note
        self.isDeleting = true
        
        Task {
            if let docId = note.googleDocId {
                do {
                    let metadata = try await gDrive.getFileMetadata(fileId: docId)
                    self.isOwnedByMe = metadata.ownedByMe
                    self.isDeleting = false
                    self.showDeleteConfirmation = true
                } catch {
                    self.isOwnedByMe = false
                    self.isDeleting = false
                    self.showDeleteConfirmation = true
                }
            } else {
                self.isOwnedByMe = false
                self.isDeleting = false
                self.showDeleteConfirmation = true
            }
        }
    }
    
    public func confirmDeletion(alsoTrashRemote: Bool, modelContext: ModelContext) async {
        guard let note = pendingNote else { return }
        
        isDeleting = true
        if alsoTrashRemote, let docId = note.googleDocId {
            try? await gDrive.trashFile(fileId: docId)
        }
        
        modelContext.delete(note)
        try? modelContext.save()
        
        self.pendingNote = nil
        self.showDeleteConfirmation = false
        self.isDeleting = false
    }
}
