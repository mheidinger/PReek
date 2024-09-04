import Foundation

enum AppError: LocalizedError {
    case parseGheUrlFailure
    case noTokenAvailable
    case networkError
    case unauthorized
    case forbidden
    case apiError
    case insufficientScopes(missingScope: Scope?)
    case unknown

    var errorDescription: String? {
        switch self {
        case .parseGheUrlFailure:
            return String(localized: "Could not parse GitHub Enterprise URL")
        case .noTokenAvailable:
            return String(localized: "No token provided")
        case .networkError:
            return String(localized: "Failed to send request to GitHub")
        case .unauthorized:
            return String(localized: "PAT is invalid")
        case .forbidden:
            return String(localized: "PAT is missing permissions, does it have the 'notifications' scope?")
        case .apiError:
            return String(localized: "Unknown error happened when calling the GitHub API")
        case let .insufficientScopes(missingScope):
            if let scope = missingScope {
                return String(localized: "PAT is missing required scope: \(scope.rawValue)")
            } else {
                return String(localized: "PAT is missing required scopes")
            }
        case .unknown:
            return String(localized: "Unknown error happened")
        }
    }
}
