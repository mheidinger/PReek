import SwiftUI
import MarkdownUI

func eventDataToActionLabel(data: any PullRequestEventData) -> String {
    let reviewLabels = [
        PullRequestEventReviewData.State.approve: "approved",
        PullRequestEventReviewData.State.changesRequested: "requested changes",
        PullRequestEventReviewData.State.comment: "commented",
        PullRequestEventReviewData.State.dismissed: "reviewed (dismissed)"
    ]
    
    switch data {
    case is PullRequestEventClosedData:
        return "closed"
    case let pushedData as PullRequestEventPushedData:
        return pushedData.isForcePush ? "force pushed" : "pushed"
    case is PullRequestEventMergedData:
        return "merged"
    case let reviewData as PullRequestEventReviewData:
        return reviewLabels[reviewData.state] ?? "reviewed"
    case is PullRequestEventCommentData:
        return "commented"
    case is PullRequestEventReadyForReviewData:
        return "marked ready"
    case is PullRequestEventRenamedTitleData:
        return "renamed"
    case is PullRequestEventReopenedData:
        return "reopened"
    case is PullRequestEventReviewRequestedData:
        return "requested review"
    default:
        return "unknown"
    }
}

struct PullRequestEventView: View {
    var pullRequestEvent: PullRequestEvent
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(pullRequestEvent.user.displayName).frame(width: 200, alignment: .leading)
                Spacer()
                Text(eventDataToActionLabel(data: pullRequestEvent.data)).frame(width: 150, alignment: .trailing)
                Spacer()
                Text(pullRequestEvent.time.formatted(date: .numeric, time: .shortened))
                    .foregroundStyle(.secondary)
                ModifierLink(destination: pullRequestEvent.url) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            PullRequestEventDataView(data: pullRequestEvent.data)
                .padding(.leading, 30)
                .padding(.top, 2)
        }
        .padding(.trailing)
    }
}

#Preview {
    let pullRequestEvents: [PullRequestEvent] = [
        PullRequestEvent.previewClosed,
        PullRequestEvent.previewCommit(),
        PullRequestEvent.previewCommit(commits: [
            Commit(id: "1", messageHeadline: "my first commit!", url: URL(string: "https://example.com")!),
        ]),
        PullRequestEvent.previewCommit(commits: [
            Commit(id: "1", messageHeadline: "my first commit!", url: URL(string: "https://example.com")!),
            Commit(id: "2", messageHeadline: "my second commit!", url: URL(string: "https://example.com")!),
            Commit(id: "3", messageHeadline: "my third commit!", url: URL(string: "https://example.com")!)
        ]),
        PullRequestEvent.previewMerged,
        PullRequestEvent.previewReview(),
        PullRequestEvent.previewComment,
        PullRequestEvent.previewReopened,
        PullRequestEvent.previewForcePushed,
        PullRequestEvent.previewRenamedTitle,
        PullRequestEvent.previewReviewRequested,
        PullRequestEvent.previewReadyForReview,
    ]
    
    return ScrollView {
        VStack {
            DividedView {
                ForEach(pullRequestEvents) { pullRequestEvent in
                    PullRequestEventView(pullRequestEvent: pullRequestEvent)
                }
            }
        }
        .padding()
    }
}
