import Foundation
import LinkHeaderParser
import OSLog

private struct GraphQLQuery: Codable {
    var query: String
    var operationName: String?
    var variables: [String: String]?
}

enum GitHubError: LocalizedError {
    case parseGheUrlFailure
    case noTokenAvailable
    case networkError
    case unauthorized
    case forbidden
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
        case .unknown:
            return String(localized: "Unknown error happened")
        }
    }
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
                throw GitHubError.parseGheUrlFailure
            }
            return baseUrl.appending(path: "api").appending(path: "v3")
        }

        return PUBLIC_GITHUB_BASE_URL
    }

    private static func graphUrl() throws -> URL {
        if let gitHubEnterpriseUrl = ConfigService.gitHubEnterpriseUrl {
            guard let baseUrl = URL(string: gitHubEnterpriseUrl) else {
                throw GitHubError.parseGheUrlFailure
            }
            return baseUrl.appending(path: "api").appending(path: "graphql")
        }

        return PUBLIC_GITHUB_BASE_URL.appending(path: "graphql")
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

    static func fetchPullRequests(repoMap: [String: [Int]]) async throws -> [PullRequest] {
        let query = GraphQLQuery(query: FetchPullRequestsQueryBuilder.fetchPullRequestQuery(repoMap: repoMap))
        var request = try URLRequest(url: graphUrl())
        request.httpMethod = "POST"
        request.httpBody = try! encoder.encode(query)

        let (data, _) = try await sendRequest(request: request)
        let parsedData = try decoder.decode(FetchPullRequestsResponse.self, from: data)
        let dtos = parsedData.data.repoMap.flatMap { $0.value.compactMap { $0.value } }
        return toPullRequests(dtos: dtos, viewer: parsedData.data.viewer)
    }

    private static func sendRequest(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard let jwt = ConfigService.token else {
            throw GitHubError.noTokenAvailable
        }

        var intRequest = request
        intRequest.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        intRequest.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await URLSession.shared.data(for: intRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GitHubError.unknown
            }

            if httpResponse.statusCode == 401 {
                throw GitHubError.unauthorized
            }
            if httpResponse.statusCode == 403 {
                throw GitHubError.forbidden
            }

            return (data, httpResponse)
        } catch let error as GitHubError {
            throw error
        } catch {
            throw GitHubError.networkError
        }
    }
}
