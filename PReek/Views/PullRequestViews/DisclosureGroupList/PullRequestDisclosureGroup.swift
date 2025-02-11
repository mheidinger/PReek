import SwiftUI

struct PullRequestDisclosureGroup: View {
    var pullRequest: PullRequest
    var setRead: (String, Bool) -> Void

    @State var sectionExpanded: Bool = false

    init(_ pullRequest: PullRequest, setRead: @escaping (String, Bool) -> Void, sectionExpanded: Bool = false) {
        self.pullRequest = pullRequest
        self.setRead = setRead
        self.sectionExpanded = sectionExpanded
    }

    var body: some View {
        VStack {
            DisclosureGroup(isExpanded: $sectionExpanded) {
                PullRequestContentView(pullRequest)
            } label: {
                PullRequestHeaderView(pullRequest, setRead: setRead)
                    .padding(.leading, 10)
                    .padding(.trailing, 5)
            }
        }
        .padding(.leading, 20)
        .contentShape(Rectangle())
        .focusable()
        .onKeyPress(.space) {
            sectionExpanded = !sectionExpanded
            return .handled
        }
        .onDisappear {
            sectionExpanded = false
        }
        .id(pullRequest.id)
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
