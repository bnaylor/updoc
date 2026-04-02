import Foundation

public actor ImageLibraryManager {
    public static let shared = ImageLibraryManager()
    private let assetsDir: URL
    
    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        assetsDir = appSupport.appendingPathComponent("updoc/assets", isDirectory: true)
        try? FileManager.default.createDirectory(at: assetsDir, withIntermediateDirectories: true)
    }
    
    public func saveImage(_ data: Data, filename: String) async throws -> String {
        let id = UUID().uuidString
        let fileExtension = (filename as NSString).pathExtension
        let safeFilename = fileExtension.isEmpty ? id : "\(id).\(fileExtension)"
        let fileURL = assetsDir.appendingPathComponent(safeFilename)
        try data.write(to: fileURL)
        return id
    }
    
    public func getAssetURL(for id: String) -> URL? {
        // In a real implementation, we might need to store the mapping of ID to filename
        // if we allow different extensions. For now, let's assume we can find it by prefix.
        guard let files = try? FileManager.default.contentsOfDirectory(at: assetsDir, includingPropertiesForKeys: nil) else {
            return nil
        }
        return files.first { $0.lastPathComponent.hasPrefix(id) }
    }
}
