import Foundation
import MarkdownUI

private func commentToEvent(commentDto: PullRequestDto.ReviewComment, pullRequestUrl: URL) -> Event {
    let data = PullRequestEventCommentData(url: toOptionalUrl(commentDto.url), comment: toComment(commentDto: commentDto))

    return Event(
        id: commentDto.id,
        user: toUser(user: commentDto.author),
        time: commentDto.createdAt,
        data: data,
        pullRequestUrl: pullRequestUrl
    )
}

func reviewThreadsCommentsToEvents(reviewThreads: [PullRequestDto.ReviewThread]?, reviewCommentIds: [String], pullRequestUrl: URL) -> [Event] {
    guard let reviewThreads = reviewThreads else {
        return []
    }

    let comments = reviewThreads.flatMap { thread in thread.comments.nodes ?? [] }
    let notSeenComments = comments.filter { comment in !reviewCommentIds.contains(comment.id) }

    return notSeenComments.map { comment in commentToEvent(commentDto: comment, pullRequestUrl: pullRequestUrl) }
}
