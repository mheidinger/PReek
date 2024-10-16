import SwiftUI

struct PullRequestsView: View {
    @ObservedObject var viewModel: PullRequestsViewModel
    @StateObject private var keyboardHandler = PullRequestsNavigationShortcutHandler()

    @FocusState var focusedPullRequestId: String?

    init(viewModel: PullRequestsViewModel) {
        self.viewModel = viewModel
        keyboardHandler.viewModel = viewModel
    }

    private var pullRequests: [PullRequest] { viewModel.pullRequests }

    private func toScrollId(_ id: String) -> String {
        "scroll-\(id)"
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        DividedView {
                            ForEach(pullRequests) { pullRequest in
                                PullRequestView(
                                    pullRequest,
                                    toggleRead: { viewModel.toggleRead(pullRequest) },
                                    scrollId: toScrollId(pullRequest.id)
                                )
                                .focused($focusedPullRequestId, equals: pullRequest.id)
                            }
                        }
                        // full width - horizontal padding from PullRequestView excl. focus border width
                        .frame(width: geometry.size.width - 23)
                    }
                    .padding(.leading, 3)
                    .padding(.vertical, 5)
                }
                .onChange(of: viewModel.focusedPullRequestId) { _, newValue in
                    if let id = newValue {
                        withAnimation {
                            proxy.scrollTo(toScrollId(id))
                            focusedPullRequestId = id
                        }
                    }
                }
                .onChange(of: focusedPullRequestId) { _, newValue in
                    if let id = newValue, viewModel.focusedPullRequestId != id {
                        viewModel.focusedPullRequestId = id
                    }
                }
            }
        }
    }
}

#Preview {
    @ObservedObject var pullRequestViewModel = PullRequestsViewModel(initialPullRequests: [
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
    ])
    return PullRequestsView(viewModel: pullRequestViewModel)
}
