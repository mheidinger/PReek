import Foundation
import MarkdownUI

private struct CommentEventDataPair {
    let comment: PullRequestDto.ReviewComment
    let eventData: EventData
    let latestCreatedAt: Date
}

private func commentToEventData(commentDto: PullRequestDto.ReviewComment, prevPair: CommentEventDataPair?) -> (EventData, Date, Bool) {
    let canMerge = canMergeEvents(commentDto, prevPair?.comment)
    if let prevCommentEventData = prevPair?.eventData as? EventCommentData, canMerge {
        // take latest url to linkt to earliest comment, prepend comments to have order: old to new
        let data = EventCommentData(url: toOptionalUrl(commentDto.url), comments: [toComment(commentDto: commentDto)] + prevCommentEventData.comments)
        // comments are ordered new to old, return last comments createdAt as newest
        return (data, prevPair!.comment.createdAt, false)
    }

    let data = EventCommentData(url: toOptionalUrl(commentDto.url), comments: [toComment(commentDto: commentDto)])
    return (data, commentDto.createdAt, false)
}

func reviewThreadsCommentsToEvents(reviewThreads: [PullRequestDto.ReviewThread]?, reviewCommentIds: [String], pullRequestUrl: URL) -> [Event] {
    guard let reviewThreads = reviewThreads else {
        return []
    }

    // Step 1: Get all comments that are not yet included in timeline events and sort them from new to old for merging
    // Reason for new to old: We want to keep id and url of the resulting event to be the oldest one => stable if an update brings more comments to merge
    // Exception to this is the time: We want the newest one here to make sure that an event including a new comment is marked as such
    let comments = reviewThreads.flatMap { thread in thread.comments.nodes ?? [] }
    let notSeenComments = comments.filter {
        comment in !reviewCommentIds.contains(comment.id)
    }.sorted {
        $0.createdAt > $1.createdAt
    }

    // Step 2: Convert comments to events and merge information
    let pairsWithMerge = notSeenComments.reduce(into: [(CommentEventDataPair, Bool)]()) { result, comment in
        let (data, latestCreatedAt, merge) = commentToEventData(commentDto: comment, prevPair: result.last?.0)
        let pair = CommentEventDataPair(comment: comment, eventData: data, latestCreatedAt: latestCreatedAt)
        result.append((pair, merge))
    }

    // Step 3: Merge items if necessary
    let mergedPairs = mergeArray(pairsWithMerge)

    // Step 4: Convert to Event objects
    return mergedPairs.map { pair in
        let comment = pair.comment
        let data = pair.eventData
        let latestCreatedAt = pair.latestCreatedAt
        return Event(
            id: comment.id + "-event",
            user: toUser(comment.author),
            time: latestCreatedAt,
            data: data,
            pullRequestUrl: pullRequestUrl
        )
    }
}
