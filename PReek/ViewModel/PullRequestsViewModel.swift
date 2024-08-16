import SwiftUI

class PullRequestsViewModel: ObservableObject {
    @Published var lastUpdated: Date? = nil
    @Published var isRefreshing = false
    @Published var error: Error? = nil
    
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
        return pullRequestMap.map { entry in
            var pullRequest = entry.value
            pullRequest.markedAsRead = isRead(pullRequest)
            return pullRequest
        }.filter { pullRequest in
            let containsNonExcludedUser = pullRequest.events.contains { event in
                return !ConfigService.excludedUsers.contains(event.user.login)
            }
            
            let passesClosedFilter = !hideClosed || !pullRequest.isClosed
            let passesReadFilter = !hideRead || !pullRequest.markedAsRead
            
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
        if isRead(pullRequest) {
            pullRequestReadMap.removeValue(forKey: pullRequest.id)
        } else {
            pullRequestReadMap[pullRequest.id] = Date()
        }
        updateHasUnread()
        objectWillChange.send()
    }
    
    func markAllAsRead() {
        let now = Date()
        pullRequests.forEach { pullRequest in
            pullRequestReadMap[pullRequest.id] = now
        }
        updateHasUnread()
        objectWillChange.send()
    }
    
    private func isRead(_ pullRequest: PullRequest) -> Bool {
        guard let markedRead = pullRequestReadMap[pullRequest.id] else {
            return false
        }
        return markedRead > pullRequest.lastNonViewerUpdated
    }
    
    private func updateHasUnread() {
        hasUnread = pullRequests.first { pullRequest in !pullRequest.markedAsRead } != nil
    }
    
    private func handleReceivedNotifications(notifications: [Notification]) async throws -> [String] {
        print("Got \(notifications.count) notifications")
        
        let repoMap = notifications.reduce([String: [Int]]()) { repoMap, notification in
            var repoMapClone = repoMap
            
            let existingPRs = repoMap[notification.repo]
            repoMapClone[notification.repo] = (existingPRs ?? []) + [notification.prNumber]
            
            return repoMapClone
        }
        
        return try await fetchPullRequestMap(repoMap: repoMap)
    }
    
    private func fetchPullRequestMap(repoMap: [String: [Int]]) async throws -> [String] {
        if !repoMap.isEmpty {
            let pullRequests = try await GitHubService.fetchPullRequests(repoMap: repoMap)
            print("Got \(pullRequests.count) pull requests")
            
            DispatchQueue.main.async {
                pullRequests.forEach { pullRequest in
                    self.pullRequestMap[pullRequest.id] = pullRequest
                }
            }
            return pullRequests.map { $0.id }
        } else {
            print("No new PRs to fetch")
        }
        return []
    }
    
    func updatePullRequests() async {
        do {
            print("Start fetching notifications")
            
            DispatchQueue.main.async {
                self.isRefreshing = true
                self.error = nil
            }
            
            let since = lastUpdated ?? Calendar.current.date(byAdding: .day, value: ConfigService.onStartFetchWeeks * 7 * -1, to: Date())!
            let updatedPullRequestIds = try await GitHubService.fetchUserNotifications(since: since, onNotificationsReceived: handleReceivedNotifications)
            
            print("Start fetching not updated pull requests")
            let notUpdatedRepoMap = pullRequestMap.values.filter { pullRequest in
                !updatedPullRequestIds.contains(pullRequest.id)
            }.reduce([String: [Int]]()) { repoMap, pullRequest in
                var repoMapClone = repoMap
                
                let existingPRs = repoMap[pullRequest.repository.name]
                repoMapClone[pullRequest.repository.name] = (existingPRs ?? []) + [pullRequest.number]
                
                return repoMapClone
            }
            _ = try await fetchPullRequestMap(repoMap: notUpdatedRepoMap)
            
            cleanupPullRequests()
            
            DispatchQueue.main.async {
                self.updateHasUnread()
                self.lastUpdated = Date()
                self.isRefreshing = false
            }
            print("Finished fetching notifications")
        } catch {
            print("Failed to get pull requests: \(error)")
            DispatchQueue.main.async {
                self.isRefreshing = false
                self.error = error
            }
        }
    }
    
    private func cleanupPullRequests() {
        let deleteFrom = Calendar.current.date(byAdding: .day, value: ConfigService.deleteAfterWeeks * 7 * -1, to: Date())!

        let filteredPullRequestMap = pullRequestMap.filter { _, pullRequest in
            pullRequest.lastUpdated > deleteFrom || (ConfigService.deleteOnlyClosed && !pullRequest.isClosed)
        }
        
        let filteredPullRequestReadMap = pullRequestReadMap.filter { pullRequestId, _ in
            filteredPullRequestMap.index(forKey: pullRequestId) != nil
        }
        
        if filteredPullRequestMap.count != pullRequestMap.count || filteredPullRequestReadMap.count != pullRequestReadMap.count {
            print("Removing \(pullRequestMap.count - filteredPullRequestMap.count) pull requests")
            print("Removing \(pullRequestReadMap.count - filteredPullRequestReadMap.count) pull requests read info")
            DispatchQueue.main.async {
                self.pullRequestMap = filteredPullRequestMap
                self.pullRequestReadMap = filteredPullRequestReadMap
            }
        }
    }
}
