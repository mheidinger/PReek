import SwiftUI

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
                        CommentView(comment: comment.comment, prefix: reviewCommentToCommentPrefix(comment: comment))
                    }
                }
            } else {
                EmptyView()
            }
        case let commentData as PullRequestEventCommentData:
            CommentView(comment: commentData.comment)
        case let renamedTitleData as PullRequestEventRenamedTitleData:
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("From:")
                        .frame(width: 50, alignment: .leading)
                        .foregroundStyle(.secondary)
                    Text(renamedTitleData.previousTitle)
                        .frame(width: 400, alignment: .leading)
                        .lineLimit(1)
                }
                HStack {
                    Text("To:")
                        .frame(width: 50, alignment: .leading)
                        .foregroundStyle(.secondary)
                    Text(renamedTitleData.currentTitle)
                        .frame(width: 400, alignment: .leading)
                        .lineLimit(1)
                }
            }
        case let reviewRequestedData as PullRequestEventReviewRequestedData:
            if let requestedReviewer = reviewRequestedData.requestedReviewer {
                HStack {
                    Text("From:")
                        .frame(width: 50, alignment: .leading)
                        .foregroundStyle(.secondary)
                    Text(requestedReviewer)
                        .frame(width: 400, alignment: .leading)
                        .lineLimit(1)
                }
            } else {
                EmptyView()
            }
        default:
            EmptyView()
        }
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
        VStack(alignment: .leading) {
            DividedView {
                ForEach(pullRequestEvents) { pullRequestEvent in
                    PullRequestEventDataView(data: pullRequestEvent.data)
                }
            }
        }
        .padding()
    }
}
