import SwiftUI

struct MainScreen: View {
    @ObservedObject var pullRequestsViewModel: PullRequestsViewModel

    var body: some View {
        #if os(macOS)
            VStack {
                content
                    .frame(maxHeight: .infinity, alignment: .center)

                StatusBarView(pullRequestsViewModel: pullRequestsViewModel)
                    .background(.background.opacity(0.7))
            }
        #else
            PullRequestsList(pullRequestsViewModel: pullRequestsViewModel) {
                if let lastUpdated = pullRequestsViewModel.lastUpdated {
                    Text("Last updated at \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                        .frame(maxWidth: .infinity)
                }
            }
        #endif
    }

    #if os(macOS)
        @ViewBuilder
        var content: some View {
            if !pullRequestsViewModel.pullRequests.isEmpty {
                PullRequestsDisclosureGroupList(
                    pullRequests: pullRequestsViewModel.pullRequests,
                    setRead: pullRequestsViewModel.setRead,
                    viewerLogin: pullRequestsViewModel.viewer?.login
                )
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
    #endif
}

#Preview {
    @ObservedObject var pullRequestsViewModel = PullRequestsViewModel(initialPullRequests: [
        PullRequest.preview(id: "1", title: "short"),
        PullRequest.preview(id: "2", title: "long long long long long long long long long long long long long long long long long long long"),
        PullRequest.preview(id: "3", lastUpdated: Calendar.current.date(byAdding: .day, value: -1, to: Date())!),
        PullRequest.preview(id: "4", lastUpdated: Calendar.current.date(byAdding: .day, value: -3, to: Date())!),
        PullRequest.preview(id: "5"),
    ])
    return MainScreen(pullRequestsViewModel: pullRequestsViewModel)
        .environmentObject(ConfigViewModel())
}
