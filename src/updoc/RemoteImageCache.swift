import Foundation
import AppKit

@MainActor
class RemoteImageCache {
    static let shared = RemoteImageCache()
    private var cache = NSCache<NSURL, NSImage>()
    private var loadingTasks = [URL: Task<NSImage?, Never>]()
    
    private init() {}
    
    func image(for url: URL) async -> NSImage? {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }
        
        if let existingTask = loadingTasks[url] {
            return await existingTask.value
        }
        
        let task = Task<NSImage?, Never> {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = NSImage(data: data) {
                    self.cache.setObject(image, forKey: url as NSURL)
                    return image
                }
            } catch {
                print("Error loading remote image: \(error)")
            }
            return nil
        }
        
        loadingTasks[url] = task
        let result = await task.value
        loadingTasks[url] = nil
        return result
    }

    func clear(for url: URL) {
        cache.removeObject(forKey: url as NSURL)
        loadingTasks[url] = nil
    }
}
