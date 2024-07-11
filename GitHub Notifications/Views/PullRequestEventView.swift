//
//  PullRequestEventView.swift
//  GitHub Notifications
//
//  Created by Max Heidinger on 24.05.24.
//

import SwiftUI

func reviewCommentToCommentPrefix(comment: PullRequestReviewComment) -> String? {
    if let setFileReference = comment.fileReference {
        if comment.isReply {
            return "replied on \(setFileReference):"
        }
        return "commented on \(setFileReference):"
    }
    if comment.isReply {
        return "replied:"
    }
    return nil
}

struct PullRequestEventDataView: View {
    var data: any PullRequestEventData
    
    var body: some View {
        switch (data) {
        case let forcePushData as PullRequestEventForcePushedData:
            if forcePushData.commitCount != nil {
                Text("\(forcePushData.commitCount!) Commits")
            } else {
                EmptyView()
            }
        case let commitData as PullRequestEventCommitData:
            Text("\(commitData.commitCount) Commits")
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
    var comment: String
    var prefix: String?
    
    var body: some View {
        VStack(alignment: .leading) {
            if let setPrefix = prefix {
                Text(setPrefix)
                    .foregroundStyle(.secondary)
            }
            Text(comment)
                .lineLimit(3)
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
    
    switch (data) {
    case is PullRequestEventClosedData:
        return "closed"
    case is PullRequestEventForcePushedData:
        return "force pushed"
    case is PullRequestEventMergedData:
        return "merged"
    case is PullRequestEventCommitData:
        return "pushed"
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
                Text(pullRequestEvent.user.login).frame(width: 200, alignment: .leading)
                Spacer()
                Text(eventDataToActionLabel(data: pullRequestEvent.data)).frame(width: 150, alignment: .trailing)
                Spacer()
                Text(pullRequestEvent.time.formatted(date: .numeric, time: .shortened))
                    .foregroundStyle(.secondary)
            }
            PullRequestEventDataView(data: pullRequestEvent.data)
                .padding(.leading, 30)
        }
    }
}

#Preview {
    let pullRequestEvents: [PullRequestEvent] = [
        PullRequestEvent.previewClosed,
        PullRequestEvent.previewCommit,
        PullRequestEvent.previewMerged,
        PullRequestEvent.previewReview(comments: []),
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
