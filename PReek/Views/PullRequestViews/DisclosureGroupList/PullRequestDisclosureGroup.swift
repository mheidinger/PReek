import SwiftUI

struct PullRequestDisclosureGroup: View {
    var pullRequest: PullRequest
    var setRead: (PullRequest.ID, Bool) -> Void

    @State var sectionExpanded: Bool = false

    init(_ pullRequest: PullRequest, setRead: @escaping (PullRequest.ID, Bool) -> Void, sectionExpanded: Bool = false) {
        self.pullRequest = pullRequest
        self.setRead = setRead
        self.sectionExpanded = sectionExpanded
    }

    var body: some View {
        VStack {
            DisclosureGroup(isExpanded: $sectionExpanded) {
                // Only create content view when expanded
                if sectionExpanded {
                    PullRequestContentView(pullRequest)
                }
            } label: {
                PullRequestHeaderView(pullRequest, setRead: setRead)
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
