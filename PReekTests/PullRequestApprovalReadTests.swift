import Foundation
import Testing

private let user = User.preview(login: "user")
private let viewerUser = User.preview(login: "viewer")
private let viewer = Viewer(login: "viewer", scopes: [])

private func createPullRequest(events: [Event]? = nil) -> PullRequest {
    PullRequest(
        id: UUID().uuidString,
        repository: Repository(name: "", url: URL(string: "https://example.com")!),
        author: user,
        title: "",
        number: 1,
        status: .open,
        lastUpdated: toDate(minute: 30),
        events: events ?? [
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

private func reviewEvent(
    minute: Int,
    author: User = viewerUser,
    state: EventReviewData.State = .approve
) -> Event {
    Event(
        id: "review-\(minute)",
        user: author,
        time: toDate(minute: minute),
        data: EventReviewData(url: nil, state: state, comments: []),
        pullRequestUrl: URL(string: "https://example.com")!
    )
}

private func readEvent(minute: Int, author: User = viewerUser, merging: Bool) -> Event {
    if !merging {
        return reviewEvent(minute: minute, author: author)
    }
    return Event(
        id: "merge-\(minute)",
        user: author,
        time: toDate(minute: minute),
        data: EventMergedData(url: nil),
        pullRequestUrl: URL(string: "https://example.com")!
    )
}

struct PullRequestApprovalReadTests {
    @Test(arguments: [false, true], [false, true])
    func enabledActionsSelectNewestMatchingEvent(approvals: Bool, merges: Bool) {
        let pullRequest = createPullRequest(events: [
            readEvent(minute: 45, merging: true),
            reviewEvent(minute: 35),
        ] + createPullRequest().events)
        var readData = ReadData()
        let changed = readData.processReadEvents(
            in: pullRequest,
            viewer: viewer,
            markApprovedPullRequestsAsRead: approvals,
            markMergedPullRequestsAsRead: merges
        )
        let expectedId: String? = merges ? "merge-45" : (approvals ? "review-35" : nil)

        #expect(changed == (approvals || merges))
        #expect(readData.eventId == expectedId)
        #expect(readData.lastProcessedReadEventId == expectedId)
        #expect(PullRequestUnreadCalculator.calculateUnread(
            for: pullRequest, viewer: viewer, readData: readData
        ).unread == !(approvals || merges))
    }

    @Test(arguments: [false, true], [false, true])
    func disabledActionDoesNotMutateReadData(merging: Bool, existingRead: Bool) throws {
        let pullRequest = createPullRequest(events: [
            readEvent(minute: 45, merging: merging),
        ] + createPullRequest().events)
        let data = Data(#"{"date":0,"lastProcessedApprovalId":"earlier-action"}"#.utf8)
        var readData = try JSONDecoder().decode(ReadData.self, from: data)
        if !existingRead {
            readData.date = .distantPast
        }
        let originalDate = readData.date
        let changed = readData.processReadEvents(
            in: pullRequest,
            viewer: viewer,
            markApprovedPullRequestsAsRead: merging,
            markMergedPullRequestsAsRead: !merging
        )

        #expect(!changed)
        #expect(readData.date == originalDate)
        #expect(readData.eventId == nil)
        #expect(readData.lastProcessedReadEventId == "earlier-action")

        // Disabled events are not consumed and can be applied on a later normal refresh.
        let enabledChanged = readData.processReadEvents(in: pullRequest, viewer: viewer)
        #expect(enabledChanged)
        #expect(readData.eventId == pullRequest.events[0].id)
    }

    @Test(arguments: [false, true], [false, true])
    func enabledActionsPreserveLaterActivityAndIgnoreOtherActors(approvals: Bool, merges: Bool) {
        let events = createPullRequest().events
        let pullRequest = createPullRequest(events: [
            readEvent(minute: 45, author: user, merging: true),
            reviewEvent(minute: 35, author: user),
            events[0], events[1],
            readEvent(minute: 15, merging: true),
            reviewEvent(minute: 10),
            events[2],
        ])
        var readData = ReadData()
        readData.processReadEvents(
            in: pullRequest,
            viewer: viewer,
            markApprovedPullRequestsAsRead: approvals,
            markMergedPullRequestsAsRead: merges
        )

        #expect(readData.eventId == (merges ? "merge-15" : (approvals ? "review-10" : nil)))
        #expect(PullRequestUnreadCalculator.calculateUnread(
            for: pullRequest, viewer: viewer, readData: readData
        ).unread)
    }

    @Test func disablingAndReenablingDoesNotReplayProcessedAction() {
        let pullRequest = createPullRequest(events: [reviewEvent(minute: 35)] + createPullRequest().events)
        var readData = ReadData()
        readData.processReadEvents(in: pullRequest, viewer: viewer)
        readData.date = .distantPast
        readData.eventId = nil

        let disabledChanged = readData.processReadEvents(
            in: pullRequest,
            viewer: viewer,
            markApprovedPullRequestsAsRead: false,
            markMergedPullRequestsAsRead: false
        )
        let enabledChanged = readData.processReadEvents(in: pullRequest, viewer: viewer)
        #expect(!disabledChanged)
        #expect(!enabledChanged)
        #expect(readData.date == .distantPast)
        #expect(readData.eventId == nil)
        #expect(readData.lastProcessedReadEventId == "review-35")
    }

    @Test(arguments: [false, true], [false, true])
    func viewerActionReadsEarlierActivity(existingRead: Bool, merging: Bool) {
        let events = createPullRequest().events
        let pullRequest = createPullRequest(events: [events[0], readEvent(minute: 25, merging: merging), events[1], events[2]])
        var readData = existingRead ? ReadData(date: toDate(minute: 0), eventId: "1") : ReadData()
        readData.processReadEvents(in: pullRequest, viewer: viewer)
        let result = PullRequestUnreadCalculator.calculateUnread(for: pullRequest, viewer: viewer, readData: readData)

        #expect(!result.unread)
        #expect(result.oldestUnreadEvent == nil)
    }

    @Test(arguments: [false, true])
    func activityAfterViewerActionRemainsUnread(merging: Bool) {
        let events = createPullRequest().events
        let pullRequest = createPullRequest(events: [events[0], events[1], readEvent(minute: 15, merging: merging), events[2]])
        var readData = ReadData()
        readData.processReadEvents(in: pullRequest, viewer: viewer)
        let result = PullRequestUnreadCalculator.calculateUnread(for: pullRequest, viewer: viewer, readData: readData)

        #expect(result.unread)
        #expect(result.oldestUnreadEvent?.id == "2")
    }

    @Test(arguments: [EventReviewData.State.comment, .changesRequested, .dismissed])
    func nonApprovalReviewsDoNotMarkRead(state: EventReviewData.State) {
        let pullRequest = createPullRequest(events: [reviewEvent(minute: 35, state: state)] + createPullRequest().events)
        var readData = ReadData()
        readData.processReadEvents(in: pullRequest, viewer: viewer)
        let result = PullRequestUnreadCalculator.calculateUnread(for: pullRequest, viewer: viewer, readData: readData)

        #expect(result.unread)
    }

    @Test(arguments: [false, true])
    func anotherUsersActionDoesNotMarkRead(merging: Bool) {
        let pullRequest = createPullRequest(events: [readEvent(minute: 35, author: user, merging: merging)] + createPullRequest().events)
        var readData = ReadData()
        readData.processReadEvents(in: pullRequest, viewer: viewer)
        let result = PullRequestUnreadCalculator.calculateUnread(for: pullRequest, viewer: viewer, readData: readData)

        #expect(result.unread)
    }

    @Test(arguments: [false, true], [false, true])
    func newerExplicitReadWinsOverViewerAction(useEventId: Bool, merging: Bool) {
        let events = createPullRequest().events
        let pullRequest = createPullRequest(events: [events[0], events[1], readEvent(minute: 15, merging: merging), events[2]])
        var readData = ReadData(date: toDate(minute: 25), eventId: useEventId ? "2" : "missing")
        readData.processReadEvents(in: pullRequest, viewer: viewer)
        let result = PullRequestUnreadCalculator.calculateUnread(for: pullRequest, viewer: viewer, readData: readData)

        #expect(!result.unread)
        #expect(result.oldestUnreadEvent == nil)

        // Even an action that did not advance the read boundary is consumed once.
        readData.date = .distantPast
        readData.eventId = nil
        readData.processReadEvents(in: pullRequest, viewer: viewer)
        #expect(PullRequestUnreadCalculator.calculateUnread(
            for: pullRequest, viewer: viewer, readData: readData
        ).unread)
    }

    @Test(arguments: [false, true], [false, true])
    func manualUnreadPersistsUntilNewAction(newAction: Bool, merging: Bool) throws {
        let acknowledged = createPullRequest(events: [readEvent(minute: 35, merging: merging)] + createPullRequest().events)
        var readData = ReadData()
        readData.processReadEvents(in: acknowledged, viewer: viewer)
        readData.date = .distantPast
        readData.eventId = nil

        var restored = try JSONDecoder().decode(ReadData.self, from: JSONEncoder().encode(readData))
        let refreshed = newAction
            ? createPullRequest(events: [readEvent(minute: 45, merging: merging)] + acknowledged.events) : acknowledged
        restored.processReadEvents(in: refreshed, viewer: viewer)
        let result = PullRequestUnreadCalculator.calculateUnread(for: refreshed, viewer: viewer, readData: restored)

        #expect(result.unread == !newAction)
        #expect(result.oldestUnreadEvent?.id == (newAction ? nil : "1"))
    }

    @Test func dismissedApprovalDoesNotReplayAnOlderApproval() {
        let approved = createPullRequest(events: [
            reviewEvent(minute: 35), reviewEvent(minute: 25),
        ] + createPullRequest().events.filter { $0.time < toDate(minute: 25) })
        var readData = ReadData()
        readData.processReadEvents(in: approved, viewer: viewer)
        readData.date = .distantPast
        readData.eventId = nil

        let refreshed = createPullRequest(events: [
            reviewEvent(minute: 35, state: .dismissed), reviewEvent(minute: 25),
        ] + createPullRequest().events.filter { $0.time < toDate(minute: 25) })
        readData.processReadEvents(in: refreshed, viewer: viewer)

        #expect(PullRequestUnreadCalculator.calculateUnread(
            for: refreshed, viewer: viewer, readData: readData
        ).unread)
        #expect(readData.eventId == nil)
    }

    @Test func legacyReadDataStillDecodes() throws {
        let data = Data(#"{"date":0,"eventId":"2"}"#.utf8)
        let readData = try JSONDecoder().decode(ReadData.self, from: data)

        #expect(readData.eventId == "2")
        #expect(readData.lastProcessedReadEventId == nil)
    }

    @Test func mergeAfterProcessedApprovalMarksRead() throws {
        let approved = createPullRequest(events: [reviewEvent(minute: 35)] + createPullRequest().events)
        let data = Data(#"{"date":0,"lastProcessedApprovalId":"review-35"}"#.utf8)
        var readData = try JSONDecoder().decode(ReadData.self, from: data)

        readData.processReadEvents(in: approved, viewer: viewer)
        #expect(PullRequestUnreadCalculator.calculateUnread(
            for: approved, viewer: viewer, readData: readData
        ).unread)

        let merged = createPullRequest(events: [readEvent(minute: 45, merging: true)] + approved.events)
        readData.processReadEvents(in: merged, viewer: viewer)
        #expect(!PullRequestUnreadCalculator.calculateUnread(
            for: merged, viewer: viewer, readData: readData
        ).unread)
        #expect(readData.eventId == "merge-45")
    }
}
