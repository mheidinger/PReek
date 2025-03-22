import SwiftUI

private let statusToImageResource: [PullRequest.Status: ImageResource] = [
    PullRequest.Status.draft: .prDraft,
    PullRequest.Status.open: .prOpen,
    PullRequest.Status.merged: .prMerged,
    PullRequest.Status.closed: .prClosed,
]

private let statusToText: [PullRequest.Status: String] = [
    PullRequest.Status.draft: String(localized: "Draft"),
    PullRequest.Status.open: String(localized: "Open"),
    PullRequest.Status.merged: String(localized: "Merged"),
    PullRequest.Status.closed: String(localized: "Closed"),
]

private let statusToColor: [PullRequest.Status: Color] = [
    PullRequest.Status.draft: .gray,
    PullRequest.Status.open: .green,
    PullRequest.Status.merged: .purple,
    PullRequest.Status.closed: .red,
]

struct StatusIcon: View {
    var status: PullRequest.Status

    init(_ status: PullRequest.Status) {
        self.status = status
    }

    var body: some View {
        Image(statusToImageResource[status] ?? .prOpen)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 32, height: 32)
    }
}

struct StatusLabel: View {
    var status: PullRequest.Status

    init(_ status: PullRequest.Status) {
        self.status = status
    }
    
    var color: Color {
        return statusToColor[status] ?? .green
    }

    var body: some View {
        Label(statusToText[status] ?? "Unknown", image: statusToImageResource[status] ?? .prOpen)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(12)

    }
}

#Preview {
    VStack {
        StatusIcon(.draft)
        StatusIcon(.open)
        StatusIcon(.merged)
        StatusIcon(.closed)
        Divider()
        StatusLabel(.draft)
        StatusLabel(.open)
        StatusLabel(.merged)
        StatusLabel(.closed)
    }
}
