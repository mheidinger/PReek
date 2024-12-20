import Foundation
import Testing

private let user = User.preview(login: "user")
private let viewerUser = User.preview(login: "viewer")
private let viewer = Viewer(login: "viewer", scopes: [])

private func createPullRequest() -> PullRequest {
    PullRequest(
        id: UUID().uuidString,
        repository: Repository(name: "", url: URL(string: "https://example.com")!),
        author: User(login: "", displayName: "", url: URL(string: "https://example.com")!),
        title: "",
        number: 1,
        status: .open,
        lastUpdated: toDate(minute: 30),
        events: [
            // Events are always sorted from newest to oldest
            Event(id: "3", user: viewerUser, time: toDate(minute: 30), data: EventClosedData(url: nil), pullRequestUrl: URL(string: "https://example.com")!),
            Event(id: "2", user: user, time: toDate(minute: 20), data: EventClosedData(url: nil), pullRequestUrl: URL(string: "https://example.com")!),
            Event(id: "1", user: user, time: toDate(minute: 10), data: EventClosedData(url: nil), pullRequestUrl: URL(string: "https://example.com")!),
        ],
        url: URL(string: "https://example.com")!,
        additions: 1,
        deletions: 1,
        approvalFrom: [],
        changesRequestedFrom: []
    )
}

struct PullRequestUnreadTests {
    @Test func noData() async throws {
        var pullRequest = createPullRequest()
        pullRequest.calculateUnread(viewer: viewer, readData: nil)

        #expect(pullRequest.unread == true)
        #expect(pullRequest.oldestUnreadEvent == nil)
    }

    @Test func missingEventUnread() async throws {
        var pullRequest = createPullRequest()
        pullRequest.calculateUnread(viewer: viewer, readData: ReadData(date: toDate(minute: 15), eventId: "does-not-exist"))

        #expect(pullRequest.unread == true)
        #expect(pullRequest.oldestUnreadEvent?.id == "2")
    }

    @Test func missingEventRead() async throws {
        var pullRequest = createPullRequest()
        pullRequest.calculateUnread(viewer: viewer, readData: ReadData(date: toDate(minute: 40), eventId: "does-not-exist"))

        #expect(pullRequest.unread == false)
        #expect(pullRequest.oldestUnreadEvent == nil)
    }

    @Test func missingEventReadIgnoringViewerEvent() async throws {
        var pullRequest = createPullRequest()
        pullRequest.calculateUnread(viewer: viewer, readData: ReadData(date: toDate(minute: 25), eventId: "does-not-exist"))

        #expect(pullRequest.unread == false)
        #expect(pullRequest.oldestUnreadEvent == nil)
    }

    @Test func eventUnread() async throws {
        var pullRequest = createPullRequest()
        // Date is ignored, demonstrated by date having a 'read' value
        pullRequest.calculateUnread(viewer: viewer, readData: ReadData(date: toDate(minute: 40), eventId: "1"))

        #expect(pullRequest.unread == true)
        #expect(pullRequest.oldestUnreadEvent?.id == "2")
    }

    @Test func eventRead() async throws {
        var pullRequest = createPullRequest()
        // Date is ignored, demonstrated by date having a 'unread' value
        pullRequest.calculateUnread(viewer: viewer, readData: ReadData(date: toDate(minute: 0), eventId: "3"))

        #expect(pullRequest.unread == false)
        #expect(pullRequest.oldestUnreadEvent == nil)
    }

    @Test func eventReadIgnoringViewerEvent() async throws {
        var pullRequest = createPullRequest()
        // Date is ignored, demonstrated by date having a 'unread' value
        pullRequest.calculateUnread(viewer: viewer, readData: ReadData(date: toDate(minute: 0), eventId: "2"))

        #expect(pullRequest.unread == false)
        #expect(pullRequest.oldestUnreadEvent == nil)
    }
}
