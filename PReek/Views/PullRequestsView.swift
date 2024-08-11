import SwiftUI

struct PullRequestsView: View {
    var pullRequests: [PullRequest]
    var toggleRead: (PullRequest) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                DividedView {
                    ForEach(pullRequests) { pullRequest in
                        PullRequestView(pullRequest: pullRequest, toggleRead: { toggleRead(pullRequest) })
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 0)
        }
    }
}

#Preview {
    PullRequestsView(pullRequests: [
        PullRequest.preview(title: "short"),
        PullRequest.preview(title: "long long long long long long long long long long long long long long long long long long"),
        PullRequest.preview(lastUpdated: Calendar.current.date(byAdding: .day, value: -1, to: Date())!),
        PullRequest.preview(lastUpdated: Calendar.current.date(byAdding: .day, value: -3, to: Date())!),
        PullRequest.preview(),
        PullRequest.preview(),
        PullRequest.preview(),
        PullRequest.preview(),
        PullRequest.preview(),
        PullRequest.preview(),
        PullRequest.preview(),
        PullRequest.preview(),
        PullRequest.preview(),
        PullRequest.preview(),
        PullRequest.preview(),
        PullRequest.preview(),
        PullRequest.preview(),
        PullRequest.preview()
    ], toggleRead: {_ in })
}
