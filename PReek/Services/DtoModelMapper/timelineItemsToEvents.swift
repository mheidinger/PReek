import Foundation
import MarkdownUI

private let reviewStateMap = [
    PullRequestDto.ReviewState.COMMENTED: EventReviewData.State.comment,
    PullRequestDto.ReviewState.APPROVED: EventReviewData.State.approve,
    PullRequestDto.ReviewState.CHANGES_REQUESTED: EventReviewData.State.changesRequested,
    PullRequestDto.ReviewState.DISMISSED: EventReviewData.State.dismissed,
]

private func toMainCommentId(_ id: String?) -> String {
    guard let id = id else {
        return UUID().uuidString
    }
    return id + "-comment"
}

private struct TimelineItemEventDataPair {
    let timelineItem: PullRequestDto.TimelineItem
    let eventData: EventData
}

private func canMergeTimelineItems(_ firstItem: PullRequestDto.TimelineItem, _ secondItem: PullRequestDto.TimelineItem?) -> Bool {
    guard let secondItem = secondItem else {
        return false
    }

    let sameAuthor = firstItem.resolvedActor?.login == secondItem.resolvedActor?.login
    // Check if times are within 5 minutes of each other
    let closeInTime = abs(firstItem.resolvedTime.timeIntervalSince(secondItem.resolvedTime)) < 5 * 60

    return sameAuthor && closeInTime
}

private func timelineItemToData(timelineItem: PullRequestDto.TimelineItem, prevPair: TimelineItemEventDataPair?) -> (EventData?, Bool) {
    let canMerge = canMergeTimelineItems(timelineItem, prevPair?.timelineItem)

    switch timelineItem.type {
    case .ClosedEvent:
        // If the last event before closing a PR has been a merge, omit the close event
        if prevPair?.eventData is EventMergedData {
            return (nil, false)
        }
        return (EventClosedData(url: toOptionalUrl(timelineItem.url)), false)
    case .HeadRefForcePushedEvent:
        if let prevCommitEventData = prevPair?.eventData as? EventPushedData, canMerge {
            return (EventPushedData(isForcePush: true, commits: prevCommitEventData.commits), true)
        }
        return (EventPushedData(isForcePush: true, commits: []), false)
    case .IssueComment:
        return (EventCommentData(url: toOptionalUrl(timelineItem.url), comment: Comment(id: toMainCommentId(timelineItem.id), content: MarkdownContent(timelineItem.body ?? ""), fileReference: nil, isReply: false)), false)
    case .MergedEvent:
        return (EventMergedData(url: toOptionalUrl(timelineItem.url)), false)
    case .PullRequestCommit:
        var newCommit: [Commit] = []
        if let commit = timelineItem.commit {
            newCommit.append(Commit(id: commit.oid, messageHeadline: commit.messageHeadline, url: toOptionalUrl(timelineItem.url)))
        }

        if let prevCommitEventData = prevPair?.eventData as? EventPushedData, canMerge {
            return (EventPushedData(isForcePush: prevCommitEventData.isForcePush, commits: prevCommitEventData.commits + newCommit), true)
        }
        return (EventPushedData(isForcePush: false, commits: newCommit), false)
    case .PullRequestReview:
        guard timelineItem.state != .PENDING else {
            return (nil, false)
        }

        let state = timelineItem.state.flatMap { reviewStateMap[$0] } ?? .dismissed

        let mainComment = timelineItem.body.map { body in
            Comment(
                id: toMainCommentId(timelineItem.id),
                content: MarkdownContent(body),
                fileReference: nil,
                isReply: false
            )
        }
        let allComments = (mainComment.map { [$0] } ?? []) + (timelineItem.comments?.nodes?.map(toComment) ?? [])

        return (EventReviewData(
            url: toOptionalUrl(timelineItem.url),
            state: state,
            comments: allComments
        ), false)
    case .ReadyForReviewEvent:
        return (ReadyForReviewData(url: toOptionalUrl(timelineItem.url)), false)
    case .RenamedTitleEvent:
        return (EventRenamedTitleData(
            currentTitle: timelineItem.currentTitle ?? "Unknown",
            previousTitle: timelineItem.previousTitle ?? "Unknown"
        ), false)
    case .ReopenedEvent:
        return (EventReopenedData(), false)
    case .ReviewRequestedEvent:
        let newRequestedReviewers = timelineItem.requestedReviewer?.resolvedName.map { [$0] } ?? []
        if let prevReviewReqeuestedEventData = prevPair?.eventData as? EventReviewRequestedData, canMerge {
            let combinedRequestedReviewers = prevReviewReqeuestedEventData.requestedReviewers + newRequestedReviewers
            return (EventReviewRequestedData(requestedReviewers: combinedRequestedReviewers), true)
        }
        return (EventReviewRequestedData(requestedReviewers: newRequestedReviewers), false)
    case .ConvertToDraftEvent:
        return (EventConvertToDraftData(url: toOptionalUrl(timelineItem.url)), false)
    default:
        return (nil, false)
    }
}

func timelineItemsToEvents(timelineItems: [PullRequestDto.TimelineItem]?, pullRequestUrl: URL) -> [Event] {
    guard let timelineItems = timelineItems else {
        return []
    }

    // Step 1: Convert timeline items to data and merge information
    let pairsWithMerge = timelineItems.reduce(into: [(TimelineItemEventDataPair, Bool)]()) { result, timelineItem in
        let (data, merge) = timelineItemToData(timelineItem: timelineItem, prevPair: result.last?.0)
        guard let data, let _ = timelineItem.id else {
            return
        }

        let pair = TimelineItemEventDataPair(timelineItem: timelineItem, eventData: data)
        result.append((pair, merge))
    }

    // Step 2: Merge items if necessary
    let mergedPairs = pairsWithMerge.reduce([TimelineItemEventDataPair]()) { dataArray, element in
        let (pair, merge) = element

        var newDataArray = dataArray
        if !dataArray.isEmpty, merge {
            newDataArray[newDataArray.endIndex - 1] = pair
        } else {
            newDataArray.append(pair)
        }
        return newDataArray
    }

    // Step 3: Convert to PullRequestEvent objects
    return mergedPairs.map { pair in
        let timelineItem = pair.timelineItem
        let data = pair.eventData
        return Event(
            id: timelineItem.id!,
            user: toUser(timelineItem.resolvedActor),
            time: timelineItem.resolvedTime,
            data: data,
            pullRequestUrl: pullRequestUrl
        )
    }
}
