import SwiftUI

struct MainScreen: View {
    @ObservedObject var pullRequestsViewModel: PullRequestsViewModel
    @ObservedObject var configViewModel: ConfigViewModel

    @ViewBuilder
    var content: some View {
        if !pullRequestsViewModel.pullRequests.isEmpty {
            PullRequestsDisclosureGroupList(
                pullRequestsViewModel.pullRequests,
                setRead: pullRequestsViewModel.setRead,
                toBeFocusedPullRequestId: $pullRequestsViewModel.focusedPullRequestId,
                lastFocusedPullRequestId: $pullRequestsViewModel.lastFocusedPullRequestId
            )
        } else if pullRequestsViewModel.error != nil {
            Image(systemName: "icloud.slash")
                .font(.largeTitle)
        } else if pullRequestsViewModel.isRefreshing {
            ProgressView()
        } else {
            Text("You are done for today! 🎉")
                .font(.title2)
        }
    }

    var body: some View {
        VStack {
            content
                .frame(maxHeight: .infinity, alignment: .center)

            StatusBarView(pullRequestsViewModel: pullRequestsViewModel)
                .background(.background.opacity(0.7))
        }
        #if os(macOS)
        .background(.background.opacity(0.5))
        #else
        .background(.windowBackground)
        #endif
    }
}

#Preview {
    @ObservedObject var pullRequestViewModel = PullRequestsViewModel(initialPullRequests: [
        PullRequest.preview(id: "1", title: "short"),
        PullRequest.preview(id: "2", title: "long long long long long long long long long long long long long long long long long long long"),
        PullRequest.preview(id: "3", lastUpdated: Calendar.current.date(byAdding: .day, value: -1, to: Date())!),
        PullRequest.preview(id: "4", lastUpdated: Calendar.current.date(byAdding: .day, value: -3, to: Date())!),
        PullRequest.preview(id: "5"),
    ])
    return ContentView(pullRequestsViewModel: pullRequestViewModel, configViewModel: ConfigViewModel(), closeWindow: {})
}
