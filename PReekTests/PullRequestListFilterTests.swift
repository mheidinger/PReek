import Foundation
import Testing

private let viewer = Viewer(login: "viewer", scopes: [])

private func makePR(
    id: String,
    status: PullRequest.Status = .open,
    participant: String = "alice",
    lastUpdated: Date = toDate(minute: 30)
) -> PullRequest {
    PullRequest(
        id: id,
        repository: Repository(name: "", url: URL(string: "https://example.com")!),
        author: User.preview(login: participant),
        title: "",
        number: 1,
        status: status,
        lastUpdated: lastUpdated,
        events: [
            Event(id: "\(id)-e1", user: User.preview(login: participant), time: lastUpdated, data: EventClosedData(url: nil), pullRequestUrl: URL(string: "https://example.com")!),
        ],
        url: URL(string: "https://example.com")!,
        additions: 0,
        deletions: 0,
        approvalFrom: [],
        changesRequestedFrom: []
    )
}

private func makeInput(
    pullRequests: [PullRequest],
    readMap: [String: ReadData] = [:],
    excludedUsers: Set<String> = [],
    showClosed: Bool = true,
    showRead: Bool = true,
    unreadCache: [String: PullRequestListFilter.UnreadCacheEntry] = [:],
    lastProcessedVersions: [String: TimeInterval] = [:]
) -> PullRequestListFilter.Input {
    PullRequestListFilter.Input(
        pullRequests: pullRequests,
        readMap: readMap,
        viewer: viewer,
        excludedUsers: excludedUsers,
        showClosed: showClosed,
        showRead: showRead,
        unreadCache: unreadCache,
        lastProcessedVersions: lastProcessedVersions
    )
}

struct PullRequestListFilterTests {
    @Test func excludesPullRequestWhenAllParticipantsExcluded() {
        let pr = makePR(id: "1", participant: "bot")
        let output = PullRequestListFilter.compute(makeInput(pullRequests: [pr], excludedUsers: ["bot"]))

        #expect(output.pullRequests.isEmpty)
    }

    @Test func keepsPullRequestWhenSomeParticipantNotExcluded() {
        let pr = makePR(id: "1", participant: "alice")
        let output = PullRequestListFilter.compute(makeInput(pullRequests: [pr], excludedUsers: ["bot"]))

        #expect(output.pullRequests.map(\.id) == ["1"])
    }

    @Test func reFiltersWhenExcludedListChanges() {
        let pr = makePR(id: "1", participant: "bot")

        let visible = PullRequestListFilter.compute(makeInput(pullRequests: [pr], excludedUsers: []))
        #expect(visible.pullRequests.map(\.id) == ["1"])

        let hidden = PullRequestListFilter.compute(makeInput(pullRequests: [pr], excludedUsers: ["bot"]))
        #expect(hidden.pullRequests.isEmpty)
    }

    @Test func showClosedToggleFiltersClosedPullRequests() {
        let pr = makePR(id: "1", status: .merged)

        let hidden = PullRequestListFilter.compute(makeInput(pullRequests: [pr], showClosed: false))
        #expect(hidden.pullRequests.isEmpty)

        let visible = PullRequestListFilter.compute(makeInput(pullRequests: [pr], showClosed: true))
        #expect(visible.pullRequests.map(\.id) == ["1"])
    }

    @Test func showReadToggleFiltersReadPullRequests() {
        let pr = makePR(id: "1")
        let version = pr.lastUpdated.timeIntervalSince1970
        // Force the PR to be considered read via a matching cache entry.
        let readCache = ["1": PullRequestListFilter.UnreadCacheEntry(unread: false, oldestEvent: nil)]
        let versions = ["1": version]

        let hidden = PullRequestListFilter.compute(makeInput(
            pullRequests: [pr],
            showRead: false,
            unreadCache: readCache,
            lastProcessedVersions: versions
        ))
        #expect(hidden.pullRequests.isEmpty)

        let visible = PullRequestListFilter.compute(makeInput(
            pullRequests: [pr],
            showRead: true,
            unreadCache: readCache,
            lastProcessedVersions: versions
        ))
        #expect(visible.pullRequests.map(\.id) == ["1"])
    }

    @Test func reusesUnreadCacheWhenVersionMatches() {
        let pr = makePR(id: "1")
        let version = pr.lastUpdated.timeIntervalSince1970
        // Cached value contradicts a fresh calculation (no readData would be unread == true).
        let cache = ["1": PullRequestListFilter.UnreadCacheEntry(unread: false, oldestEvent: nil)]

        let reused = PullRequestListFilter.compute(makeInput(
            pullRequests: [pr],
            unreadCache: cache,
            lastProcessedVersions: ["1": version]
        ))
        #expect(reused.pullRequests.first?.unread == false)

        // Without matching versions the value is recomputed (no readData -> unread).
        let recomputed = PullRequestListFilter.compute(makeInput(pullRequests: [pr], unreadCache: cache))
        #expect(recomputed.pullRequests.first?.unread == true)
    }
}
