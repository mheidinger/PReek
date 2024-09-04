import Foundation

struct PullRequestDto: Decodable {
    enum State: String, Decodable {
        case OPEN
        case CLOSED
        case MERGED
    }

    enum ReviewState: String, Decodable {
        case PENDING
        case COMMENTED
        case APPROVED
        case CHANGES_REQUESTED
        case DISMISSED
    }

    struct Actor: Decodable {
        let login: String
        let url: String
        let name: String?
    }

    // This is an empty object if we don't fetch teams but have permission for it
    struct ActorOrTeam: Decodable {
        /// only on Actor
        let login: String?
        /// required on Team, optional on Actor
        let name: String?
        let url: String?
    }

    struct Repository: Decodable {
        let nameWithOwner: String
        let url: String
    }

    struct TimelineItems: Decodable {
        let nodes: [TimelineItem]?
    }

    struct TimelineItem: Decodable {
        enum ItemType: String, CaseIterableDefaultsLast {
            case ClosedEvent
            case HeadRefForcePushedEvent
            case IssueComment
            case MergedEvent
            case PullRequestCommit
            case PullRequestReview
            case ReadyForReviewEvent
            case RenamedTitleEvent
            case ReopenedEvent
            case ReviewRequestedEvent
            case ConvertToDraftEvent
            case Unknown
        }

        let id: String?
        let type: ItemType

        /// all except PullRequestCommit (commit.committedDate)
        let createdAt: Date?
        /// all except PullRequestReview (author.user), PullRequestCommit (commit.author.user)
        let actor: Actor?
        /// all except HeadRefForcePushedEvent, RenamedTitleEvent, ReopenedEvent, ReviewRequestedEvent
        let url: String?
        /// PullRequestCommit
        let commit: Commit?
        /// PullRequestReview and IssueComment
        let author: Actor?
        let body: String?
        /// PullRequestReview
        let state: ReviewState?
        let comments: ReviewComments?
        /// RenamedTitleEvent
        let currentTitle: String?
        let previousTitle: String?
        /// ReviewRequestedEvent
        let requestedReviewer: ActorOrTeam?
        
        var resolvedActor: Actor? {
            actor ?? author ?? commit?.author?.user
        }
        
        var resolvedTime: Date {
            createdAt ?? commit?.committedDate ?? Date()
        }
    }

    struct Commit: Decodable {
        let author: CommitAuthor?
        let committedDate: Date
        let messageHeadline: String
        let oid: String
    }

    struct CommitAuthor: Decodable {
        let user: Actor?
    }

    struct ReviewComments: Decodable {
        let nodes: [ReviewComment]?
    }

    struct ReviewComment: Decodable {
        let id: String
        let author: Actor?
        let body: String
        let createdAt: Date
        let path: String
        let replyTo: ReviewCommentReplyTo?
        let url: String
    }

    struct ReviewCommentReplyTo: Decodable {
        let id: String
    }

    struct ReviewThreads: Decodable {
        let nodes: [ReviewThread]?
    }

    struct ReviewThread: Decodable {
        let comments: ReviewComments
    }

    struct LatestOpinionatedReviews: Decodable {
        let nodes: [LatestOpinionatedReview]?
    }

    struct LatestOpinionatedReview: Decodable {
        let state: ReviewState
        let author: Actor
    }

    let id: String
    let state: State
    let isDraft: Bool
    let title: String
    let number: Int
    let updatedAt: Date
    let author: Actor?
    let repository: Repository
    let latestOpinionatedReviews: LatestOpinionatedReviews?
    let reviewThreads: ReviewThreads
    let timelineItems: TimelineItems
    let url: String
    let additions: Int
    let deletions: Int
}
