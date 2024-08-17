import Foundation

struct Commit: Identifiable {
    // Hash of the commit
    let id: String
    let messageHeadline: String
    let url: URL?
}
