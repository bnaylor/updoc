import Foundation

public struct GDocsService {
    public init() {}
    
    public func fetchDocContent(docId: String) async throws -> String {
        // TODO: Call Docs API to get content JSON and convert to Markdown (for now return mock)
        return "# Remote Content"
    }
    
    public func updateDocContent(docId: String, content: String) async throws {
        // TODO: Convert Markdown to Docs JSON and push batch update (for now return mock)
        print("Updating doc \(docId) with content length \(content.count)")
    }
}
