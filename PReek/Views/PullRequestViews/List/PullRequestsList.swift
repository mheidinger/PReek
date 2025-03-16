import SwiftUI

struct PullRequestsList<Footer: View>: View {
    var pullRequests: [PullRequest]
    var setRead: (String, Bool) -> Void

    let footer: () -> Footer

    @State private var selectedPullRequestId: String?

    init(_ pullRequests: [PullRequest], setRead: @escaping (String, Bool) -> Void, @ViewBuilder footer: @escaping () -> Footer) {
        self.pullRequests = pullRequests
        self.setRead = setRead
        self.footer = footer
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedPullRequestId) {
                Section {
                    ForEach(pullRequests) { pullRequest in
                        PullRequestListItem(pullRequest)
                            .contextMenu {
                                Button(pullRequest.unread ? "Mark read" : "Mark unread", action: { setRead(pullRequest.id, pullRequest.unread) })
                            }
                    }
                } footer: {
                    footer()
                }
            }
        } detail: {
            if let selectedId = selectedPullRequestId,
               let selectedPullRequest = pullRequests.first(where: { $0.id == selectedId })
            {
                PullRequestDetailView(selectedPullRequest, setRead: setRead)
            } else {
                Text("Select a pull request")
            }
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
        ],
        setRead: { _, _ in },
        footer: { Text("Footer") }
    )
}
