import SwiftUI

struct PullRequestView: View {
    var pullRequest: PullRequest
    var toggleRead: () -> Void

    @State var sectionExpanded: Bool = false

    var body: some View {
        VStack {
            DisclosureGroup(isExpanded: $sectionExpanded) {
                PullRequestContentView(pullRequest: pullRequest)
            } label: {
                PullRequestHeaderView(pullRequest: pullRequest, toggleRead: toggleRead)
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
            pullRequest: PullRequest.preview(),
            toggleRead: {},
            sectionExpanded: true
        )
    }
    .padding()
}
