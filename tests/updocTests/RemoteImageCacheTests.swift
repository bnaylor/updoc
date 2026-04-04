import Testing
import Foundation
import AppKit
@testable import updoc

@MainActor
struct RemoteImageCacheTests {
    @Test func clearRemovesCachedImage() async throws {
        let cache = RemoteImageCache.shared
        let url = URL(string: "https://example.com/test.png")!
        
        // We can't easily inject a mock image into NSCache without modifying RemoteImageCache
        // or using a URL that actually loads something.
        // For now, let's see if we can at least call the method.
        
        cache.clear(for: url)
        
        // This should fail to compile initially as clear(for:) doesn't exist.
    }
}
