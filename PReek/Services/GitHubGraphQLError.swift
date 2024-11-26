import Foundation

struct GitHubGraphQLError: Decodable, CustomStringConvertible {
    let type: String?
    let path: [String]?
    let message: String?

    var description: String {
        """
        type: \(type ?? "nil")
        path: \(path?.joined(separator: ".") ?? "nil")
        message: \(message ?? "nil")
        """
    }
}
