import SwiftUI

struct MainScreen: View {
    @ObservedObject var pullRequestsViewModel: PullRequestsViewModel
    @ObservedObject var configViewModel: ConfigViewModel

    var body: some View {
        #if os(macOS)
            VStack {
                content
                    .frame(maxHeight: .infinity, alignment: .center)

                StatusBarView(pullRequestsViewModel: pullRequestsViewModel)
                    .background(.background.opacity(0.7))
            }
            .background(.background.opacity(0.5))
        #else
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.systemGroupedBackground)
        #endif
    }

    @ViewBuilder
    var content: some View {
        if !pullRequestsViewModel.pullRequests.isEmpty {
            #if os(macOS)
                PullRequestsDisclosureGroupList(
                    pullRequestsViewModel.pullRequests,
                    setRead: pullRequestsViewModel.setRead,
                    toBeFocusedPullRequestId: $pullRequestsViewModel.focusedPullRequestId,
                    lastFocusedPullRequestId: $pullRequestsViewModel.lastFocusedPullRequestId
                )
            #else
                PullRequestsList(pullRequestsViewModel: pullRequestsViewModel, footer: {
                    HStack {
                        Spacer()
                        Text("Last updated at \(pullRequestsViewModel.lastUpdated?.formatted(date: .omitted, time: .shortened) ?? "...")")
                        Spacer()
                    }
                })
            #endif
        } else if pullRequestsViewModel.error != nil {
            VStack {
                Image(systemName: "icloud.slash")
                    .font(.largeTitle)
                Text("No Connection")
                    .foregroundStyle(.secondary)
            }
        } else if pullRequestsViewModel.isRefreshing {
            VStack {
                ProgressView()
                Text("Loading Pull Requests...")
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("You are done for today! 🎉")
                .font(.title2)
        }
    }
}

#Preview {
    @ObservedObject var pullRequestsViewModel = PullRequestsViewModel(initialPullRequests: [
        PullRequest.preview(id: "1", title: "short"),
        PullRequest.preview(id: "2", title: "long long long long long long long long long long long long long long long long long long long"),
        PullRequest.preview(id: "3", lastUpdated: Calendar.current.date(byAdding: .day, value: -1, to: Date())!),
        PullRequest.preview(id: "4", lastUpdated: Calendar.current.date(byAdding: .day, value: -3, to: Date())!),
        PullRequest.preview(id: "5"),
    ])
    return MainScreen(pullRequestsViewModel: pullRequestsViewModel, configViewModel: ConfigViewModel())
}
