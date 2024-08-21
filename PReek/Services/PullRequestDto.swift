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

    struct User: Decodable {
        var login: String
        var url: String
        var name: String?
    }

    struct Repository: Decodable {
        var nameWithOwner: String
        var url: String
    }

    struct TimelineItems: Decodable {
        var nodes: [TimelineItem]?
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

        var id: String?
        var type: ItemType

        /// all except PullRequestCommit (commit.committedDate)
        var createdAt: Date?
        /// all except PullRequestReview (author.user), PullRequestCommit (commit.author.user)
        var actor: User?
        /// all except HeadRefForcePushedEvent, RenamedTitleEvent, ReopenedEvent, ReviewRequestedEvent
        var url: String?
        /// PullRequestCommit
        var commit: Commit?
        /// PullRequestReview and IssueComment
        var author: User?
        var body: String?
        /// PullRequestReview
        var state: ReviewState?
        var comments: ReviewComments?
        /// RenamedTitleEvent
        var currentTitle: String?
        var previousTitle: String?
        /// ReviewRequestedEvent
        var requestedReviewer: User?
    }

    struct Commit: Decodable {
        var author: CommitAuthor?
        var committedDate: Date
        var messageHeadline: String
        var oid: String
    }

    struct CommitAuthor: Decodable {
        var user: User?
    }

    struct ReviewComments: Decodable {
        var nodes: [ReviewComment]?
    }

    struct ReviewComment: Decodable {
        var id: String
        var author: User?
        var body: String
        var createdAt: Date
        var path: String
        var replyTo: ReviewCommentReplyTo?
        var url: String
    }

    struct ReviewCommentReplyTo: Decodable {
        var id: String
    }

    struct ReviewThreads: Decodable {
        var nodes: [ReviewThread]?
    }

    struct ReviewThread: Decodable {
        var comments: ReviewComments
    }

    struct LatestOpinionatedReviews: Decodable {
        var nodes: [LatestOpinionatedReview]?
    }

    struct LatestOpinionatedReview: Decodable {
        var state: ReviewState
        var author: User
    }

    var id: String
    var state: State
    var isDraft: Bool
    var title: String
    var number: Int
    var updatedAt: Date
    var author: User?
    var repository: Repository
    var latestOpinionatedReviews: LatestOpinionatedReviews?
    var reviewThreads: ReviewThreads
    var timelineItems: TimelineItems
    var url: String
    var additions: Int
    var deletions: Int
}
