import Foundation
import Testing

private func makePresentationPR(id: String, title: String, lastUpdated: Date = Date()) -> PullRequest {
    PullRequest(
        id: id,
        repository: Repository(name: "repo", url: URL(string: "https://example.com")!),
        author: User.preview(login: "alice"),
        title: title,
        number: 1,
        status: .open,
        lastUpdated: lastUpdated,
        events: [],
        url: URL(string: "https://example.com")!,
        additions: 0,
        deletions: 0,
        approvalFrom: [],
        changesRequestedFrom: []
    )
}

struct PullRequestPresentationStateTests {
    @Test func publishesRemoteUpdatesImmediatelyWhileInactive() {
        let original = makePresentationPR(id: "1", title: "Original")
        let updated = makePresentationPR(id: "1", title: "Updated")
        var state = PullRequestPresentationState(initialPullRequests: [original])

        let changed = state.mergeLatest([updated])

        #expect(changed)
        #expect(state.presentedPullRequests["1"]?.title == "Updated")
        #expect(!state.hasPendingUpdates)
    }

    @Test func stagesCompleteSnapshotWhilePresentationIsActive() {
        let original = makePresentationPR(id: "1", title: "Original")
        let updated = makePresentationPR(id: "1", title: "Updated")
        let added = makePresentationPR(id: "2", title: "Added")
        var state = PullRequestPresentationState(initialPullRequests: [original])
        state.setPresentationActive(true)

        let changed = state.mergeLatest([updated, added])

        #expect(!changed)
        #expect(state.presentedPullRequests.count == 1)
        #expect(state.presentedPullRequests["1"]?.title == "Original")
        #expect(state.presentedPullRequests["2"] == nil)
        #expect(state.hasPendingUpdates)
    }

    @Test func explicitApplyPublishesPendingSnapshot() {
        let original = makePresentationPR(id: "1", title: "Original")
        let updated = makePresentationPR(id: "1", title: "Updated")
        var state = PullRequestPresentationState(initialPullRequests: [original])
        state.setPresentationActive(true)
        state.mergeLatest([updated])

        let changed = state.applyLatest()

        #expect(changed)
        #expect(state.presentedPullRequests["1"]?.title == "Updated")
        #expect(!state.hasPendingUpdates)
        #expect(state.isPresentationActive)
    }

    @Test func canPublishInitialRefreshWhilePresentationIsActive() {
        let added = makePresentationPR(id: "1", title: "Added")
        var state = PullRequestPresentationState()
        state.setPresentationActive(true)

        let changed = state.mergeLatest([added], applyingWhileActive: true)

        #expect(changed)
        #expect(state.presentedPullRequests[added.id] == added)
        #expect(!state.hasPendingUpdates)
        #expect(state.isPresentationActive)
    }

    @Test func endingPresentationPublishesPendingSnapshot() {
        let original = makePresentationPR(id: "1", title: "Original")
        let added = makePresentationPR(id: "2", title: "Added")
        var state = PullRequestPresentationState(initialPullRequests: [original])
        state.setPresentationActive(true)
        state.mergeLatest([added])

        let changed = state.setPresentationActive(false)

        #expect(changed)
        #expect(Set(state.presentedPullRequests.keys) == ["1", "2"])
        #expect(!state.hasPendingUpdates)
    }

    @Test func stagesRemovalsWhilePresentationIsActive() {
        let first = makePresentationPR(id: "1", title: "First")
        let second = makePresentationPR(id: "2", title: "Second")
        var state = PullRequestPresentationState(initialPullRequests: [first, second])
        state.setPresentationActive(true)

        state.replaceLatest(with: [first.id: first])

        #expect(state.presentedPullRequests[second.id] != nil)
        #expect(state.hasPendingUpdates)

        state.applyLatest()
        #expect(state.presentedPullRequests[second.id] == nil)
    }
}
