import OSLog
import SwiftUI

class PullRequestsViewModel: ObservableObject {
    @Published var lastUpdated: Date? = nil
    @Published var isRefreshing = false
    @Published var error: Error? = nil

    private let logger = Logger()

    @AppStorage("hideClosed") var hideClosed: Bool = true {
        didSet {
            objectWillChange.send()
        }
    }

    @AppStorage("hideRead") var hideRead: Bool = true {
        didSet {
            objectWillChange.send()
        }
    }

    @CodableAppStorage("pullRequestReadMap") private var pullRequestReadMap: [String: Date] = [:]
    @Published var hasUnread: Bool = false

    @Published private var pullRequestMap: [String: PullRequest] = [:]
    var pullRequests: [PullRequest] {
        pullRequestMap.map { entry in
            var pullRequest = entry.value
            pullRequest.lastMarkedAsRead = pullRequestReadMap[pullRequest.id]
            return pullRequest
        }.filter { pullRequest in
            let containsNonExcludedUser = pullRequest.events.contains { event in
                !ConfigService.excludedUsers.contains(event.user.login)
            }

            let passesClosedFilter = !hideClosed || !pullRequest.isClosed
            let passesReadFilter = !hideRead || pullRequest.unread

            return containsNonExcludedUser && passesClosedFilter && passesReadFilter
        }.sorted {
            $0.lastUpdated > $1.lastUpdated
        }
    }

    private var timer: Timer?

    func triggerUpdatePullRequests() {
        Task {
            await updatePullRequests()
        }
    }

    func startFetchTimer() {
        if timer != nil {
            return
        }
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            self.triggerUpdatePullRequests()
        }
    }

    func toggleRead(_ pullRequest: PullRequest) {
        if pullRequest.unread {
            pullRequestReadMap[pullRequest.id] = lastUpdated
        } else {
            pullRequestReadMap.removeValue(forKey: pullRequest.id)
        }
        updateHasUnread()
        objectWillChange.send()
    }

    func markAllAsRead() {
        for pullRequest in pullRequests {
            pullRequestReadMap[pullRequest.id] = lastUpdated
        }
        updateHasUnread()
        objectWillChange.send()
    }

    private func updateHasUnread() {
        hasUnread = pullRequests.first { pullRequest in pullRequest.unread } != nil
    }

    private func handleReceivedNotifications(notifications: [Notification], viewer: Viewer) async throws -> [String] {
        logger.info("Got \(notifications.count) notifications")

        let repoMap = notifications.reduce([String: [Int]]()) { repoMap, notification in
            var repoMapClone = repoMap

            let existingPRs = repoMap[notification.repo]
            repoMapClone[notification.repo] = (existingPRs ?? []) + [notification.prNumber]

            return repoMapClone
        }

        return try await fetchPullRequestMap(repoMap: repoMap, viewer: viewer)
    }

    private func fetchPullRequestMap(repoMap: [String: [Int]], viewer: Viewer) async throws -> [String] {
        if !repoMap.isEmpty {
            let pullRequests = try await GitHubService.fetchPullRequests(repoMap: repoMap, viewer: viewer)
            logger.info("Got \(pullRequests.count) pull requests")

            DispatchQueue.main.async {
                for pullRequest in pullRequests {
                    self.pullRequestMap[pullRequest.id] = pullRequest
                }
                self.updateHasUnread()
            }
            return pullRequests.map { $0.id }
        } else {
            logger.info("No new PRs to fetch")
        }
        return []
    }

    func updatePullRequests() async {
        do {
            DispatchQueue.main.async {
                self.isRefreshing = true
            }

            logger.info("Get current user")
            let viewer = try await GitHubService.fetchViewer()

            logger.info("Start fetching notifications")
            let newLastUpdated = Date()
            let since = lastUpdated ?? Calendar.current.date(byAdding: .day, value: ConfigService.onStartFetchWeeks * 7 * -1, to: newLastUpdated)!
            let updatedPullRequestIds = try await GitHubService.fetchUserNotifications(since: since, onNotificationsReceived: { try await handleReceivedNotifications(notifications: $0, viewer: viewer) })

            logger.info("Start fetching not updated pull requests")
            let notUpdatedRepoMap = pullRequestMap.values.filter { pullRequest in
                !updatedPullRequestIds.contains(pullRequest.id) && pullRequest.status != .merged
            }.reduce([String: [Int]]()) { repoMap, pullRequest in
                var repoMapClone = repoMap

                let existingPRs = repoMap[pullRequest.repository.name]
                repoMapClone[pullRequest.repository.name] = (existingPRs ?? []) + [pullRequest.number]

                return repoMapClone
            }
            _ = try await fetchPullRequestMap(repoMap: notUpdatedRepoMap, viewer: viewer)

            cleanupPullRequests()

            DispatchQueue.main.async {
                self.lastUpdated = newLastUpdated
                self.isRefreshing = false
                self.error = nil
            }
            logger.info("Finished fetching notifications")
        } catch {
            logger.error("Failed to get pull requests: \(error)")
            DispatchQueue.main.async {
                self.isRefreshing = false
                self.error = error
            }
        }
    }

    private func cleanupPullRequests() {
        let daysToDeduct = (ConfigService.deleteAfterWeeks * 7) + 1
        let deleteFrom = Calendar.current.date(byAdding: .day, value: daysToDeduct * -1, to: Date())!

        let filteredPullRequestMap = pullRequestMap.filter { _, pullRequest in
            pullRequest.lastUpdated > deleteFrom || (ConfigService.deleteOnlyClosed && !pullRequest.isClosed)
        }

        let filteredPullRequestReadMap = pullRequestReadMap.filter { pullRequestId, _ in
            filteredPullRequestMap.index(forKey: pullRequestId) != nil
        }

        if filteredPullRequestMap.count != pullRequestMap.count || filteredPullRequestReadMap.count != pullRequestReadMap.count {
            // swiftformat:disable redundantSelf
            logger.info("Removing \(self.pullRequestMap.count - filteredPullRequestMap.count) pull requests")
            logger.info("Removing \(self.pullRequestReadMap.count - filteredPullRequestReadMap.count) pull requests read info")
            // swiftformat:enable redundantSelf
            DispatchQueue.main.async {
                self.pullRequestMap = filteredPullRequestMap
                self.pullRequestReadMap = filteredPullRequestReadMap
            }
        }
    }
}
