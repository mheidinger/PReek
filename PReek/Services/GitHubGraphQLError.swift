import Foundation

struct GitHubGraphQLError: Decodable {
    enum ErrorType: String, CaseIterableDefaultsLast {
        case INSUFFICIENT_SCOPES
        case Unknown
    }

    let type: ErrorType
}
