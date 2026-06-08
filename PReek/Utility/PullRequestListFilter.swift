import Foundation

/// Pure, side-effect-free computation of the filtered pull request list.
///
/// Operates on an immutable snapshot so it can run off the main thread. Unread state is
/// memoized across runs via `unreadCache` keyed by each PR's `lastUpdated` version.
enum PullRequestListFilter {
    struct UnreadCacheEntry {
        let unread: Bool
        let oldestEvent: Event?
    }

    struct Input {
        let pullRequests: [PullRequest]
        let readMap: [String: ReadData]
        let viewer: Viewer?
        let excludedUsers: Set<String>
        let showClosed: Bool
        let showRead: Bool
        let unreadCache: [String: UnreadCacheEntry]
        let lastProcessedVersions: [String: TimeInterval]
    }

    struct Output {
        let pullRequests: [PullRequest]
        let hasUnread: Bool
        let unreadCache: [String: UnreadCacheEntry]
        let lastProcessedVersions: [String: TimeInterval]
    }

    static func compute(_ input: Input) -> Output {
        var unreadCache: [String: UnreadCacheEntry] = [:]
        var lastProcessedVersions: [String: TimeInterval] = [:]
        unreadCache.reserveCapacity(input.pullRequests.count)
        lastProcessedVersions.reserveCapacity(input.pullRequests.count)

        var filteredPRs: [PullRequest] = []
        filteredPRs.reserveCapacity(input.pullRequests.count)

        for pr in input.pullRequests {
            let version = pr.lastUpdated.timeIntervalSince1970

            // Reuse cached unread state when the PR has not changed since last computation.
            let entry: UnreadCacheEntry
            if input.lastProcessedVersions[pr.id] == version, let cached = input.unreadCache[pr.id] {
                entry = cached
            } else {
                let result = PullRequestUnreadCalculator.calculateUnread(
                    for: pr,
                    viewer: input.viewer,
                    readData: input.readMap[pr.id]
                )
                entry = UnreadCacheEntry(unread: result.unread, oldestEvent: result.oldestUnreadEvent)
            }
            unreadCache[pr.id] = entry
            lastProcessedVersions[pr.id] = version

            var updatedPR = pr
            updatedPR.unread = entry.unread
            updatedPR.oldestUnreadEvent = entry.oldestEvent

            let passesClosedFilter = input.showClosed || !updatedPR.isClosed
            let passesReadFilter = input.showRead || updatedPR.unread
            guard passesClosedFilter, passesReadFilter else { continue }

            let containsNonExcludedUser = updatedPR.participantLogins.contains { login in
                !input.excludedUsers.contains(login)
            }
            guard containsNonExcludedUser else { continue }

            filteredPRs.append(updatedPR)
        }

        filteredPRs.sort { $0.lastUpdated > $1.lastUpdated }

        let hasUnread = filteredPRs.contains { $0.unread }

        return Output(
            pullRequests: filteredPRs,
            hasUnread: hasUnread,
            unreadCache: unreadCache,
            lastProcessedVersions: lastProcessedVersions
        )
    }
}
