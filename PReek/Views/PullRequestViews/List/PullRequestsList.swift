import SwiftUI

struct PullRequestsList: View {
    var pullRequests: [PullRequest]

    @State private var selectedPullRequestId: String?

    init(_ pullRequests: [PullRequest]) {
        self.pullRequests = pullRequests
    }

    var body: some View {
        NavigationSplitView {
            List(pullRequests, selection: $selectedPullRequestId) { pullRequest in
                PullRequestListItem(pullRequest)
            }
        } detail: {
            Text(selectedPullRequestId ?? "unknown")
        }
    }
}

#Preview {
    PullRequestsList(
        [
            PullRequest.preview(id: "1", title: "short"),
            PullRequest.preview(id: "2", title: "long long long long long long long long long long long long long long long long long long long"),
            PullRequest.preview(id: "3", lastUpdated: Calendar.current.date(byAdding: .day, value: -1, to: Date())!),
            PullRequest.preview(id: "4", lastUpdated: Calendar.current.date(byAdding: .day, value: -3, to: Date())!),
            PullRequest.preview(id: "5"),
            PullRequest.preview(id: "6"),
            PullRequest.preview(id: "7"),
            PullRequest.preview(id: "8"),
            PullRequest.preview(id: "9"),
            PullRequest.preview(id: "10"),
            PullRequest.preview(id: "11"),
            PullRequest.preview(id: "12"),
            PullRequest.preview(id: "13"),
            PullRequest.preview(id: "14"),
            PullRequest.preview(id: "15"),
            PullRequest.preview(id: "16"),
            PullRequest.preview(id: "17"),
            PullRequest.preview(id: "18"),
        ]
    )
}
