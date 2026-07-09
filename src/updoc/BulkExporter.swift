import Foundation
import SwiftData

@ModelActor
public actor BulkExporter {
    public func exportNotes(to rootURL: URL) async throws -> Int {
        let fileManager = FileManager.default
        var existingPaths: Set<String> = []
        var exportedCount = 0
        
        // 1. Create directories for all existing folders to preserve hierarchy even if empty
        let folderDescriptor = FetchDescriptor<Folder>()
        let folders = try modelContext.fetch(folderDescriptor)
        for folder in folders {
            let pathComponents = getRelativePath(for: folder)
            var targetDir = rootURL
            for component in pathComponents {
                targetDir = targetDir.appendingPathComponent(component, isDirectory: true)
            }
            try fileManager.createDirectory(at: targetDir, withIntermediateDirectories: true, attributes: nil)
        }
        
        // 2. Export all notes
        let noteDescriptor = FetchDescriptor<Note>(sortBy: [SortDescriptor(\.createdAt), SortDescriptor(\.title)])
        let notes = try modelContext.fetch(noteDescriptor)
        for note in notes {
            var targetDir = rootURL
            if let meetingID = note.meetingID, !meetingID.isEmpty {
                let calendar = Calendar.current
                let year = String(format: "%04d", calendar.component(.year, from: note.createdAt))
                let month = String(format: "%02d", calendar.component(.month, from: note.createdAt))
                let day = String(format: "%02d", calendar.component(.day, from: note.createdAt))
                targetDir = rootURL
                    .appendingPathComponent(year, isDirectory: true)
                    .appendingPathComponent(month, isDirectory: true)
                    .appendingPathComponent(day, isDirectory: true)
            } else if let folder = note.folder {
                let pathComponents = getRelativePath(for: folder)
                for component in pathComponents {
                    targetDir = targetDir.appendingPathComponent(component, isDirectory: true)
                }
            }
            try fileManager.createDirectory(at: targetDir, withIntermediateDirectories: true, attributes: nil)
            
            let baseName = sanitizeFilename(note.title).trimmingCharacters(in: .whitespacesAndNewlines)
            let finalBaseName = baseName.isEmpty ? "Untitled Note" : baseName
            
            var counter = 2
            var fileURL = targetDir.appendingPathComponent("\(finalBaseName).md")
            while existingPaths.contains(fileURL.path) || fileManager.fileExists(atPath: fileURL.path) {
                fileURL = targetDir.appendingPathComponent("\(finalBaseName) \(counter).md")
                counter += 1
            }
            existingPaths.insert(fileURL.path)
            
            let content = buildNoteContent(for: note)
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            exportedCount += 1
        }
        
        return exportedCount
    }
    
    private func getRelativePath(for folder: Folder) -> [String] {
        var components: [String] = []
        var current: Folder? = folder
        while let f = current {
            let cleanName = sanitizeFilename(f.name).trimmingCharacters(in: .whitespacesAndNewlines)
            components.insert(cleanName.isEmpty ? "Unnamed Folder" : cleanName, at: 0)
            current = f.parent
        }
        return components
    }
    
    private func sanitizeFilename(_ name: String) -> String {
        let unsafeChars = CharacterSet(charactersIn: ":/\\*?\"<>|")
        return name.components(separatedBy: unsafeChars).joined()
    }
    
    private func buildNoteContent(for note: Note) -> String {
        var existingFrontmatter: [String: String] = [:]
        var body = note.content
        
        if let match = extractExistingFrontmatter(from: body) {
            existingFrontmatter = match.frontmatter
            body = match.body
        }
        
        if let meetingID = note.meetingID, !meetingID.isEmpty {
            existingFrontmatter["meetingId"] = meetingID
        }
        
        if existingFrontmatter["date"] == nil {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            existingFrontmatter["date"] = formatter.string(from: note.createdAt)
        }
        
        if let themeName = note.themeName, !themeName.isEmpty {
            existingFrontmatter["cssclasses"] = themeName
        }
        
        if let docId = note.googleDocId, !docId.isEmpty {
            existingFrontmatter["googleDocId"] = docId
        }
        
        if !note.categories.isEmpty {
            let formattedTags = "[" + note.categories.map { "\"\($0)\"" }.joined(separator: ", ") + "]"
            existingFrontmatter["tags"] = formattedTags
        }
        
        if note.isWeeklyLog {
            existingFrontmatter["isWeeklyLog"] = "true"
        }
        
        if let weeklyLogId = note.weeklyLogId, !weeklyLogId.isEmpty {
            existingFrontmatter["weeklyLogId"] = weeklyLogId
        }
        
        let orderedKeys = ["meetingId", "date", "attendees", "cssclasses", "googleDocId", "tags", "isWeeklyLog", "weeklyLogId"]
        var lines: [String] = ["---"]
        var addedKeys: Set<String> = []
        
        for key in orderedKeys {
            if let value = existingFrontmatter[key] {
                lines.append("\(key): \(value)")
                addedKeys.insert(key)
            }
        }
        
        for key in existingFrontmatter.keys.sorted() where !addedKeys.contains(key) {
            if let value = existingFrontmatter[key] {
                lines.append("\(key): \(value)")
            }
        }
        
        lines.append("---")
        lines.append("")
        
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanBody.isEmpty {
            return lines.joined(separator: "\n")
        } else {
            return lines.joined(separator: "\n") + cleanBody + "\n"
        }
    }
    
    private func extractExistingFrontmatter(from content: String) -> (frontmatter: [String: String], body: String)? {
        let nsString = content as NSString
        let pattern = "^---\\r?\\n([\\s\\S]*?)\\r?\\n---(?:\\r?\\n([\\s\\S]*))?$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        
        guard let match = regex.firstMatch(in: content, options: [], range: NSRange(location: 0, length: nsString.length)), match.numberOfRanges >= 2 else {
            return nil
        }
        
        let fmBlock = nsString.substring(with: match.range(at: 1))
        let body: String
        if match.numberOfRanges >= 3, match.range(at: 2).location != NSNotFound {
            body = nsString.substring(with: match.range(at: 2))
        } else {
            body = ""
        }
        
        var frontmatter: [String: String] = [:]
        let fmLines = fmBlock.components(separatedBy: .newlines)
        for line in fmLines {
            let parts = line.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 {
                frontmatter[parts[0]] = parts[1]
            }
        }
        
        return (frontmatter, body)
    }
}
