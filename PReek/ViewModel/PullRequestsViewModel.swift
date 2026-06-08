import Combine
import OSLog
import SwiftUI

class PullRequestsViewModel: ObservableObject {
    private let logger = Logger()
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?
    private var viewer: Viewer?

    init(initialPullRequests: [PullRequest] = []) {
        pullRequestMap = Dictionary(uniqueKeysWithValues: initialPullRequests.map { ($0.id, $0) })

        // Directly access UserDefaults w/ same keys above for correct initial values in the subject
        let storedShowClosed = UserDefaults.standard.bool(forKey: "showClosed")
        let storedShowRead = UserDefaults.standard.bool(forKey: "showRead")
        showClosedSubject = CurrentValueSubject<Bool, Never>(storedShowClosed)
        showReadSubject = CurrentValueSubject<Bool, Never>(storedShowRead)
        setupPullRequestsMemoization()
    }

    deinit {
        timer?.invalidate()
        timer = nil
        cancellables.removeAll()
    }

    @Published private(set) var lastUpdated: Date? = nil
    @Published private(set) var isRefreshing = false
    @Published var error: Error? = nil
    @Published private(set) var hasUnread: Bool = false

    private var showClosedSubject: CurrentValueSubject<Bool, Never>
    @AppStorage("showClosed") var showClosed: Bool = true {
        didSet {
            showClosedSubject.send(showClosed)
        }
    }

    private var showReadSubject = CurrentValueSubject<Bool, Never>(false)
    @AppStorage("showRead") var showRead: Bool = true {
        didSet {
            showReadSubject.send(showRead)
        }
    }

    var pullRequests: [PullRequest] {
        memoizedPullRequests
    }

    @CodableAppStorage("pullRequestReadMap") private var pullRequestReadMap: [String: ReadData] =
        [:]
    private var pullRequestMap: [String: PullRequest] = [:]
    /// Wall-clock time each PR was last fetched from GitHub, used to skip refetching recently
    /// updated non-notified PRs (stale-while-revalidate).
    private var pullRequestLastFetched: [String: Date] = [:]
    @Published private var memoizedPullRequests: [PullRequest] = []
    private let invalidationTrigger = PassthroughSubject<Void, Never>()

    private var unreadCache: [String: PullRequestListFilter.UnreadCacheEntry] = [:]
    private var lastProcessedVersions: [String: TimeInterval] = [:]

    private let maxCacheSize = 500

    /// Non-notified PRs fetched within this window are skipped on refresh; they are only
    /// re-fetched once their cached copy is older than this interval.
    private let staleRefreshInterval: TimeInterval = 3 * 60

    private func setupPullRequestsMemoization() {
        // Each emission means the derived list may have changed. Excluded user changes are
        // included so the list re-filters without refetching from GitHub.
        let triggers = Publishers.CombineLatest(
            invalidationTrigger.prepend(()),
            ConfigService.excludedUsersDidChange.prepend(())
        )
        .setFailureType(to: Never.self)

        Publishers.CombineLatest4(
            showClosedSubject,
            showReadSubject,
            $lastUpdated,
            triggers
        )
        .throttle(for: .milliseconds(100), scheduler: DispatchQueue.main, latest: true)
        .map {
            [weak self] showClosed, showRead, _, _ -> AnyPublisher<
                PullRequestListFilter.Output, Never
            > in
            guard let self = self else {
                return Just(
                    PullRequestListFilter.Output(
                        pullRequests: [], hasUnread: false, unreadCache: [:],
                        lastProcessedVersions: [:]
                    )
                ).eraseToAnyPublisher()
            }

            // Snapshot mutable state on the main thread, then filter on a background queue.
            let input = PullRequestListFilter.Input(
                pullRequests: Array(self.pullRequestMap.values),
                readMap: self.pullRequestReadMap,
                viewer: self.viewer,
                excludedUsers: ConfigService.excludedUsersSet,
                showClosed: showClosed,
                showRead: showRead,
                unreadCache: self.unreadCache,
                lastProcessedVersions: self.lastProcessedVersions
            )

            return Future<PullRequestListFilter.Output, Never> { promise in
                DispatchQueue.global(qos: .userInitiated).async {
                    promise(.success(PullRequestListFilter.compute(input)))
                }
            }.eraseToAnyPublisher()
        }
        .switchToLatest()
        .receive(on: DispatchQueue.main)
        .sink { [weak self] output in
            guard let self = self else { return }
            self.unreadCache = output.unreadCache
            self.lastProcessedVersions = output.lastProcessedVersions
            self.memoizedPullRequests = output.pullRequests
            self.hasUnread = output.hasUnread
        }
        .store(in: &cancellables)
    }

