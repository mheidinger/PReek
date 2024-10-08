import Foundation
import MarkdownUI

struct Comment: Identifiable, Equatable {
    let id: String
    let content: MarkdownContent
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
