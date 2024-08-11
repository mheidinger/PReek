import Foundation
import LinkHeaderParser

private struct GraphQLQuery: Codable {
    var query: String
    var operationName: String?
    var variables: [String: String]?
}

class GitHubService {
    static private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
    static private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
    
    static private func baseUrl() throws -> URL {
        guard let baseUrl: URL = URL(string: ConfigService.apiBaseUrl) else {
            throw "Could not construct valid base URL"
        }
        return baseUrl
    }
    
    static private func graphUrl() throws -> URL {
        if ConfigService.graphUrl != nil {
            guard let graphUrl: URL = URL(string: ConfigService.graphUrl!) else {
                throw "Could not construct valid GraphQL URL"
            }
            return graphUrl
        }
        
        return try baseUrl().appending(path: "graphql")
    }
    
    static func fetchUserNotifications(since: Date, onNotificationsReceived: ([Notification]) async throws -> Void) async throws {
        var url: URL? = try baseUrl().appending(path: "notifications")
            .appending(queryItems: [
                URLQueryItem(name: "all", value: "true"),
                URLQueryItem(name: "since", value: since.formatted(.iso8601))
            ])
        
        repeat {
            var request = URLRequest(url: url!)
            request.httpMethod = "GET"
            
            let (data, response) = try await sendRequest(request: request)
            
            let parsedData = try decoder.decode([NotificationDto].self, from: data)
            try await onNotificationsReceived(toNotifications(dtos: parsedData)) // TODO: Let this run async?
            
            guard let httpResponse = response as? HTTPURLResponse else {
                break
            }
            
            guard let linkHeader = httpResponse.allHeaderFields["Link"] as? String else {
                break
            }
            let nextLink = LinkHeaderParser.parseLinkHeader(linkHeader, defaultContext: nil, contentLanguageHeader: nil)?.first { link in
                link.rel.first { rel in rel == "next" } != nil
            }
            
            if nextLink != nil {
                url = nextLink?.link
            } else {
                url = nil
            }
        } while url != nil
    }
    
    static func fetchPullRequests(repoMap: [String: [Int]]) async throws -> [PullRequest] {
        let query = GraphQLQuery(query: FetchPullRequestsQueryBuilder.fetchPullRequestQuery(repoMap: repoMap))
        var request = URLRequest(url: try graphUrl())
        request.httpMethod = "POST"
        request.httpBody = try! encoder.encode(query)
        
        let (data, _) = try await sendRequest(request: request)
        let parsedData = try decoder.decode(FetchPullRequestsResponse.self, from: data)
        let dtos = parsedData.data.repoMap.flatMap { $0.value.compactMap { $0.value } }
        return toPullRequests(dtos: dtos, viewer: parsedData.data.viewer)
    }
    
    static private func sendRequest(request: URLRequest) async throws -> (Data, URLResponse) {
        guard let jwt = ConfigService.token else {
            throw "No token available"
        }
        
        var intRequest = request
        intRequest.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        intRequest.cachePolicy = .reloadIgnoringLocalCacheData
        
        return try await URLSession.shared.data(for: intRequest)
    }
}
