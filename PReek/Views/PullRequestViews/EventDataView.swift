import SwiftUI

struct EventDataView: View {
    var data: EventData

    init(_ data: EventData) {
        self.data = data
    }

    var body: some View {
        switch data {
        case let pushedData as EventPushedData:
            CommitsView(commits: pushedData.commits)
        case let reviewData as EventReviewData:
            CommentsView(comments: reviewData.comments)
        case let commentData as EventCommentData:
            CommentsView(comments: commentData.comments)
        case let renamedTitleData as EventRenamedTitleData:
            HStack {
                VStack(alignment: .leading) {
                    Text("From:")
                    Text("To:")
                }
                .foregroundStyle(.secondary)

                VStack(alignment: .leading) {
                    Text(renamedTitleData.previousTitle)
                        .lineLimit(1)
                    Text(renamedTitleData.currentTitle)
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
    let pullRequestEvents = [
        Event.previewCommit(commits: [
            Commit(id: "1", messageHeadline: "my first commit has a really long commit message!", url: URL(string: "https://example.com")!, parentId: "2"),
            Commit(id: "2", messageHeadline: "my second commit!", url: URL(string: "https://example.com")!, parentId: "3"),
            Commit(id: "3", messageHeadline: "my third commit!", url: URL(string: "https://example.com")!, parentId: nil),
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
