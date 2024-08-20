import SwiftUI
import MarkdownUI

func eventDataToActionLabel(data: any PullRequestEventData) -> String {
    let reviewLabels = [
        PullRequestEventReviewData.State.approve: String(localized: "approved"),
        PullRequestEventReviewData.State.changesRequested: String(localized: "requested changes"),
        PullRequestEventReviewData.State.comment: String(localized: "commented"),
        PullRequestEventReviewData.State.dismissed: String(localized: "reviewed (dismissed)")
    ]
    
    switch data {
    case is PullRequestEventClosedData:
        return String(localized: "closed")
    case let pushedData as PullRequestEventPushedData:
        return pushedData.isForcePush ? String(localized: "force pushed") : String(localized: "pushed")
    case is PullRequestEventMergedData:
        return String(localized: "merged")
    case let reviewData as PullRequestEventReviewData:
        return reviewLabels[reviewData.state] ?? String(localized: "reviewed")
    case is PullRequestEventCommentData:
        return String(localized: "commented")
    case is PullRequestEventReadyForReviewData:
        return String(localized: "marked ready")
    case is PullRequestEventRenamedTitleData:
        return String(localized: "renamed")
    case is PullRequestEventReopenedData:
        return String(localized: "reopened")
    case is PullRequestEventReviewRequestedData:
        return String(localized: "requested review")
    case is PullRequestEventConvertToDraftData:
        return String(localized: "converted to draft")
    default:
        return String(localized: "unknown")
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
        PullRequestEvent.previewConvertToDraft
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
