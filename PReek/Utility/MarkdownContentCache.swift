import Foundation
import MarkdownUI

/// Parses `MarkdownContent` lazily and caches the result so markdown is only parsed when a comment
/// is actually displayed, and re-renders (or refetches of unchanged comments) reuse the parsed
/// value instead of reparsing.
enum MarkdownContentCache {
    private final class Box {
        let content: MarkdownContent
        init(_ content: MarkdownContent) { self.content = content }
    }

    private static let cache: NSCache<NSString, Box> = {
        let cache = NSCache<NSString, Box>()
        cache.countLimit = 500
        return cache
    }()

    static func content(rawMarkdown: String) -> MarkdownContent {
        let key = rawMarkdown as NSString
        if let cached = cache.object(forKey: key) {
            return cached.content
        }
        let parsed = MarkdownContent(rawMarkdown)
        cache.setObject(Box(parsed), forKey: key)
        return parsed
    }
}
