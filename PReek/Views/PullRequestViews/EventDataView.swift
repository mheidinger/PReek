import SwiftUI

struct EventDataView: View {
    var data: any EventData

    init(_ data: any EventData) {
        self.data = data
    }

    var body: some View {
        switch data {
        case let pushedData as EventPushedData:
            CommitsView(commits: pushedData.commits)
        case let reviewData as EventReviewData:
            if !reviewData.comments.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(reviewData.comments) { comment in
                        CommentView(comment: comment)
                    }
                }
            } else {
                EmptyView()
            }
        case let commentData as EventCommentData:
            CommentView(comment: commentData.comment)
        case let renamedTitleData as EventRenamedTitleData:
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
        case let reviewRequestedData as EventReviewRequestedData:
            if !reviewRequestedData.requestedReviewers.isEmpty {
                HStack(alignment: .top) {
                    Text("From:")
                        .frame(width: 50, alignment: .leading)
                        .foregroundStyle(.secondary)
                    if reviewRequestedData.requestedReviewers.count == 1 {
                        Text(reviewRequestedData.requestedReviewers[0])
                    } else {
                        VStack(alignment: .leading) {
                            ForEach(reviewRequestedData.requestedReviewers, id: \.self) { reviewer in
                                BulletPoint(reviewer)
                            }
                        }
                    }
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
    let pullRequestEvents: [Event] = [
        Event.previewCommit(commits: [
            Commit(id: "1", messageHeadline: "my first commit!", url: URL(string: "https://example.com")!),
            Commit(id: "2", messageHeadline: "my second commit!", url: URL(string: "https://example.com")!),
            Commit(id: "3", messageHeadline: "my third commit!", url: URL(string: "https://example.com")!),
        ]),
        Event.previewReview(),
        Event.previewComment,
        Event.previewRenamedTitle,
        Event.previewReviewRequested,
    ]

    return ScrollView {
        VStack(alignment: .leading) {
            DividedView {
                ForEach(pullRequestEvents) { pullRequestEvent in
                    EventDataView(pullRequestEvent.data)
                }
            }
        }
        .padding()
    }
}
