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
    return id + "-event"
}

private struct TimelineItemEventDataPair {
    let timelineItem: PullRequestDto.TimelineItem
    let eventData: EventData
    let mergedFromOldest: PullRequestDto.TimelineItem?

    var baseTimelineItem: PullRequestDto.TimelineItem {
        mergedFromOldest ?? timelineItem
    }
}

private func timelineItemToData(timelineItem: PullRequestDto.TimelineItem, prevPair: TimelineItemEventDataPair?) -> TimelineItemEventDataPair? {
    let canMerge = canMergeEvents(timelineItem, prevPair?.baseTimelineItem)

    var data: EventData?
    var merge = false

    switch timelineItem.type {
    case .ClosedEvent:
        // If the last event before closing a PR has been a merge, omit the close event
        if prevPair?.eventData is EventMergedData {
            break
        }
        data = EventClosedData(url: toOptionalUrl(timelineItem.url))
    case .HeadRefForcePushedEvent:
        if let prevCommitEventData = prevPair?.eventData as? EventPushedData, canMerge {
            data = EventPushedData(isForcePush: true, commits: prevCommitEventData.commits)
            merge = true
            break
        }
        data = EventPushedData(isForcePush: true, commits: [])
    case .IssueComment:
        // Don't merge here as these are top-level comments on the PR
        var comments: [Comment] = []
        if let body = timelineItem.body, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            comments.append(Comment(id: toMainCommentId(timelineItem.id), content: MarkdownContent(body), fileReference: nil, isReply: false))
        }
        data = EventCommentData(url: toOptionalUrl(timelineItem.url), comments: comments)
    case .MergedEvent:
        data = EventMergedData(url: toOptionalUrl(timelineItem.url))
    case .PullRequestCommit:
        var newCommit: [Commit] = []
        if let commit = timelineItem.commit {
            newCommit.append(Commit(id: commit.oid, messageHeadline: commit.messageHeadline, url: toOptionalUrl(timelineItem.url), parentId: commit.parents.nodes.first?.oid))
        }

        if let prevCommitEventData = prevPair?.eventData as? EventPushedData, canMerge {
            data = EventPushedData(isForcePush: prevCommitEventData.isForcePush, commits: prevCommitEventData.commits + newCommit)
            merge = true
            break
        }
        data = EventPushedData(isForcePush: false, commits: newCommit)
    case .PullRequestReview:
        guard timelineItem.state != .PENDING else {
            break
        }

        let state = timelineItem.state.flatMap { reviewStateMap[$0] } ?? .dismissed

        var comments: [Comment] = []
        if let mainCommentBody = timelineItem.body, !mainCommentBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            comments.append(Comment(id: toMainCommentId(timelineItem.id), content: MarkdownContent(mainCommentBody), fileReference: nil, isReply: false))
        }
        comments += (timelineItem.comments?.nodes?.compactMap(toComment) ?? [])

        data = EventReviewData(
            url: toOptionalUrl(timelineItem.url),
            state: state,
            comments: comments
        )
    case .ReadyForReviewEvent:
        data = ReadyForReviewData(url: toOptionalUrl(timelineItem.url))
    case .RenamedTitleEvent:
        data = EventRenamedTitleData(
            currentTitle: timelineItem.currentTitle ?? "Unknown",
            previousTitle: timelineItem.previousTitle ?? "Unknown"
        )
    case .ReopenedEvent:
        data = EventReopenedData()
    case .ReviewRequestedEvent:
        let newRequestedReviewers = timelineItem.requestedReviewer?.resolvedName.map { [$0] } ?? []
        if let prevReviewReqeuestedEventData = prevPair?.eventData as? EventReviewRequestedData, canMerge {
            let combinedRequestedReviewers = prevReviewReqeuestedEventData.requestedReviewers + newRequestedReviewers
            data = EventReviewRequestedData(requestedReviewers: combinedRequestedReviewers)
            merge = true
            break
        }
        data = EventReviewRequestedData(requestedReviewers: newRequestedReviewers)
    case .ConvertToDraftEvent:
        data = EventConvertToDraftData(url: toOptionalUrl(timelineItem.url))
    case .AutoMergeEnabledEvent:
        data = EventAutoMergeEnabledData(variant: .merge)
    case .AutoRebaseEnabledEvent:
        data = EventAutoMergeEnabledData(variant: .rebase)
    case .AutoSquashEnabledEvent:
        data = EventAutoMergeEnabledData(variant: .squash)
    case .AutoMergeDisabledEvent:
        data = EventAutoMergeDisabledData()
    default:
        break
    }

    guard let data else {
        return nil
    }

    return TimelineItemEventDataPair(timelineItem: timelineItem, eventData: data, mergedFromOldest: merge ? prevPair?.baseTimelineItem : nil)
}

func timelineItemsToEvents(timelineItems: [PullRequestDto.TimelineItem]?, pullRequestUrl: URL) -> [Event] {
    guard let timelineItems = timelineItems else {
        return []
    }

    // Step 1: Convert timeline items to data and merge information
    var pairs: [TimelineItemEventDataPair] = []
    pairs.reserveCapacity(timelineItems.count)

    for timelineItem in timelineItems {
        guard timelineItem.id != nil else {
            continue
        }

        guard let pair = timelineItemToData(timelineItem: timelineItem, prevPair: pairs.last) else {
            continue
        }

        pairs.append(pair)
    }

    // Step 2: Merge items if necessary
    let mergedPairs = mergeArray(pairs, indicator: \.mergedFromOldest)

    // Step 3: Convert to Event objects
    return mergedPairs.map { pair in
        let timelineItem = pair.timelineItem
        let baseTimelineItem = pair.baseTimelineItem
        let data = pair.eventData
        return Event(
            id: baseTimelineItem.id!, // ID of oldest item
            user: toUser(baseTimelineItem.resolvedActor),
            time: timelineItem.resolvedTime, // Time of newest item
            data: data,
            pullRequestUrl: pullRequestUrl
        )
    }
}
