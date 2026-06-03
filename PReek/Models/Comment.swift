import Foundation

struct Comment: Identifiable, Equatable {
    let id: String
    /// Raw markdown body. Parsed into `MarkdownContent` lazily at display time.
    let content: String
    let fileReference: String?
    let isReply: Bool

    var displayPrefix: String? {
        if let setFileReference = fileReference {
            if isReply {
                return String(localized: "replied on \(setFileReference):")
            }
            return String(localized: "commented on \(setFileReference):")
        }
        if isReply {
            return String(localized: "replied:")
        }
        return nil
    }
}
