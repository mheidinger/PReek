import SwiftUI

struct PullRequestDisclosureGroup: View, Equatable {
    var pullRequest: PullRequest
    var setRead: (PullRequest.ID, Bool) -> Void

    @State var sectionExpanded: Bool = false

    init(_ pullRequest: PullRequest, setRead: @escaping (PullRequest.ID, Bool) -> Void, sectionExpanded: Bool = false) {
        self.pullRequest = pullRequest
        self.setRead = setRead
        self.sectionExpanded = sectionExpanded
    }

    static func == (lhs: PullRequestDisclosureGroup, rhs: PullRequestDisclosureGroup) -> Bool {
        lhs.pullRequest.id == rhs.pullRequest.id &&
            lhs.pullRequest.unread == rhs.pullRequest.unread &&
            lhs.pullRequest.title == rhs.pullRequest.title &&
            lhs.pullRequest.lastUpdated == rhs.pullRequest.lastUpdated &&
            lhs.pullRequest.status == rhs.pullRequest.status
    }

    var body: some View {
        VStack {
            DisclosureGroup(isExpanded: $sectionExpanded) {
                // Only create content view when expanded
                if sectionExpanded {
                    PullRequestContentView(pullRequest)
                        .equatable()
                }
            } label: {
                PullRequestHeaderView(pullRequest, setRead: setRead)
                    .equatable()
                    .padding(.leading, 10)
                    .padding(.trailing, 5)
            }
        }
        .padding(.leading, 10)
        .onDisappear {
            sectionExpanded = false
        }
    }
}

#Preview {
    ScrollView {
        PullRequestDisclosureGroup(
            PullRequest.preview(title: "long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long lon"),
            setRead: { _, _ in },
            sectionExpanded: true
        )
    }
    .padding()
}
