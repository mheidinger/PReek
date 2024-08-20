import Foundation
import MarkdownUI

protocol EventData {
    // Returning nil will default to the PR overview page
    var url: URL? { get }
}

struct Event: Identifiable {
    let id: String
    let user: User
    let time: Date
    let data: EventData
    let pullRequestUrl: URL

    var url: URL {
        guard let dataUrl = data.url else {
            return pullRequestUrl
        }
        if dataUrl.host() != nil {
            return dataUrl
        }

        return URL(string: dataUrl.path, relativeTo: pullRequestUrl) ?? pullRequestUrl
    }

    static let previewClosed = Event(id: UUID().uuidString, user: User.preview(login: "person-1"), time: Date(), data: PullRequestEventClosedData(url: nil), pullRequestUrl: URL(string: "https://example.com")!)
    static let previewForcePushed = Event(id: UUID().uuidString, user: User.preview(login: "person-with-long-name-2"), time: Date(), data: PullRequestEventPushedData(isForcePush: true, commits: []), pullRequestUrl: URL(string: "https://example.com")!)
    static let previewMerged = Event(id: UUID().uuidString, user: User.preview(login: "per3"), time: Date(), data: PullRequestEventMergedData(url: nil), pullRequestUrl: URL(string: "https://example.com")!)
    static func previewCommit(commits: [Commit] = []) -> Event {
        Event(id: UUID().uuidString, user: User.preview(login: "person-4"), time: Date(), data: PullRequestEventPushedData(isForcePush: false, commits: commits), pullRequestUrl: URL(string: "https://example.com")!)
    }

    static func previewReview(comments: [Comment]? = nil) -> Event {
        Event(
            id: UUID().uuidString,
            user: User.preview(login: "person-5"),
            time: Date(),
            data: PullRequestEventReviewData(
                url: nil,
                state: .changesRequested,
                comments: comments ?? [
                    Comment(id: UUID().uuidString, content: MarkdownContent("""
                    # Heading

                    > Some important comment that also is not too short as we'll get long comments and it won't stop and go on and on and on

                    **Theres more to come.**

                    *The End!*
                    """), fileReference: nil, isReply: false),
                    Comment(id: UUID().uuidString, content: MarkdownContent("Some important comment that also is not too short as we'll get long comments"), fileReference: "MyComponent.tsx#L123", isReply: true),
                ]
            ),
            pullRequestUrl: URL(string: "https://example.com")!
        )
    }

    static let previewComment = Event(
        id: UUID().uuidString,
        user: User.preview(login: "person-6"),
        time: Date(),
        data: PullRequestEventCommentData(url: nil, comment: Comment(id: UUID().uuidString, content: MarkdownContent("Hello World, this is some really long comment which basically has no content but it has to be long"), fileReference: nil, isReply: false)),
        pullRequestUrl: URL(string: "https://example.com")!
    )
    static let previewReadyForReview = Event(id: UUID().uuidString, user: User.preview(login: "person-7"), time: Date(), data: PullRequestEventReadyForReviewData(url: nil), pullRequestUrl: URL(string: "https://example.com")!)
    static let previewRenamedTitle = Event(id: UUID().uuidString, user: User.preview(login: "person-8"), time: Date(), data: PullRequestEventRenamedTitleData(currentTitle: "current title", previousTitle: "previous title"), pullRequestUrl: URL(string: "https://example.com")!)
    static let previewReopened = Event(id: UUID().uuidString, user: User.preview(login: "person-9"), time: Date(), data: PullRequestEventReopenedData(), pullRequestUrl: URL(string: "https://example.com")!)
    static let previewReviewRequested = Event(id: UUID().uuidString, user: User.preview(login: "person-10"), time: Date(), data: PullRequestEventReviewRequestedData(requestedReviewer: "me"), pullRequestUrl: URL(string: "https://example.com")!)
    static let previewConvertToDraft = Event(id: UUID().uuidString, user: User.preview(login: "person-11"), time: Date(), data: PullRequestEventConvertToDraftData(url: URL(string: "https://example.com")!), pullRequestUrl: URL(string: "https://example.com")!)
}

struct PullRequestEventClosedData: EventData {
    let url: URL?
}

struct PullRequestEventPushedData: EventData {
    var url: URL? {
        guard let first = commits.first, let last = commits.last else {
            return URL(string: "files")!
        }

        if commits.count == 1 {
            return URL(string: "files/\(first.id)")
        }
        return URL(string: "files/\(first.id)..\(last.id)")
    }

    let isForcePush: Bool
    let commits: [Commit]
}

struct PullRequestEventMergedData: EventData {
    let url: URL?
}

struct PullRequestEventReviewData: EventData {
    enum State {
        case comment
        case approve
        case changesRequested
        case dismissed
    }

    let url: URL?
    let state: State
    let comments: [Comment]
}

struct PullRequestEventCommentData: EventData {
    let url: URL?
    let comment: Comment
}

struct PullRequestEventReadyForReviewData: EventData {
    let url: URL?
}

struct PullRequestEventRenamedTitleData: EventData {
    let url: URL? = nil
    let currentTitle: String
    let previousTitle: String
}

struct PullRequestEventReopenedData: EventData {
    let url: URL? = nil
}

struct PullRequestEventReviewRequestedData: EventData {
    let url: URL? = nil
    let requestedReviewer: String?
}

struct PullRequestEventConvertToDraftData: EventData {
    let url: URL?
}
