import Foundation
import SwiftData

struct ImportItem: Codable {
    let title: String
    let url: String
    let createdAt: String
    let folderPath: String
    let meetingID: String?
}

@ModelActor
public actor BulkImporter {
    public func importNotes(from url: URL) async throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        
        let items = try decoder.decode([ImportItem].self, from: data)
        
        for item in items {
            // Parse URL
            guard let docId = extractDocId(from: item.url) else { continue }
            
            // Handle folders
            let folder = try getOrCreateFolder(for: item.folderPath)
            
            // Create Note
            let formatter = ISO8601DateFormatter()
            let date = formatter.date(from: item.createdAt) ?? Date()
            
            let newNote = Note(
                title: item.title,
                content: "", // Content will be fetched on sync
                createdAt: date,
                googleDocId: docId,
                meetingID: item.meetingID,
                folder: folder,
                isReadOnly: true // Default to read-only
            )
            
            modelContext.insert(newNote)
        }
        
        try modelContext.save()
    }
    
    private func extractDocId(from urlString: String) -> String? {
        let pattern = "document/d/([^/]+)"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let nsString = urlString as NSString
        let results = regex?.matches(in: urlString, options: [], range: NSRange(location: 0, length: nsString.length))
        
        if let match = results?.first, match.numberOfRanges > 1 {
            return nsString.substring(with: match.range(at: 1))
        }
        return nil
    }
    
    private func getOrCreateFolder(for path: String) throws -> Folder? {
        if path.isEmpty { return nil }
        
        let components = path.components(separatedBy: "/")
        var currentFolder: Folder? = nil
        
        for component in components {
            let name = component.trimmingCharacters(in: .whitespacesAndNewlines)
            if name.isEmpty { continue }
            
            // Search for existing folder
            let descriptor = FetchDescriptor<Folder>()
            let allFolders = try modelContext.fetch(descriptor)
            
            let existing = allFolders.first { folder in
                folder.name == name && folder.parent == currentFolder
            }
            
            if let folder = existing {
                currentFolder = folder
            } else {
                let newFolder = Folder(name: name, parent: currentFolder)
                modelContext.insert(newFolder)
                currentFolder = newFolder
            }
        }
        
        return currentFolder
    }
}
