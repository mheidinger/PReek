import SwiftUI

struct PullRequestsDisclosureGroupList: View {
    var pullRequests: [PullRequest]
    var setRead: (PullRequest.ID, Bool) -> Void

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    DividedView(pullRequests) { pullRequest in
                        PullRequestDisclosureGroup(
                            pullRequest,
                            setRead: setRead
                        )
                    }
                }
                .padding(.leading, 3)
                .padding(.vertical, 5)
            }
        }
    }
}

#Preview {
    PullRequestsDisclosureGroupList(
        pullRequests: [
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
        setRead: { _, _ in }
    )
}
