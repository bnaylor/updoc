import Foundation

public struct GDriveService: Sendable {
    public init() {}
    
    public func getFileRevision(fileId: String) async throws -> String {
        // TODO: Call Drive API to get head revision (for now return mock)
        return "rev-1"
    }
}
