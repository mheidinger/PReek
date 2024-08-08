//
//  FetchUserPullRequestsQuery.swift
//  GitHub Notifications
//
//  Created by Max Heidinger on 24.05.24.
//

import Foundation

private struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    init?(stringValue: String) {
        self.stringValue = stringValue
    }
    var intValue: Int?
    init?(intValue: Int) {
        return nil
    }
}

struct FetchPullRequestsResponse: Decodable {
    typealias PullRequestDtoMap = [String: PullRequestDto]
    typealias RepositoryDtoMap = [String: PullRequestDtoMap]
    
    struct Data: Decodable {
        let viewer: PullRequestDto.User
        let repoMap: RepositoryDtoMap
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
            
            viewer = try container.decode(PullRequestDto.User.self, forKey: DynamicCodingKeys(stringValue: "viewer")!)
            
            var repos = RepositoryDtoMap()
            for key in container.allKeys {
                if key.stringValue.starts(with: "repo") {
                    let repo = try container.decode(PullRequestDtoMap.self, forKey: key)
                    repos[key.stringValue] = repo
                }
            }
            repoMap = repos
        }
    }
    
    let data: Data
}

struct FetchPullRequestsQueryBuilder {
    static func fetchPullRequestQuery(repoMap: [String: [Int]]) -> String {
        var repoCount = 0
        let queryContent = repoMap.reduce("") { query, repo in
            let repoQuery = repo.value.reduce("") { repoQuery, prNumber in
                return repoQuery + """
                    pr\(prNumber): pullRequest(number: \(prNumber)) {
                      ...PullRequestFragment
                    }
                    
                    """
            }
            
            repoCount += 1
            let repoSplit = repo.key.split(separator: "/")
            return query + """
                repo\(repoCount): repository(owner:"\(repoSplit.first!)", name:"\(repoSplit.last!)") {
                    \(repoQuery)
                }
                
                """
        }
        
        return """
            \(pullRequestFragment)
            
            query pullRequests {
              viewer {
                ...ActorFragment
              }
            
              \(queryContent)
            }
            """
    }
    
    private static let pullRequestFragment = """
        fragment ActorFragment on Actor {
          login
          url
          ... on User {
            name
          }
        }
        
        fragment PullRequestReviewFragment on PullRequestReview {
          author {
            ...ActorFragment
          }
          bodyText
          state
          createdAt
          url
          comments(last: 30) {
            nodes {
              id
              author {
                ...ActorFragment
              }
              bodyText
              createdAt
              diffHunk
              outdated
              path
              replyTo {
                id
              }
            }
          }
        }
        
        fragment PullRequestFragment on PullRequest {
          id
          state
          title
          number
          updatedAt
          author {
            ...ActorFragment
          }
          repository {
            nameWithOwner
            url
          }
          isDraft
          url
          additions
          deletions
          timelineItems(last: 30) {
            nodes {
              type: __typename
              ... on Node {
                id
              }
              ... on ClosedEvent {
                actor {
                  ...ActorFragment
                }
                createdAt
                url
              }
              ... on HeadRefForcePushedEvent {
                actor {
                  ...ActorFragment
                }
                createdAt
              }
              ... on IssueComment {
                author {
                  ...ActorFragment
                }
                bodyText
                createdAt
                url
              }
              ... on MergedEvent {
                actor {
                  ...ActorFragment
                }
                createdAt
                url
              }
              ... on PullRequestCommit {
                commit {
                  author {
                    user {
                      ...ActorFragment
                    }
                  }
                  committedDate
                  url
                }
              }
              ... on PullRequestReview {
                ...PullRequestReviewFragment
              }
              ... on ReadyForReviewEvent {
                actor {
                  ...ActorFragment
                }
                createdAt
                url
              }
              ... on RenamedTitleEvent {
                actor {
                  ...ActorFragment
                }
                createdAt
                currentTitle
                previousTitle
              }
              ... on ReopenedEvent {
                actor {
                  ...ActorFragment
                }
                createdAt
              }
              ... on ReviewRequestedEvent {
                actor {
                  ...ActorFragment
                }
                createdAt
                requestedReviewer {
                  ... on Actor {
                    ...ActorFragment
                  }
                }
              }
            }
          }
        }
        """
}
