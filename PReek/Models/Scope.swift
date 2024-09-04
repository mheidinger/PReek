import Foundation

enum Scope: String, CaseIterable {
    case notifications
    case repo
    case readOrg = "read:org"
}
