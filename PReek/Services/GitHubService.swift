import Foundation
import LinkHeaderParser
import OSLog

private struct GraphQLQuery: Codable {
    var query: String
    var operationName: String?
    var variables: [String: String]?
}

class GitHubService {
    private static let logger = Logger()

    private static let PUBLIC_GITHUB_BASE_URL = URL(string: "https://api.github.com")!

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

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
        default:
            // If there are errors, then they should already be logged
            if errors?.first == nil {
                logger.error("Unknown error happened when calling the GitHub API")
            }
            return AppError.apiError
        }
    }

    private static func logGraphQlErrors(errors: [GitHubGraphQLError]?) {
        errors?.forEach { error in
            logger.error("Received error from GitHub API: \(error)")
        }
    }

    static func fetchViewer() async throws -> Viewer {
        let query = GraphQLQuery(query: ViewerQuery)
        var request = try URLRequest(url: graphUrl())
        request.httpMethod = "POST"
        request.httpBody = try encoder.encode(query)

        let (data, response) = try await sendRequest(request: request)
        let parsedData = try decoder.decode(ViewerResponse.self, from: data)

        logGraphQlErrors(errors: parsedData.errors)
        guard let data = parsedData.data else {
            throw graphQlErrorToError(errors: parsedData.errors)
        }
        let scopesHeader = response.value(forHTTPHeaderField: "x-oauth-scopes")

        return toViewer(data.viewer, scopesHeader: scopesHeader)
    }

    // returns IDs of all fetched PRs to update all that did not have new notifications
    static func fetchUserNotifications(since: Date, onNotificationsReceived: ([Notification]) async throws -> [String]) async throws -> [String] {
        logger.info("Fetching notifications since \(since.formatted())")
        var url: URL? = try restApiUrl().appending(path: "notifications")
            .appending(queryItems: [
                URLQueryItem(name: "all", value: "true"),
                URLQueryItem(name: "since", value: since.formatted(.iso8601)),
            ])

        var updatedPullRequestIds: [String] = []
        repeat {
            var request = URLRequest(url: url!)
            request.httpMethod = "GET"

            let (data, response) = try await sendRequest(request: request)

            let parsedData = try decoder.decode([NotificationDto].self, from: data)
            let batchUpdatedPullRequestIds = try await onNotificationsReceived(toNotifications(dtos: parsedData)) // TODO: Let this run async?
            updatedPullRequestIds.append(contentsOf: batchUpdatedPullRequestIds)

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
        let parsedData = try decoder.decode(PullRequestsResponse.self, from: data)

        logGraphQlErrors(errors: parsedData.errors)
        guard let data = parsedData.data else {
            throw graphQlErrorToError(errors: parsedData.errors)
        }

        let dtos = data.flatMap { $0.value.compactMap { $0.value } }
        return toPullRequests(dtos: dtos, viewer: viewer)
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
            logger.error("Failed to send request to GitHub, remapping to network error: \(error)")
            throw AppError.networkError
        }
    }
}
