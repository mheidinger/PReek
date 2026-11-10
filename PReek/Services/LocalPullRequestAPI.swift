#if os(macOS)
    import Foundation

    /// Pull-request details shared by editor workspaces and agent context preparation.
    enum LocalPullRequestAPI {
        struct Details: Decodable {
            struct Ref: Decodable {
                struct Repository: Decodable {
                    let fullName: String

                    private enum CodingKeys: String, CodingKey {
                        case fullName = "full_name"
                    }
                }

                let sha: String
                let ref: String
                let repository: Repository?

                private enum CodingKeys: String, CodingKey {
                    case sha, ref
                    case repository = "repo"
                }
            }

            let title: String
            let body: String?
            let url: URL
            let head: Ref
            let base: Ref

            private enum CodingKeys: String, CodingKey {
                case title, body, head, base
                case url = "html_url"
            }
        }

        static func metadata(for url: URL) async throws -> LocalWorkspaceService.Metadata {
            let details = try await details(for: url)
            return LocalWorkspaceService.Metadata(
                headSHA: details.head.sha,
                baseSHA: details.base.sha,
                title: details.title,
                pushDestination: details.head.repository.map {
                    .init(repository: $0.fullName, branch: details.head.ref)
                }
            )
        }

        static func details(for url: URL) async throws -> Details {
            let identity = try LocalWorkspaceService.identity(for: url)
            let repository = "\(identity.owner)/\(identity.repository)"
            let (data, _) = try await GitHubService.localActionRequest(
                pullRequestURL: url,
                path: "repos/\(repository)/pulls/\(identity.number)"
            )
            let details = try JSONDecoder().decode(Details.self, from: data)
            guard details.url.host?.lowercased() == url.host?.lowercased(),
                  details.url.port == url.port,
                  normalizedPath(details.url) == normalizedPath(url),
                  details.base.repository?.fullName.lowercased() == repository
            else {
                throw LocalActionError(message: "GitHub returned a different repository or pull request. Check the repository mapping.")
            }
            return details
        }

        private static func normalizedPath(_ url: URL) -> String {
            url.path.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
    }
#endif
