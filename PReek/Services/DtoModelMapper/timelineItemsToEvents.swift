import Foundation
import MarkdownUI

private func toOptionalUrl(_ url: String?) -> URL? {
    guard let url = url else {
        return nil
    }
    return URL(string: url)
}

private let reviewStateMap = [
    PullRequestDto.TimelineItem.ReviewState.COMMENTED: PullRequestEventReviewData.State.comment,
    PullRequestDto.TimelineItem.ReviewState.APPROVED: PullRequestEventReviewData.State.approve,
    PullRequestDto.TimelineItem.ReviewState.CHANGES_REQUESTED: PullRequestEventReviewData.State.changesRequested,
    PullRequestDto.TimelineItem.ReviewState.DISMISSED: PullRequestEventReviewData.State.dismissed,
]

private func timelineItemToData(timelineItem: PullRequestDto.TimelineItem, prevEventData: PullRequestEventData?) -> (PullRequestEventData?, Bool) {
    switch timelineItem.type {
    case .ClosedEvent:
        if prevEventData is PullRequestEventMergedData {
            return (nil, false)
        }
        return (PullRequestEventClosedData(url: toOptionalUrl(timelineItem.url)), false)
    case .HeadRefForcePushedEvent:
        if let prevCommitEventData = prevEventData as? PullRequestEventPushedData {
            return (PullRequestEventPushedData(isForcePush: true, commits: prevCommitEventData.commits), true)
        }
        return (PullRequestEventPushedData(isForcePush: true, commits: []), false)
    case .IssueComment:
        return (PullRequestEventCommentData(url: toOptionalUrl(timelineItem.url), comment: MarkdownContent(timelineItem.body ?? "")), false)
    case .MergedEvent:
        return (PullRequestEventMergedData(url: toOptionalUrl(timelineItem.url)), false)
    case .PullRequestCommit:
        var newCommit: [Commit] = []
        if let commit = timelineItem.commit {
            newCommit.append(Commit(id: commit.oid, messageHeadline: commit.messageHeadline, url: toOptionalUrl(timelineItem.url)))
        }

        if let prevCommitEventData = prevEventData as? PullRequestEventPushedData {
            return (PullRequestEventPushedData(isForcePush: false, commits: prevCommitEventData.commits + newCommit), true)
        }
        return (PullRequestEventPushedData(isForcePush: false, commits: newCommit), false)
    case .PullRequestReview:
        if timelineItem.state == .PENDING {
            return (nil, false)
        }
        return (PullRequestEventReviewData(
            url: toOptionalUrl(timelineItem.url),
            state: (timelineItem.state != nil) ? reviewStateMap[timelineItem.state!] ?? .dismissed : .dismissed,
            comments: timelineItem.comments?.nodes?.map { comment in
                PullRequestReviewComment(
                    id: comment.id,
                    comment: MarkdownContent(comment.body),
                    fileReference: comment.path,
                    isReply: comment.replyTo != nil
                )
            } ?? []
        ), false)
    case .ReadyForReviewEvent:
        return (PullRequestEventReadyForReviewData(url: toOptionalUrl(timelineItem.url)), false)
    case .RenamedTitleEvent:
        return (PullRequestEventRenamedTitleData(
            currentTitle: timelineItem.currentTitle ?? "Unknown",
            previousTitle: timelineItem.previousTitle ?? "Unknown"
        ), false)
    case .ReopenedEvent:
        return (PullRequestEventReopenedData(), false)
    case .ReviewRequestedEvent:
        return (PullRequestEventReviewRequestedData(requestedReviewer: timelineItem.requestedReviewer?.name ?? timelineItem.requestedReviewer?.login), false)
    case .ConvertToDraftEvent:
        return (PullRequestEventConvertToDraftData(url: toOptionalUrl(timelineItem.url)), false)
    default:
        return (nil, false)
    }
}

func timelineItemsToEvents(timelineItems: [PullRequestDto.TimelineItem], pullRequestUrl: URL) -> [PullRequestEvent] {
    // Step 1: Convert timeline items to data and merge information
    var prevEventData: PullRequestEventData?
    let dataArray: [(PullRequestEventData, PullRequestDto.TimelineItem, Bool)] = timelineItems.compactMap { timelineItem in
        let (data, merge) = timelineItemToData(timelineItem: timelineItem, prevEventData: prevEventData)
        guard let data, let _ = timelineItem.id else {
            return nil
        }
        prevEventData = data
        return (data, timelineItem, merge)
    }

    // Step 2: Merge items if necessary
    let mergedDataArray = dataArray.reduce([(PullRequestEventData, PullRequestDto.TimelineItem)]()) { dataArray, element in
        let (data, timelineItem, merge) = element

        var newDataArray = dataArray
        let newItem = (data, timelineItem)
        if !dataArray.isEmpty, merge {
            newDataArray[newDataArray.endIndex - 1] = newItem
        } else {
            newDataArray.append(newItem)
        }
        return newDataArray
    }

    // Step 3: Convert to PullRequestEvent objects
    return mergedDataArray.map { data, timelineItem in
        PullRequestEvent(
            id: timelineItem.id!,
            user: toUser(user: timelineItem.actor ?? timelineItem.author ?? timelineItem.commit?.author?.user),
            time: timelineItem.createdAt ?? timelineItem.commit?.committedDate ?? Date(),
            data: data,
            pullRequestUrl: pullRequestUrl
        )
    }
}
