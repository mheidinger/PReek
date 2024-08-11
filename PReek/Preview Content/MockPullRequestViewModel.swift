import Foundation

class MockPullRequestsViewModel: PullRequestsViewModelProtocol {
    @Published var lastUpdated: Date? = Date()
    @Published var isRefreshing = false
    @Published var hasError = false
    @Published var hideClosed = false
    @Published var hideRead = false
    
    var pullRequests: [PullRequest] = [
        PullRequest.preview()
    ]
    
    func triggerFetchPullRequests() {
        // Simulate fetching
        isRefreshing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.isRefreshing = false
        }
    }
    
    func startFetchTimer() {
        // No-op for mock
    }
    
    func toggleRead(_ pullRequest: PullRequest) {
        if let index = pullRequests.firstIndex(where: { $0.id == pullRequest.id }) {
            pullRequests[index].markedAsRead.toggle()
        }
    }
    
    func markAllAsRead() {
        pullRequests = pullRequests.map { pr in
            var updatedPR = pr
            updatedPR.markedAsRead = true
            return updatedPR
        }
    }
}
