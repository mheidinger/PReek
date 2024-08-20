import Foundation

private struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    var intValue: Int?
    init?(intValue _: Int) {
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

enum FetchPullRequestsQueryBuilder {
    static func fetchPullRequestQuery(repoMap: [String: [Int]]) -> String {
        var repoCount = 0
        let queryContent = repoMap.reduce("") { query, repo in
            let repoQuery = repo.value.reduce("") { repoQuery, prNumber in
                repoQuery + """
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

    fragment CommentFragment on PullRequestReviewComment {
      id
      author {
        ...ActorFragment
      }
      body
      createdAt
      path
      replyTo {
        id
      }
      url
    }

    fragment PullRequestReviewFragment on PullRequestReview {
      author {
        ...ActorFragment
      }
      body
      state
      createdAt
      url
      comments(last: 30) {
        nodes {
          ...CommentFragment
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
      reviewThreads(last: 30) {
        nodes {
          comments(last: 30) {
            nodes {
              ...CommentFragment
            }
          }
        }
      }
      timelineItems(last: 30, itemTypes: [PULL_REQUEST_COMMIT, PULL_REQUEST_REVIEW, HEAD_REF_FORCE_PUSHED_EVENT, MERGED_EVENT, REVIEW_REQUESTED_EVENT, READY_FOR_REVIEW_EVENT, CONVERT_TO_DRAFT_EVENT, ISSUE_COMMENT, CLOSED_EVENT, RENAMED_TITLE_EVENT, REOPENED_EVENT]) {
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
            body
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
              messageHeadline
              oid
            }
            url
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
          ... on ConvertToDraftEvent {
            actor {
              ...ActorFragment
            }
            createdAt
            url
          }
        }
      }
    }
    """
}
