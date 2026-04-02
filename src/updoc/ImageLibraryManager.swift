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
        guard !data.isEmpty else {
            throw NSError(domain: "ImageLibraryManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Empty image data"])
        }
        
        let id = UUID().uuidString
        let fileExtension = (filename as NSString).pathExtension
        let safeFilename = fileExtension.isEmpty ? id : "\(id).\(fileExtension)"
        let fileURL = assetsDir.appendingPathComponent(safeFilename)
        
        do {
            try data.write(to: fileURL)
        } catch {
            throw NSError(domain: "ImageLibraryManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to save image: \(error.localizedDescription)"])
        }
        
        return safeFilename
    }
    
    public func getAssetURL(for id: String) -> URL? {
        // Construct URL directly since ID is now the safeFilename
        let fileURL = assetsDir.appendingPathComponent(id)
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }
}
