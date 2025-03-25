import Foundation
import MarkdownUI

protocol EventData {
    // Returning nil will default to the PR overview page
    var url: URL? { get }
    func isEqual(_ other: EventData) -> Bool
}

extension EventData where Self: Equatable {
    func isEqual(_ other: EventData) -> Bool {
        guard let o = other as? Self else { return false }
        return self == o
    }
}

struct Event: Identifiable, Equatable {
    static func == (lhs: Event, rhs: Event) -> Bool {
        lhs.id == rhs.id &&
            lhs.user == rhs.user &&
            lhs.time == rhs.time &&
            lhs.url == rhs.url &&
            lhs.data.isEqual(rhs.data)
    }

    let id: String
    let user: User
    let time: Date
    let data: EventData
    let url: URL

    init(id: Event.ID, user: User, time: Date, data: EventData, pullRequestUrl: URL) {
        self.id = id
        self.user = user
        self.time = time
        self.data = data

        url = data.url.map { dataUrl in
            dataUrl.host != nil ? dataUrl : pullRequestUrl.appendingPathComponent(dataUrl.path)
        } ?? pullRequestUrl
    }

    var timeFormatted: String {
        if isDateInLastSevenDays(time) {
            return time.formatRelative
        }
        return time.formatted(
            Date.FormatStyle()
                .month(.abbreviated)
                .day(.defaultDigits)
                .hour()
                .minute()
        )
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
        data: EventCommentData(url: nil, comments: [Comment(id: UUID().uuidString, content: MarkdownContent("Hello World, this is some really long comment which basically has no content but it has to be long"), fileReference: nil, isReply: false)]),
        pullRequestUrl: URL(string: "https://example.com")!
    )
    static let previewReadyForReview = Event(id: UUID().uuidString, user: User.preview(login: "person-7"), time: Date().addingTimeInterval(-70), data: ReadyForReviewData(url: nil), pullRequestUrl: URL(string: "https://example.com")!)
    static let previewRenamedTitle = Event(id: UUID().uuidString, user: User.preview(login: "person-8"), time: Date().addingTimeInterval(-80), data: EventRenamedTitleData(currentTitle: "current title", previousTitle: "previous title"), pullRequestUrl: URL(string: "https://example.com")!)
    static let previewReopened = Event(id: UUID().uuidString, user: User.preview(login: "person-9"), time: Date().addingTimeInterval(-90), data: EventReopenedData(), pullRequestUrl: URL(string: "https://example.com")!)
    static let previewReviewRequested = Event(id: UUID().uuidString, user: User.preview(login: "person-10"), time: Date().addingTimeInterval(-100), data: EventReviewRequestedData(requestedReviewers: ["me", "you"]), pullRequestUrl: URL(string: "https://example.com")!)
    static let previewConvertToDraft = Event(id: UUID().uuidString, user: User.preview(login: "person-11"), time: Date().addingTimeInterval(-110), data: EventConvertToDraftData(url: URL(string: "https://example.com")!), pullRequestUrl: URL(string: "https://example.com")!)
    static let previewAutoMergeEnabled = Event(id: UUID().uuidString, user: User.preview(login: "person-12"), time: Date().addingTimeInterval(-120), data: EventAutoMergeEnabledData(variant: .rebase), pullRequestUrl: URL(string: "https://example.com")!)
    static let previewAutoMergeDisabled = Event(id: UUID().uuidString, user: User.preview(login: "person-13"), time: Date().addingTimeInterval(-130), data: EventAutoMergeDisabledData(), pullRequestUrl: URL(string: "https://example.com")!)
}

struct EventClosedData: EventData, Equatable {
    let url: URL?
}

struct EventPushedData: EventData, Equatable {
    var url: URL? {
        guard let first = commits.first, let last = commits.last else {
            return URL(string: "files")!
        }

        if commits.count == 1 {
            return first.url
        }
        return URL(string: "files/\(first.parentId ?? first.id)..\(last.id)")
    }

    let isForcePush: Bool
    let commits: [Commit]
}

struct EventMergedData: EventData, Equatable {
    let url: URL?
}

struct EventReviewData: EventData, Equatable {
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

struct EventCommentData: EventData, Equatable {
    let url: URL?
    let comments: [Comment]
}

struct ReadyForReviewData: EventData, Equatable {
    let url: URL?
}

struct EventRenamedTitleData: EventData, Equatable {
    let url: URL? = nil
    let currentTitle: String
    let previousTitle: String
}

struct EventReopenedData: EventData, Equatable {
    let url: URL? = nil
}

struct EventReviewRequestedData: EventData, Equatable {
    let url: URL? = nil
    let requestedReviewers: [String]
}

struct EventConvertToDraftData: EventData, Equatable {
    let url: URL?
}

struct EventAutoMergeEnabledData: EventData, Equatable {
    enum Variant: String {
        case merge
        case rebase
        case squash
    }

    let url: URL? = nil
    let variant: Variant
}

struct EventAutoMergeDisabledData: EventData, Equatable {
    let url: URL? = nil
}
