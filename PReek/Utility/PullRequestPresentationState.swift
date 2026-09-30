import Foundation

/// Keeps the latest fetched pull requests separate from the snapshot currently shown to the user.
/// While presentation is active, remote changes accumulate in `latestPullRequests` until they are
/// explicitly applied or presentation ends.
struct PullRequestPresentationState {
    private(set) var latestPullRequests: [String: PullRequest]
    private(set) var presentedPullRequests: [String: PullRequest]
    private(set) var isPresentationActive = false

    init(initialPullRequests: [PullRequest] = []) {
        let initialMap = Dictionary(uniqueKeysWithValues: initialPullRequests.map { ($0.id, $0) })
        latestPullRequests = initialMap
        presentedPullRequests = initialMap
    }

    var hasPendingUpdates: Bool {
        latestPullRequests != presentedPullRequests
    }

    /// Returns whether the presented snapshot changed.
    @discardableResult
    mutating func mergeLatest(
        _ pullRequests: [PullRequest],
        applyingWhileActive: Bool = false
    ) -> Bool {
        for pullRequest in pullRequests {
            latestPullRequests[pullRequest.id] = pullRequest
        }
        if applyingWhileActive {
            return applyLatest()
        }
        return publishLatestIfAllowed()
    }

    /// Returns whether the presented snapshot changed.
    @discardableResult
    mutating func replaceLatest(
        with pullRequests: [String: PullRequest],
        applyingWhileActive: Bool = false
    ) -> Bool {
        latestPullRequests = pullRequests
        if applyingWhileActive {
            return applyLatest()
        }
        return publishLatestIfAllowed()
    }

    /// Returns whether ending presentation applied a new snapshot.
    @discardableResult
    mutating func setPresentationActive(_ isActive: Bool) -> Bool {
        isPresentationActive = isActive
        return publishLatestIfAllowed()
    }

    /// Returns whether a new snapshot was applied.
    @discardableResult
    mutating func applyLatest() -> Bool {
        guard presentedPullRequests != latestPullRequests else { return false }
        presentedPullRequests = latestPullRequests
        return true
    }

    private mutating func publishLatestIfAllowed() -> Bool {
        guard !isPresentationActive else { return false }
        return applyLatest()
    }
}
