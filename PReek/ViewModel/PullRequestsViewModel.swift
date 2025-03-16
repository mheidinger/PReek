import Combine
import OSLog
import SwiftUI

class PullRequestsViewModel: ObservableObject {
    private let logger = Logger()
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?
    private var viewer: Viewer?

    enum SetFocusType {
        case first
        case last
        case next
        case previous
    }

    init(initialPullRequests: [PullRequest] = []) {
        pullRequestMap = Dictionary(uniqueKeysWithValues: initialPullRequests.map { ($0.id, $0) })

        // Directly access UserDefaults w/ same keys above for correct initial values in the subject
        let storedShowClosed = UserDefaults.standard.bool(forKey: "showClosed")
        let storedShowRead = UserDefaults.standard.bool(forKey: "showRead")
        showClosedSubject = CurrentValueSubject<Bool, Never>(storedShowClosed)
        showReadSubject = CurrentValueSubject<Bool, Never>(storedShowRead)
        setupPullRequestsMemoization()
        setupPullRequestFocus()
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

    @Published var lastFocusedPullRequestId: String?
    @Published var focusedPullRequestId: String?
    var pullRequests: [PullRequest] {
        memoizedPullRequests
    }

    @CodableAppStorage("pullRequestReadMap") private var pullRequestReadMap: [String: ReadData] = [:]
    private var pullRequestMap: [String: PullRequest] = [:]
    @Published private var memoizedPullRequests: [PullRequest] = []
    private let invalidationTrigger = PassthroughSubject<Void, Never>()

    private let setFocusTrigger = PassthroughSubject<SetFocusType, Never>()

    private func setupPullRequestsMemoization() {
        // Combine dependencies that affect the pullRequests computation
        // Also add last updated as excluded users are not considered
        Publishers.CombineLatest4(
            showClosedSubject,
            showReadSubject,
            $lastUpdated,
            invalidationTrigger
                .prepend(())
                .setFailureType(to: Never.self)
        )
        .throttle(for: .milliseconds(100), scheduler: DispatchQueue.main, latest: true)
        .map { [weak self] showClosed, showRead, _, _ in
            guard let self = self else { return ([], false) }

            let updatedRead = self.pullRequestMap.map { entry in
                var pullRequest = entry.value
                pullRequest.calculateUnread(viewer: self.viewer, readData: self.pullRequestReadMap[pullRequest.id])
                return pullRequest
            }
            let filtered = updatedRead.filter { pullRequest in
                let containsNonExcludedUser = pullRequest.events.contains { event in
                    !ConfigService.excludedUsers.contains(event.user.login)
                }

                let passesClosedFilter = showClosed || !pullRequest.isClosed
                let passesReadFilter = showRead || pullRequest.unread

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

    func setRead(_ id: String, read: Bool) {
        if read {
            let newestEventId = pullRequests.first(where: { $0.id == id })?.events.first?.id
            pullRequestReadMap[id] = ReadData(date: lastUpdated ?? Date(), eventId: newestEventId)
        } else {
            pullRequestReadMap.removeValue(forKey: id)
        }
        invalidationTrigger.send()
    }

    func markAllAsRead() {
        for pullRequest in pullRequests {
            let newestEventId = pullRequest.events.first?.id
            pullRequestReadMap[pullRequest.id] = ReadData(date: lastUpdated ?? Date(), eventId: newestEventId)
        }
        invalidationTrigger.send()
    }

    private func setupPullRequestFocus() {
        setFocusTrigger
            .throttle(for: .milliseconds(20), scheduler: DispatchQueue.main, latest: true)
            .map { [weak self] type in
                guard let self = self else { return nil }

                switch type {
                case .first:
                    return self.pullRequests.first?.id
                case .last:
                    return self.pullRequests.last?.id
                case .next:
                    return self.getNextFocusIdByOffset(by: 1)
                case .previous:
                    return self.getNextFocusIdByOffset(by: -1)
                }
            }
            .receive(on: DispatchQueue.main)
            .assign(to: \.focusedPullRequestId, on: self)
            .store(in: &cancellables)
    }

    func setFocus(_ type: SetFocusType) {
        setFocusTrigger.send(type)
    }

    private func getNextFocusIdByOffset(by offset: Int) -> String? {
        if pullRequests.count == 0 {
            focusedPullRequestId = nil
            return nil
        }

        let basePullRequestId = lastFocusedPullRequestId ?? focusedPullRequestId

        // Calculate next PR by current focus
        let currentIndex = basePullRequestId.flatMap { focusedId in
            pullRequests.firstIndex { $0.id == focusedId }
        }
        let newIndex = ((currentIndex ?? (offset < 0 ? pullRequests.count : -1)) + offset + pullRequests.count) % pullRequests.count

        return pullRequests[safe: newIndex].map { $0.id }
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

    func updatePullRequests() async {
        do {
            await MainActor.run {
                self.isRefreshing = true
            }

            logger.info("Get current user")
            viewer = try await GitHubService.fetchViewer()

            logger.info("Start fetching notifications")
            let newLastUpdated = Date()
            let since = lastUpdated ?? Calendar.current.date(byAdding: .day, value: ConfigService.onStartFetchWeeks * 7 * -1, to: newLastUpdated)!
            let updatedPullRequestIds = try await GitHubService.fetchUserNotifications(since: since, onNotificationsReceived: { try await handleReceivedNotifications(notifications: $0, viewer: viewer!) })

            logger.info("Start fetching not updated pull requests")
            let notUpdatedRepoMap = pullRequestMap.values.filter { pullRequest in
                !updatedPullRequestIds.contains(pullRequest.id) && pullRequest.status != .merged
            }.reduce([String: [Int]]()) { repoMap, pullRequest in
                var repoMapClone = repoMap

                let existingPRs = repoMap[pullRequest.repository.name]
                repoMapClone[pullRequest.repository.name] = (existingPRs ?? []) + [pullRequest.number]

                return repoMapClone
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
