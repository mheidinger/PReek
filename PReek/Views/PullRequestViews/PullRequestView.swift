import SwiftUI

struct PullRequestView: View {
    var pullRequest: PullRequest
    var toggleRead: () -> Void

    @State var sectionExpanded: Bool

    init(_ pullRequest: PullRequest, toggleRead: @escaping () -> Void, sectionExpanded: Bool = false) {
        self.pullRequest = pullRequest
        self.toggleRead = toggleRead
        self.sectionExpanded = sectionExpanded
    }

    var body: some View {
        VStack {
            DisclosureGroup(isExpanded: $sectionExpanded) {
                PullRequestContentView(pullRequest)
            } label: {
                PullRequestHeaderView(pullRequest, toggleRead: toggleRead)
            }
        }
        .onDisappear {
            sectionExpanded = false
        }
    }
}

#Preview {
    ScrollView {
        PullRequestView(
            PullRequest.preview(),
            toggleRead: {},
            sectionExpanded: true
        )
    }
    .padding()
}
