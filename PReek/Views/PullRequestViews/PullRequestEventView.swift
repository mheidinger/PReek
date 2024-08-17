import SwiftUI
import MarkdownUI

struct PullRequestEventDataView: View {
    var data: any PullRequestEventData
    
    private func reviewCommentToCommentPrefix(comment: PullRequestReviewComment) -> String? {
        if let setFileReference = comment.fileReference {
            if comment.isReply {
                return String(localized: "replied on \(setFileReference):")
            }
            return String(localized: "commented on \(setFileReference):")
        }
        if comment.isReply {
            return String(localized: "replied:")
        }
        return nil
    }
    
    var body: some View {
        switch data {
        case let pushedData as PullRequestEventPushedData:
            CommitsView(commits: pushedData.commits)
        case let reviewData as PullRequestEventReviewData:
            if !reviewData.comments.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(reviewData.comments) { comment in
                        PullRequestCommentView(comment: comment.comment, prefix: reviewCommentToCommentPrefix(comment: comment))
                    }
                }
            } else {
                EmptyView()
            }
        case let commentData as PullRequestEventCommentData:
            PullRequestCommentView(comment: commentData.comment)
        case let renamedTitleData as PullRequestEventRenamedTitleData:
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("From:")
                        .frame(width: 50, alignment: .leading)
                        .foregroundStyle(.secondary)
                    Text(renamedTitleData.previousTitle)
                        .frame(width: 400, alignment: .leading)
                        .lineLimit(1)
                    Spacer()
                }
                HStack {
                    Text("To:")
                        .frame(width: 50, alignment: .leading)
                        .foregroundStyle(.secondary)
                    Text(renamedTitleData.currentTitle)
                        .frame(width: 400, alignment: .leading)
                        .lineLimit(1)
                    Spacer()
                }
            }
        case let reviewRequestedData as PullRequestEventReviewRequestedData:
            if reviewRequestedData.requestedReviewer != nil {
                HStack {
                    Text("From:")
                        .frame(width: 50, alignment: .leading)
                        .foregroundStyle(.secondary)
                    Text(reviewRequestedData.requestedReviewer!)
                        .frame(width: 400, alignment: .leading)
                        .lineLimit(1)
                    Spacer()
                }
            }
            EmptyView()
        default:
            EmptyView()
        }
    }
}

struct PullRequestCommentView: View {
    var comment: MarkdownContent
    var prefix: String?
    
    var body: some View {
        VStack(alignment: .leading) {
            if let setPrefix = prefix {
                Text(setPrefix)
                    .foregroundStyle(.secondary)
            }
            ClippedMarkdownView(content: comment)
        }
    }
}

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
    @Environment(\.closeMenuBarWindowModifierLinkAction) var modifierLinkAction
    
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
                ModifierLink(destination: pullRequestEvent.url, additionalAction: modifierLinkAction) {
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
        }.padding()
    }
}
