import Foundation
import MarkdownUI

protocol PullRequestEventData {
    // Returning nil will default to the PR overview page
    var url: URL? { get }
}

struct PullRequestEvent: Identifiable {
    let id: String
    let user: User
    let time: Date
    let data: PullRequestEventData
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
    
    static let previewClosed = PullRequestEvent(id: UUID().uuidString, user: User.preview(login: "person-1"), time: Date(), data: PullRequestEventClosedData(url: nil), pullRequestUrl: URL(string: "https://example.com")!)
    static let previewForcePushed = PullRequestEvent(id: UUID().uuidString, user: User.preview(login: "person-with-long-name-2"), time: Date(), data: PullRequestEventPushedData(isForcePush: true, commits: []), pullRequestUrl: URL(string: "https://example.com")!)
    static let previewMerged = PullRequestEvent(id: UUID().uuidString, user: User.preview(login: "per3"), time: Date(), data: PullRequestEventMergedData(url: nil), pullRequestUrl: URL(string: "https://example.com")!)
    static func previewCommit(commits: [Commit] = []) -> PullRequestEvent {
        PullRequestEvent(id: UUID().uuidString, user: User.preview(login: "person-4"), time: Date(), data: PullRequestEventPushedData(isForcePush: false, commits: commits), pullRequestUrl: URL(string: "https://example.com")!)
    }
    static func previewReview(comments: [PullRequestReviewComment]? = nil) -> PullRequestEvent {
        PullRequestEvent(
            id: UUID().uuidString,
            user: User.preview(login: "person-5"),
            time: Date(),
            data: PullRequestEventReviewData(
                url: nil,
                state: .changesRequested,
                comments: comments ?? [
                    PullRequestReviewComment(id: UUID().uuidString, comment: MarkdownContent("""
                        # Heading
                        
                        > Some important comment that also is not too short as we'll get long comments and it won't stop and go on and on and on
                        
                        **Theres more to come.**
                        
                        *The End!*
                        """), fileReference: nil, isReply: false),
                    PullRequestReviewComment(id: UUID().uuidString, comment: MarkdownContent("Some important comment that also is not too short as we'll get long comments"), fileReference: "MyComponent.tsx#L123", isReply: true)
                ]
            ),
            pullRequestUrl: URL(string: "https://example.com")!
        )
    }
    static let previewComment = PullRequestEvent(
        id: UUID().uuidString,
        user: User.preview(login: "person-6"),
        time: Date(),
        data: PullRequestEventCommentData(url: nil, comment: MarkdownContent("Hello World, this is some really long comment which basically has no content but it has to be long")),
        pullRequestUrl: URL(string: "https://example.com")!
    )
    static let previewReadyForReview = PullRequestEvent(id: UUID().uuidString, user: User.preview(login: "person-7"), time: Date(), data: PullRequestEventReadyForReviewData(url: nil), pullRequestUrl: URL(string: "https://example.com")!)
    static let previewRenamedTitle = PullRequestEvent(id: UUID().uuidString, user: User.preview(login: "person-8"), time: Date(), data: PullRequestEventRenamedTitleData(currentTitle: "current title", previousTitle: "previous title"), pullRequestUrl: URL(string: "https://example.com")!)
    static let previewReopened = PullRequestEvent(id: UUID().uuidString, user: User.preview(login: "person-9"), time: Date(), data: PullRequestEventReopenedData(), pullRequestUrl: URL(string: "https://example.com")!)
    static let previewReviewRequested = PullRequestEvent(id: UUID().uuidString, user: User.preview(login: "person-10"), time: Date(), data: PullRequestEventReviewRequestedData(requestedReviewer: "me"), pullRequestUrl: URL(string: "https://example.com")!)
}

struct PullRequestEventClosedData: PullRequestEventData {
    let url: URL?
}

struct PullRequestEventPushedData: PullRequestEventData {
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

struct PullRequestEventMergedData: PullRequestEventData {
    let url: URL?
}

struct PullRequestReviewComment: Identifiable {
    let id: String
    let comment: MarkdownContent
    let fileReference: String?
    let isReply: Bool
}

struct PullRequestEventReviewData: PullRequestEventData {
    enum State {
        case comment
        case approve
        case changesRequested
        case dismissed
    }
    
    let url: URL?
    let state: State
    let comments: [PullRequestReviewComment]
}

struct PullRequestEventCommentData: PullRequestEventData {
    let url: URL?
    let comment: MarkdownContent
}

struct PullRequestEventReadyForReviewData: PullRequestEventData {
    let url: URL?
}

struct PullRequestEventRenamedTitleData: PullRequestEventData {
    let url: URL? = nil
    let currentTitle: String
    let previousTitle: String
}

struct PullRequestEventReopenedData: PullRequestEventData {
    let url: URL? = nil
}

struct PullRequestEventReviewRequestedData: PullRequestEventData {
    let url: URL? = nil
    let requestedReviewer: String?
}
