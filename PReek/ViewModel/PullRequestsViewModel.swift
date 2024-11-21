import Combine
import OSLog
import SwiftUI

class PullRequestsViewModel: ObservableObject {
    private let logger = Logger()

    @Published private(set) var lastUpdated: Date? = nil
    @Published private(set) var isRefreshing = false
    @Published private(set) var error: Error? = nil
    @Published private(set) var hasUnread: Bool = false

    private var hideClosedSubject: CurrentValueSubject<Bool, Never>
    @AppStorage("hideClosed") var hideClosed: Bool = false {
        didSet {
            hideClosedSubject.send(hideClosed)
        }
    }

    private var hideReadSubject = CurrentValueSubject<Bool, Never>(false)
    @AppStorage("hideRead") var hideRead: Bool = false {
        didSet {
            hideReadSubject.send(hideRead)
        }
    }

    var pullRequests: [PullRequest] {
        memoizedPullRequests
    }

    init(initialPullRequests: [PullRequest] = []) {
        pullRequestMap = Dictionary(uniqueKeysWithValues: initialPullRequests.map { ($0.id, $0) })

        // Directly access UserDefaults w/ same keys above for correct initial values in the subject
        let storedHideClosed = UserDefaults.standard.bool(forKey: "hideClosed")
        let storedHideRead = UserDefaults.standard.bool(forKey: "hideRead")
        hideClosedSubject = CurrentValueSubject<Bool, Never>(storedHideClosed)
        hideReadSubject = CurrentValueSubject<Bool, Never>(storedHideRead)
        setupPullRequestsMemoization()
    }

    @CodableAppStorage("pullRequestReadMap") private var pullRequestReadMap: [String: Date] = [:]
    private var pullRequestMap: [String: PullRequest] = [:]
    @Published private var memoizedPullRequests: [PullRequest] = []
    private var cancellables = Set<AnyCancellable>()
    private let invalidationTrigger = PassthroughSubject<Void, Never>()

    private func setupPullRequestsMemoization() {
        // Combine dependencies that affect the pullRequests computation
        // Also add last updated as excluded users are not considered
        Publishers.CombineLatest4(
            hideClosedSubject,
            hideReadSubject,
            $lastUpdated,
            invalidationTrigger
                .prepend(())
                .setFailureType(to: Never.self)
        )
        .throttle(for: .milliseconds(100), scheduler: DispatchQueue.main, latest: true)
        .map { [weak self] hideClosed, hideRead, _, _ in
            guard let self = self else { return ([], false) }

            logger.info("Memoize pull requests")

            let updatedRead = self.pullRequestMap.map { entry in
                var pullRequest = entry.value
                pullRequest.lastMarkedAsRead = self.pullRequestReadMap[pullRequest.id]
                return pullRequest
            }
            let filtered = updatedRead.filter { pullRequest in
                let containsNonExcludedUser = pullRequest.events.contains { event in
                    !ConfigService.excludedUsers.contains(event.user.login)
                }

                let passesClosedFilter = !hideClosed || !pullRequest.isClosed
                let passesReadFilter = !hideRead || pullRequest.unread

                return containsNonExcludedUser && passesClosedFilter && passesReadFilter
            }
            let filteredAndSorted = filtered.sorted {
                $0.lastUpdated > $1.lastUpdated
            }

            let hasUnread = filteredAndSorted.contains { $0.unread }
            return (filteredAndSorted, hasUnread)
        }
        .receive(on: DispatchQueue.main)
        .sink { [weak self] (pullRequests: [PullRequest], hasUnread: Bool) in
            self?.memoizedPullRequests = pullRequests
            self?.hasUnread = hasUnread
        }
        .store(in: &cancellables)
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
        invalidationTrigger.send()
    }

    func markAllAsRead() {
        for pullRequest in pullRequests {
            pullRequestReadMap[pullRequest.id] = lastUpdated
        }
        invalidationTrigger.send()
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

            await MainActor.run {
                for pullRequest in pullRequests {
                    self.pullRequestMap[pullRequest.id] = pullRequest
                }
                self.invalidationTrigger.send()
            }
            return pullRequests.map { $0.id }
        } else {
            logger.info("No new PRs to fetch")
        }
        return []
    }

    func updatePullRequests() async {
        do {
            await MainActor.run {
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

            await MainActor.run {
                self.lastUpdated = newLastUpdated
                self.isRefreshing = false
                self.error = nil
            }

            await cleanupPullRequests()
            logger.info("Finished fetching notifications")
        } catch {
            logger.error("Failed to get pull requests: \(error)")
            await MainActor.run {
                self.isRefreshing = false
                self.error = error
            }
        }
    }

    private func cleanupPullRequests() async {
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
            await MainActor.run {
                self.pullRequestMap = filteredPullRequestMap
                self.pullRequestReadMap = filteredPullRequestReadMap
            }
        }
    }
}