    /// Single in-flight refresh shared by all callers (timer, pull-to-refresh, status bar, launch).
    private var refreshTask: Task<Void, Never>?

    func triggerUpdatePullRequests() {
        Task {
            await updatePullRequests()
        }
    }

    func startFetchTimer() {
        if timer != nil {
            return
        }
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.triggerUpdatePullRequests()
        }
    }

    func setRead(_ id: PullRequest.ID, read: Bool) {
        if read {
            let newestEventId = pullRequests.first(where: { $0.id == id })?.events.first?.id
            pullRequestReadMap[id] = ReadData(date: lastUpdated ?? Date(), eventId: newestEventId)
        } else {
            pullRequestReadMap.removeValue(forKey: id)
        }

        // Invalidate cache for this specific PR
        unreadCache.removeValue(forKey: id)
        invalidationTrigger.send()
    }

    func markAllAsRead() {
        let readDate = lastUpdated ?? Date()
        // Mutate a local copy and persist once, instead of encoding the whole map per PR.
        var readMap = pullRequestReadMap
        for pullRequest in pullRequests {
            readMap[pullRequest.id] = ReadData(
                date: readDate, eventId: pullRequest.events.first?.id
            )
        }
        pullRequestReadMap = readMap

        // Clear unread cache as all items are now read
        unreadCache.removeAll()
        invalidationTrigger.send()
    }

    private func handleReceivedNotifications(notifications: [Notification], viewer: Viewer)
        async throws -> Set<String>
    {
        logger.info("Got \(notifications.count) notifications")

        let repoMap = notifications.reduce(into: [String: [Int]]()) { repoMap, notification in
            repoMap[notification.repo, default: []].append(notification.prNumber)
        }

        return try await fetchPullRequestMap(repoMap: repoMap, viewer: viewer)
    }

    private func fetchPullRequestMap(repoMap: [String: [Int]], viewer: Viewer) async throws -> Set<
        String
    > {
        if repoMap.isEmpty {
            logger.info("No new PRs to fetch")
            return []
        }

        let batches = PullRequestsQueryBuilder.chunkRepoMap(repoMap)
        let totalPullRequests = repoMap.values.reduce(0) { $0 + $1.count }

        if batches.count > 1 {
            logger.info(
                "Fetching \(totalPullRequests) pull requests in \(batches.count) GraphQL batches"
            )
        }

        var updatedPullRequestIds = Set<String>()
        updatedPullRequestIds.reserveCapacity(totalPullRequests)

        for batch in batches {
            let pullRequests = try await GitHubService.fetchPullRequests(
                repoMap: batch, viewer: viewer
            )
            logger.info("Got \(pullRequests.count) pull requests")

            updatedPullRequestIds.formUnion(pullRequests.map { $0.id })

            let fetchedAt = Date()
            await MainActor.run {
                for pullRequest in pullRequests {
                    self.pullRequestMap[pullRequest.id] = pullRequest
                    self.pullRequestLastFetched[pullRequest.id] = fetchedAt
                    self.unreadCache.removeValue(forKey: pullRequest.id)
                }
                self.invalidationTrigger.send()
            }
        }

        return updatedPullRequestIds
    }

    func testConnection() async -> Error? {
        do {
            _ = try await GitHubService.fetchViewer()
            logger.info("Connection successful")
            return nil
        } catch {
            logger.info("Connection failed: \(error)")
            return error
        }
    }

    /// Coalesces overlapping refreshes: concurrent callers await the same in-flight refresh
    /// instead of each spawning their own GitHub round-trips.
    ///
    /// Thread safety: `refreshTask` is only accessed here, on the main actor, so there is no data
    /// race on it. Correctness relies on there being **no suspension point (`await`) between the
    /// nil-check and the `refreshTask = task` assignment** — that keeps the check-and-set atomic
    /// against `@MainActor` reentrancy, so two callers can never both start a refresh. Do not
    /// insert an `await` in that span.
    @MainActor
    func updatePullRequests() async {
        if let refreshTask {
            await refreshTask.value
            return
        }

        let task = Task { await self.performUpdatePullRequests() }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    private func performUpdatePullRequests() async {
        do {
            await MainActor.run {
                self.isRefreshing = true
            }

            logger.info("Get current user")
            viewer = try await GitHubService.fetchViewer()

            logger.info("Start fetching notifications")
            let newLastUpdated = Date()
            let since =
                lastUpdated ?? Calendar.current.date(
                    byAdding: .day, value: ConfigService.onStartFetchWeeks * 7 * -1,
                    to: newLastUpdated
                )!
            let updatedPullRequestIds = try await GitHubService.fetchUserNotifications(
                since: since,
                onNotificationsReceived: {
                    try await handleReceivedNotifications(notifications: $0, viewer: viewer!)
                }
            )

            logger.info("Start fetching not updated pull requests")
            let staleThreshold = Date().addingTimeInterval(-staleRefreshInterval)
            let notUpdatedRepoMap = pullRequestMap.values.filter { pullRequest in
                guard !updatedPullRequestIds.contains(pullRequest.id),
                      pullRequest.status != .merged
                else {
                    return false
                }
                // Skip PRs we fetched recently; their cached copy is still fresh enough.
                if let lastFetched = pullRequestLastFetched[pullRequest.id],
                   lastFetched > staleThreshold
                {
                    return false
                }
                return true
            }.reduce(into: [String: [Int]]()) { repoMap, pullRequest in
                repoMap[pullRequest.repository.name, default: []].append(pullRequest.number)
            }
            _ = try await fetchPullRequestMap(repoMap: notUpdatedRepoMap, viewer: viewer!)

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
        let deleteFrom = Calendar.current.date(
            byAdding: .day, value: daysToDeduct * -1, to: Date()
        )!

        var filteredPullRequestMap = pullRequestMap.filter { _, pullRequest in
            pullRequest.lastUpdated > deleteFrom
                || (ConfigService.deleteOnlyClosed && !pullRequest.isClosed)
        }

        // Enforce maximum cache size to prevent unbounded memory growth
        if filteredPullRequestMap.count > maxCacheSize {
            let sortedPRs = filteredPullRequestMap.values.sorted { $0.lastUpdated > $1.lastUpdated }
            let keysToKeep = Set(sortedPRs.prefix(maxCacheSize).map { $0.id })
            filteredPullRequestMap = filteredPullRequestMap.filter { keysToKeep.contains($0.key) }
            // swiftformat:disable redundantSelf
            logger.info("Limiting cache to \(self.maxCacheSize) most recent pull requests")
            // swiftformat:enable redundantSelf
        }

        let filteredPullRequestReadMap = pullRequestReadMap.filter { pullRequestId, _ in
            filteredPullRequestMap.index(forKey: pullRequestId) != nil
        }

        if filteredPullRequestMap.count != pullRequestMap.count
            || filteredPullRequestReadMap.count != pullRequestReadMap.count
        {
            // swiftformat:disable redundantSelf
            logger.info(
                "Removing \(self.pullRequestMap.count - filteredPullRequestMap.count) pull requests"
            )
            logger.info(
                "Removing \(self.pullRequestReadMap.count - filteredPullRequestReadMap.count) pull requests read info"
            )
            // swiftformat:enable redundantSelf
            await MainActor.run { [filteredPullRequestMap, filteredPullRequestReadMap] in
                self.pullRequestMap = filteredPullRequestMap
                self.pullRequestReadMap = filteredPullRequestReadMap
                self.pullRequestLastFetched = self.pullRequestLastFetched.filter {
                    filteredPullRequestMap.index(forKey: $0.key) != nil
                }
                self.invalidationTrigger.send()
            }
        }
    }
}
