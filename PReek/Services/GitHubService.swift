import Foundation
import LinkHeaderParser
import OSLog

private struct GraphQLQuery: Codable {
    var query: String
    var operationName: String?
    var variables: [String: String]?
}

private struct GitHubErrorResponse: Decodable {
    let message: String?
}

class GitHubService {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "de.max-heidinger.PReek",
        category: "GitHubService"
    )

    private static let PUBLIC_GITHUB_BASE_URL = URL(string: "https://api.github.com")!

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static func restApiUrl() throws -> URL {
        if let gitHubEnterpriseUrl = ConfigService.gitHubEnterpriseUrl {
            guard let baseUrl = URL(string: gitHubEnterpriseUrl) else {
                throw AppError.parseGheUrlFailure
            }
            return baseUrl.appending(path: "api").appending(path: "v3")
        }

        return PUBLIC_GITHUB_BASE_URL
    }

    private static func graphUrl() throws -> URL {
        if let gitHubEnterpriseUrl = ConfigService.gitHubEnterpriseUrl {
            guard let baseUrl = URL(string: gitHubEnterpriseUrl) else {
                throw AppError.parseGheUrlFailure
            }
            return baseUrl.appending(path: "api").appending(path: "graphql")
        }

        return PUBLIC_GITHUB_BASE_URL.appending(path: "graphql")
    }

    private static func graphQlErrorToError(errors: [GitHubGraphQLError]?) -> AppError {
        switch errors?.first?.type {
        case "INSUFFICIENT_SCOPES":
            return AppError.insufficientScopes(missingScope: nil)
        case "RATE_LIMITED":
            return AppError.rateLimited
        default:
            // If there are errors, then they should already be logged
            if errors?.first == nil {
                logger.error("Unknown error happened when calling the GitHub API")
            }
            return AppError.apiError
        }
    }

    private static func logGraphQlErrors(errors: [GitHubGraphQLError]?, operation: String) {
        errors?.forEach { error in
            logger.error(
                """
                GitHub GraphQL error \
                operation=\(operation, privacy: .public) \
                type=\(error.type ?? "unknown", privacy: .public) \
                path=\(error.path?.joined(separator: ".") ?? "unknown", privacy: .public) \
                message=\(error.message ?? "No message provided", privacy: .public)
                """
            )
        }
    }

    static func fetchViewer() async throws -> Viewer {
        let query = GraphQLQuery(query: ViewerQuery)
        var request = try URLRequest(url: graphUrl())
        request.httpMethod = "POST"
        request.httpBody = try encoder.encode(query)

        let (data, response) = try await sendRequest(request: request)
        let parsedData = try decodeResponse(ViewerResponse.self, from: data, operation: "viewer")

        logGraphQlErrors(errors: parsedData.errors, operation: "viewer")
        guard let data = parsedData.data else {
            throw graphQlErrorToError(errors: parsedData.errors)
        }
        let scopesHeader = response.value(forHTTPHeaderField: "x-oauth-scopes")

        return toViewer(data.viewer, scopesHeader: scopesHeader)
    }

    /// returns IDs of all fetched PRs to update all that did not have new notifications
    static func fetchUserNotifications(since: Date, onNotificationsReceived: ([Notification]) async throws -> Set<String>) async throws -> Set<String> {
        logger.info("Fetching notifications since \(since.formatted())")
        var url: URL? = try restApiUrl().appending(path: "notifications")
            .appending(queryItems: [
                URLQueryItem(name: "all", value: "true"),
                URLQueryItem(name: "since", value: since.formatted(.iso8601)),
            ])

        var updatedPullRequestIds = Set<String>()
        repeat {
            var request = URLRequest(url: url!)
            request.httpMethod = "GET"

            let (data, response) = try await sendRequest(request: request)

            let parsedData = try decodeResponse(
                [NotificationDto].self,
                from: data,
                operation: "notifications"
            )
            let batchUpdatedPullRequestIds = try await onNotificationsReceived(toNotifications(dtos: parsedData)) // TODO: Let this run async?
            updatedPullRequestIds.formUnion(batchUpdatedPullRequestIds)

            guard let linkHeader = response.value(forHTTPHeaderField: "Link") else {
                break
            }
            let nextLink = LinkHeaderParser.parseLinkHeader(linkHeader, defaultContext: nil, contentLanguageHeader: nil)?.first { link in
                link.rel.first { rel in rel == "next" } != nil
            }

            if let nextLink = nextLink {
                url = nextLink.link
                logger.debug("Next page available")
            } else {
                url = nil
            }
        } while url != nil

        return updatedPullRequestIds
    }

    static func fetchPullRequests(repoMap: [String: [Int]], viewer: Viewer) async throws -> [PullRequest] {
        let fetchRequestedTeamReview = viewer.scopes?.contains(.readOrg) ?? false

        let query = GraphQLQuery(query: PullRequestsQueryBuilder.fetchPullRequestQuery(repoMap: repoMap, fetchRequestedTeamReview: fetchRequestedTeamReview))
        var request = try URLRequest(url: graphUrl())
        request.httpMethod = "POST"
        request.httpBody = try encoder.encode(query)

        let (data, _) = try await sendRequest(request: request)
        let operation = "pull-requests repos=\(repoMap.count) pullRequests=\(repoMap.values.flatMap { $0 }.count)"
        let parsedData = try decodeResponse(PullRequestsResponse.self, from: data, operation: operation)

        logGraphQlErrors(errors: parsedData.errors, operation: operation)
        guard let data = parsedData.data else {
            throw graphQlErrorToError(errors: parsedData.errors)
        }

        let dtos = data
            .values // Dictionary<String, PullRequestsResponse.PullRequestDtoMap?>.Values
            .compactMap { $0 } // [PullRequestsResponse.PullRequestDtoMap]
            .flatMap { $0 } // [Dictionary<String, PullRequestDto?>.Element]
            .compactMap { $0.value } // [PullRequestDto]
        return toPullRequests(dtos: dtos)
    }

    private static func decodeResponse<T: Decodable>(
        _ type: T.Type,
        from data: Data,
        operation: String
    ) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            logger.error(
                """
                Failed to decode GitHub response \
                operation=\(operation, privacy: .public) \
                responseBytes=\(data.count, privacy: .public) \
                error=\(String(describing: error), privacy: .public)
                """
            )
            throw error
        }
    }

    private static func sendRequest(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard let jwt = ConfigService.token else {
            throw AppError.noTokenAvailable
        }

        var intRequest = request
        intRequest.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        intRequest.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await URLSession.shared.data(for: intRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppError.unknown
            }

            logHttpErrorIfNeeded(response: httpResponse, data: data, request: request)

            if httpResponse.statusCode == 401 {
                throw AppError.unauthorized
            }
            if httpResponse.statusCode == 403 {
                throw AppError.forbidden
            }

            return (data, httpResponse)
        } catch let error as AppError {
            throw error
        } catch {
            let urlError = error as? URLError
            logger.error(
                """
                GitHub request failed \
                operation=\(requestOperation(request), privacy: .public) \
                urlErrorCode=\(urlError?.code.rawValue ?? 0, privacy: .public) \
                error=\(String(describing: error), privacy: .public)
                """
            )
            throw AppError.networkError
        }
    }

    private static func requestOperation(_ request: URLRequest) -> String {
        "\(request.httpMethod ?? "GET") \(request.url?.path ?? "unknown")"
    }

    private static func logHttpErrorIfNeeded(
        response: HTTPURLResponse,
        data: Data,
        request: URLRequest
    ) {
        guard !(200 ... 299).contains(response.statusCode) else {
            return
        }

        let apiError = try? JSONDecoder().decode(GitHubErrorResponse.self, from: data)
        let rateLimitRemaining = response.value(forHTTPHeaderField: "x-ratelimit-remaining") ?? "unknown"
        let rateLimitReset = response.value(forHTTPHeaderField: "x-ratelimit-reset") ?? "unknown"
        let retryAfter = response.value(forHTTPHeaderField: "retry-after") ?? "unknown"
        logger.error(
            """
            GitHub HTTP error \
            operation=\(requestOperation(request), privacy: .public) \
            status=\(response.statusCode, privacy: .public) \
            rateLimitRemaining=\(rateLimitRemaining, privacy: .public) \
            rateLimitReset=\(rateLimitReset, privacy: .public) \
            retryAfter=\(retryAfter, privacy: .public) \
            message=\(apiError?.message ?? "No message provided", privacy: .public)
            """
        )
    }
}
