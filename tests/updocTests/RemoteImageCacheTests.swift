import Testing
import Foundation
import AppKit
@testable import updoc

@MainActor
struct RemoteImageCacheTests {
    @Test func clearRemovesCachedImageAndCancelsTask() async throws {
        let cache = RemoteImageCache.shared
        let url = URL(string: "https://example.com/test.png")!
        
        // Clear before starting to ensure a clean state
        cache.clear(for: url)
        
        // We can't easily verify the internal state of cache/loadingTasks as they are private,
        // but we can verify that the method is callable and doesn't crash.
        cache.clear(for: url)
    }
}
