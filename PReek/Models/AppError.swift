import Foundation

enum AppError: LocalizedError {
    case parseGheUrlFailure
    case noTokenAvailable
    case networkError
    case unauthorized
    case forbidden
    case apiError
    case insufficientScopes(missingScope: Scope?)
    case missingConfigToShare
    case qrCodeGenerationFailed
    case failedToImportShareData
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
        case .missingConfigToShare:
            return String(localized: "No configuration to share")
        case .qrCodeGenerationFailed:
            return String(localized: "Failed to generate QR code")
        case .failedToImportShareData:
            return String(localized: "Failed to import shared configuration")
        case .unknown:
            return String(localized: "Unknown error happened")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .failedToImportShareData:
            return "Please verify you are using the latest version of the app on both devices. If the issue persists, please report the issue."
        default:
            return nil
        }
    }
}
