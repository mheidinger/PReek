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

    static let previewClosed = Event(id: UUID().uuidString, user: User.preview(login: "person-1"), time: Date().addingTimeInterval(-10), data: EventClosedData(url: nil), pullRequestUrl: URL(string: "https://example.com")!)
    static let previewForcePushed = Event(id: UUID().uuidString, user: User.preview(login: "person-with-long-name-2"), time: Date().addingTimeInterval(-20), data: EventPushedData(isForcePush: true, commits: []), pullRequestUrl: URL(string: "https://example.com")!)
    static let previewMerged = Event(id: UUID().uuidString, user: User.preview(login: "per3"), time: Date().addingTimeInterval(-30), data: EventMergedData(url: nil), pullRequestUrl: URL(string: "https://example.com")!)
    static func previewCommit(commits: [Commit] = []) -> Event {
        Event(id: UUID().uuidString, user: User.preview(login: "person-4"), time: Date().addingTimeInterval(-40), data: EventPushedData(isForcePush: false, commits: commits), pullRequestUrl: URL(string: "https://example.com")!)
    }

    static func previewReview(comments: [Comment]? = nil) -> Event {
        Event(
            id: UUID().uuidString,
            user: User.preview(login: "person-5"),
            time: Date().addingTimeInterval(-50),
            data: EventReviewData(
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
        time: Date().addingTimeInterval(-60),
        data: EventCommentData(url: nil, comment: Comment(id: UUID().uuidString, content: MarkdownContent("Hello World, this is some really long comment which basically has no content but it has to be long"), fileReference: nil, isReply: false)),
        pullRequestUrl: URL(string: "https://example.com")!
    )
    static let previewReadyForReview = Event(id: UUID().uuidString, user: User.preview(login: "person-7"), time: Date().addingTimeInterval(-70), data: ReadyForReviewData(url: nil), pullRequestUrl: URL(string: "https://example.com")!)
    static let previewRenamedTitle = Event(id: UUID().uuidString, user: User.preview(login: "person-8"), time: Date().addingTimeInterval(-80), data: EventRenamedTitleData(currentTitle: "current title", previousTitle: "previous title"), pullRequestUrl: URL(string: "https://example.com")!)
    static let previewReopened = Event(id: UUID().uuidString, user: User.preview(login: "person-9"), time: Date().addingTimeInterval(-90), data: EventReopenedData(), pullRequestUrl: URL(string: "https://example.com")!)
    static let previewReviewRequested = Event(id: UUID().uuidString, user: User.preview(login: "person-10"), time: Date().addingTimeInterval(-100), data: EventReviewRequestedData(requestedReviewer: "me"), pullRequestUrl: URL(string: "https://example.com")!)
    static let previewConvertToDraft = Event(id: UUID().uuidString, user: User.preview(login: "person-11"), time: Date().addingTimeInterval(-110), data: EventConvertToDraftData(url: URL(string: "https://example.com")!), pullRequestUrl: URL(string: "https://example.com")!)
}

struct EventClosedData: EventData {
    let url: URL?
}

struct EventPushedData: EventData {
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

struct EventMergedData: EventData {
    let url: URL?
}

struct EventReviewData: EventData {
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

struct EventCommentData: EventData {
    let url: URL?
    let comment: Comment
}

struct ReadyForReviewData: EventData {
    let url: URL?
}

struct EventRenamedTitleData: EventData {
    let url: URL? = nil
    let currentTitle: String
    let previousTitle: String
}

struct EventReopenedData: EventData {
    let url: URL? = nil
}

struct EventReviewRequestedData: EventData {
    let url: URL? = nil
    let requestedReviewer: String?
}

struct EventConvertToDraftData: EventData {
    let url: URL?
}
