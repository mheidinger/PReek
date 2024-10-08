import SwiftUI

struct PullRequestsView: View {
    var pullRequests: [PullRequest]
    var setRead: (String, Bool) -> Void
    @Binding var toBeFocusedPullRequestId: String?
    @Binding var lastFocusedPullRequestId: String?

    @FocusState var focusedPullRequestId: String?

    init(_ pullRequests: [PullRequest], setRead: @escaping (String, Bool) -> Void, toBeFocusedPullRequestId: Binding<String?>, lastFocusedPullRequestId: Binding<String?>) {
        self.pullRequests = pullRequests
        self.setRead = setRead
        _toBeFocusedPullRequestId = toBeFocusedPullRequestId
        _lastFocusedPullRequestId = lastFocusedPullRequestId
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        DividedView(pullRequests) { pullRequest in
                            PullRequestView(
                                pullRequest,
                                setRead: setRead
                            )
                            .focused($focusedPullRequestId, equals: pullRequest.id)
                        }
                        // full width - horizontal padding from PullRequestView excl. focus border width
                        .frame(width: geometry.size.width - 23)
                    }
                    .padding(.leading, 3)
                    .padding(.vertical, 5)
                }
                .onChange(of: toBeFocusedPullRequestId) { _, newValue in
                    if let id = newValue {
                        withAnimation {
                            proxy.scrollTo(id)
                        } completion: {
                            focusedPullRequestId = id
                        }
                    }
                }
                .onChange(of: focusedPullRequestId) { _, newValue in
                    if let id = newValue {
                        lastFocusedPullRequestId = id
                    }
                }
            }
        }
    }
}

#Preview {
    PullRequestsView(
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
        toBeFocusedPullRequestId: .constant(""),
        lastFocusedPullRequestId: .constant("")
    )
}
