import SwiftUI

struct PullRequestsList<Footer: View>: View {
    @ObservedObject var pullRequestsViewModel: PullRequestsViewModel
    @ViewBuilder let footer: () -> Footer

    var pullRequests: [PullRequest] {
        pullRequestsViewModel.pullRequests
    }

    @State private var selectedPullRequestId: PullRequest.ID?
    @State private var showFilterSheet: Bool = false
    @State private var showMarkAllAsReadConfirm: Bool = false
    @State private var setUnreadOnChange: Bool = false

    init(pullRequestsViewModel: PullRequestsViewModel, @ViewBuilder footer: @escaping () -> Footer) {
        self.pullRequestsViewModel = pullRequestsViewModel
        self.footer = footer
    }

    private var selectedPullRequest: PullRequest? {
        guard let selectedPullRequestId else { return nil }
        return pullRequests.first(where: { $0.id == selectedPullRequestId })
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedPullRequestId) {
                Section {
                    ForEach(pullRequests) { pullRequest in
                        PullRequestListItem(pullRequest)
                            .contextMenu {
                                Button(pullRequest.unread ? "Mark read" : "Mark unread", action: { pullRequestsViewModel.setRead(pullRequest.id, read: pullRequest.unread) })
                            }
                    }
                } footer: {
                    footer()
                }
            }
            .refreshable {
                pullRequestsViewModel.triggerUpdatePullRequests()
            }
            .onChange(of: selectedPullRequestId) { oldValue, _ in
                guard let oldValue else { return }

                if setUnreadOnChange {
                    pullRequestsViewModel.setRead(oldValue, read: false)
                    setUnreadOnChange = false
                } else {
                    pullRequestsViewModel.setRead(oldValue, read: true)
                }
            }
            .toolbar {
                Button(action: { showFilterSheet = true }) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title)
                }

                Button(action: { showMarkAllAsReadConfirm = true }) {
                    Image(systemName: "eye.circle")
                        .font(.title)
                }
                .confirmationDialog("Are you sure?", isPresented: $showMarkAllAsReadConfirm) {
                    Button("Mark all as read") {
                        pullRequestsViewModel.markAllAsRead()
                    }
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                NavigationStack {
                    Form {
                        Toggle(isOn: $pullRequestsViewModel.showClosed) {
                            Text("Show closed")
                        }
                        Toggle(isOn: $pullRequestsViewModel.showRead) {
                            Text("Show read")
                        }
                    }
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .navigationTitle("Filters")
                    .toolbar {
                        Button(action: { showFilterSheet = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .imageScale(.large)
                        }
                    }
                }
                .presentationDetents([.fraction(0.3)])
            }
        } detail: {
            if let selectedPullRequest {
                PullRequestDetailView(selectedPullRequest, setRead: pullRequestsViewModel.setRead, setUnreadOnChange: $setUnreadOnChange)
            } else {
                Text("Select a pull request")
            }
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
    return PullRequestsList(pullRequestsViewModel: pullRequestsViewModel, footer: { Text("Footer") })
}
