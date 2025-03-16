import SwiftUI

private let statusToIcon: [PullRequest.Status: ImageResource] = [
    PullRequest.Status.draft: .prDraft,
    PullRequest.Status.open: .prOpen,
    PullRequest.Status.merged: .prMerged,
    PullRequest.Status.closed: .prClosed,
]

struct StatusIcon: View {
    var status: PullRequest.Status

    init(_ status: PullRequest.Status) {
        self.status = status
    }

    var body: some View {
        Image(statusToIcon[status] ?? .prOpen)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 32, height: 32)
    }
}

#Preview {
    VStack {
        StatusIcon(.draft)
        StatusIcon(.open)
        StatusIcon(.merged)
        StatusIcon(.closed)
    }
}
