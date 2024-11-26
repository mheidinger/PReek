import SwiftUI

struct MainScreen: View {
    @ObservedObject var pullRequestsViewModel: PullRequestsViewModel
    @ObservedObject var configViewModel: ConfigViewModel

    @ViewBuilder
    var content: some View {
        if !pullRequestsViewModel.pullRequests.isEmpty {
            PullRequestsView(
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
        .background(.background.opacity(0.5))
    }
}
