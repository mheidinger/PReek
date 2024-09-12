import Foundation
import MarkdownUI

private struct CommentEventDataPair {
    let comment: PullRequestDto.ReviewComment
    let eventData: EventData
    let mergedFromOldest: PullRequestDto.ReviewComment?

    var baseComment: PullRequestDto.ReviewComment {
        mergedFromOldest ?? comment
    }
}

private func commentToEventDataPair(commentDto: PullRequestDto.ReviewComment, prevPair: CommentEventDataPair?) -> CommentEventDataPair {
    let canMerge = canMergeEvents(commentDto, prevPair?.baseComment)

    let newComments = [toComment(commentDto: commentDto)].compactMap { $0 }

    if let prevCommentEventData = prevPair?.eventData as? EventCommentData, canMerge {
        // take latest url to link to earliest comment, prepend comments to have order: old to new
        let data = EventCommentData(url: toOptionalUrl(commentDto.url), comments: prevCommentEventData.comments + newComments)
        // comments are ordered new to old, return last comments createdAt as newest
        return CommentEventDataPair(comment: commentDto, eventData: data, mergedFromOldest: prevPair?.baseComment)
    }

    let data = EventCommentData(url: toOptionalUrl(commentDto.url), comments: newComments)
    return CommentEventDataPair(comment: commentDto, eventData: data, mergedFromOldest: nil)
}

func reviewThreadsCommentsToEvents(reviewThreads: [PullRequestDto.ReviewThread]?, reviewCommentIds: [String], pullRequestUrl: URL) -> [Event] {
    guard let reviewThreads = reviewThreads else {
        return []
    }

    // Step 1: Get all comments that are not yet included in timeline events and sort them from old to new for merging
    let comments = reviewThreads.flatMap { thread in thread.comments.nodes ?? [] }
    let notSeenComments = comments.filter {
        comment in !reviewCommentIds.contains(comment.id)
    }.sorted {
        $0.createdAt < $1.createdAt
    }

    // Step 2: Convert comments to events and merge information
    let pairs = notSeenComments.reduce(into: [CommentEventDataPair]()) { result, comment in
        let pair = commentToEventDataPair(commentDto: comment, prevPair: result.last)
        result.append(pair)
    }

    // Step 3: Merge items if necessary
    let mergedPairs = mergeArray(pairs, indicator: \.mergedFromOldest)

    // Step 4: Convert to Event objects
    return mergedPairs.map { pair in
        let comment = pair.comment
        let baseComment = pair.baseComment
        let data = pair.eventData
        return Event(
            id: baseComment.id + "-event", // ID of oldest comment
            user: toUser(baseComment.author),
            time: comment.createdAt, // Time of newest comment
            data: data,
            pullRequestUrl: pullRequestUrl
        )
    }
}
