import Foundation

struct Commit: Identifiable, Equatable {
    // Hash of the commit
    let id: String
    let messageHeadline: String
    let url: URL?
    let parentId: Commit.ID?
}
