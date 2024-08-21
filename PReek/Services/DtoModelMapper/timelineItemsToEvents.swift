import Foundation
import MarkdownUI

private let reviewStateMap = [
    PullRequestDto.TimelineItem.ReviewState.COMMENTED: EventReviewData.State.comment,
    PullRequestDto.TimelineItem.ReviewState.APPROVED: EventReviewData.State.approve,
    PullRequestDto.TimelineItem.ReviewState.CHANGES_REQUESTED: EventReviewData.State.changesRequested,
    PullRequestDto.TimelineItem.ReviewState.DISMISSED: EventReviewData.State.dismissed,
]

private func timelineItemToData(timelineItem: PullRequestDto.TimelineItem, prevEventData: EventData?) -> (EventData?, Bool) {
    switch timelineItem.type {
    case .ClosedEvent:
        if prevEventData is EventMergedData {
            return (nil, false)
        }
        return (EventClosedData(url: toOptionalUrl(timelineItem.url)), false)
    case .HeadRefForcePushedEvent:
        if let prevCommitEventData = prevEventData as? EventPushedData {
            return (EventPushedData(isForcePush: true, commits: prevCommitEventData.commits), true)
        }
        return (EventPushedData(isForcePush: true, commits: []), false)
    case .IssueComment:
        return (EventCommentData(url: toOptionalUrl(timelineItem.url), comment: Comment(id: timelineItem.id ?? UUID().uuidString, content: MarkdownContent(timelineItem.body ?? ""), fileReference: nil, isReply: false)), false)
    case .MergedEvent:
        return (EventMergedData(url: toOptionalUrl(timelineItem.url)), false)
    case .PullRequestCommit:
        var newCommit: [Commit] = []
        if let commit = timelineItem.commit {
            newCommit.append(Commit(id: commit.oid, messageHeadline: commit.messageHeadline, url: toOptionalUrl(timelineItem.url)))
        }

        if let prevCommitEventData = prevEventData as? EventPushedData {
            return (EventPushedData(isForcePush: false, commits: prevCommitEventData.commits + newCommit), true)
        }
        return (EventPushedData(isForcePush: false, commits: newCommit), false)
    case .PullRequestReview:
        if timelineItem.state == .PENDING {
            return (nil, false)
        }
        return (EventReviewData(
            url: toOptionalUrl(timelineItem.url),
            state: (timelineItem.state != nil) ? reviewStateMap[timelineItem.state!] ?? .dismissed : .dismissed,
            comments: timelineItem.comments?.nodes?.map(toComment) ?? []
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
        return (EventReviewRequestedData(requestedReviewer: timelineItem.requestedReviewer?.name ?? timelineItem.requestedReviewer?.login), false)
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
    var prevEventData: EventData?
    let dataArray: [(EventData, PullRequestDto.TimelineItem, Bool)] = timelineItems.compactMap { timelineItem in
        let (data, merge) = timelineItemToData(timelineItem: timelineItem, prevEventData: prevEventData)
        guard let data, let _ = timelineItem.id else {
            return nil
        }
        prevEventData = data
        return (data, timelineItem, merge)
    }

    // Step 2: Merge items if necessary
    let mergedDataArray = dataArray.reduce([(EventData, PullRequestDto.TimelineItem)]()) { dataArray, element in
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
        Event(
            id: timelineItem.id!,
            user: toUser(user: timelineItem.actor ?? timelineItem.author ?? timelineItem.commit?.author?.user),
            time: timelineItem.createdAt ?? timelineItem.commit?.committedDate ?? Date(),
            data: data,
            pullRequestUrl: pullRequestUrl
        )
    }
}
