//
//  toPullRequests.swift
//  GitHub Notifications
//
//  Created by Max Heidinger on 24.05.24.
//

import Foundation

private let pullRequestStatus = [
    PullRequestDto.State.OPEN: PullRequest.Status.open,
    PullRequestDto.State.MERGED: PullRequest.Status.merged,
    PullRequestDto.State.CLOSED: PullRequest.Status.closed
]

private let pullRequestState = [
    PullRequestDto.TimelineItem.ReviewState.COMMENTED: PullRequestEventReviewData.State.comment,
    PullRequestDto.TimelineItem.ReviewState.APPROVED: PullRequestEventReviewData.State.approve,
    PullRequestDto.TimelineItem.ReviewState.CHANGES_REQUESTED: PullRequestEventReviewData.State.changesRequested,
    PullRequestDto.TimelineItem.ReviewState.DISMISSED: PullRequestEventReviewData.State.dismissed
]

private func toUser(user: PullRequestDto.User?) -> User {
    guard let user = user else {
        return User(login: "Unknown", url: nil)
    }
    
    return User(
        login: user.login,
        displayName: user.name,
        url: URL(string: user.url)
    )
}

private func toRepository(repository: PullRequestDto.Repository) -> Repository {
    Repository(
        name: repository.nameWithOwner,
        url: URL(string: repository.url) ?? URL(string: "https://invalid.data")!
    )
}

private func timelineItemToData(timelineItem: PullRequestDto.TimelineItem, prevEventData: PullRequestEventData?) -> (PullRequestEventData?, Bool) {
    switch timelineItem.type {
    case .ClosedEvent:
        return (PullRequestEventClosedData(), false)
    case .HeadRefForcePushedEvent:
        if let prevCommitEventData = prevEventData as? PullRequestEventCommitData {
            return (PullRequestEventForcePushedData(commitCount: prevCommitEventData.commitCount), true)
        }
        return (PullRequestEventForcePushedData(), false)
    case .IssueComment:
        return (PullRequestEventCommentData(comment: timelineItem.bodyText ?? "Unknown"), false)
    case .MergedEvent:
        return (PullRequestEventMergedData(), false)
    case .PullRequestCommit:
        if let prevCommitEventData = prevEventData as? PullRequestEventCommitData {
            return (PullRequestEventCommitData(commitCount: prevCommitEventData.commitCount + 1), true)
        }
        return (PullRequestEventCommitData(commitCount: 1), false)
    case .PullRequestReview:
        if (timelineItem.state == .PENDING) {
            return (nil, false)
        }
        return (PullRequestEventReviewData(
            state: (timelineItem.state != nil) ? pullRequestState[timelineItem.state!] ?? .dismissed : .dismissed,
            comments: timelineItem.comments?.nodes?.map { comment in
                PullRequestReviewComment(
                    id: comment.id,
                    comment: comment.bodyText,
                    fileReference: comment.path,
                    isReply: comment.replyTo != nil
                )
            } ?? []
        ), false)
    case .ReadyForReviewEvent:
        return (PullRequestEventReadyForReviewData(), false)
    case .RenamedTitleEvent:
        return (PullRequestEventRenamedTitleData(
            currentTitle: timelineItem.currentTitle ?? "Unknown",
            previousTitle: timelineItem.previousTitle ?? "Unknown"
        ), false)
    case .ReopenedEvent:
        return (PullRequestEventReopenedData(), false)
    case .ReviewRequestedEvent:
        return (PullRequestEventReviewRequestedData(requestedReviewer: timelineItem.requestedReviewer?.name ?? timelineItem.requestedReviewer?.login), false)
    default:
        return (nil, false)
    }
}

private func timelineItemsToEvents(timelineItems: [PullRequestDto.TimelineItem]) -> [PullRequestEvent] {
    var prevEventData: PullRequestEventData? = nil
    return timelineItems.reduce([(PullRequestEventData, PullRequestDto.TimelineItem)]()) {dataArray, timelineItem in
        let data = timelineItemToData(timelineItem: timelineItem, prevEventData: prevEventData)
        if data.0 == nil {
            return dataArray
        }
        prevEventData = data.0
        
        var newDataArray = dataArray
        let newItem = (data.0!, timelineItem)
        
        if timelineItem.id == nil {
            return dataArray
        }
        
        if data.1 {
            newDataArray[newDataArray.endIndex-1] = newItem
        } else {
            newDataArray.append(newItem)
        }
        return newDataArray
    }.map { result in
        PullRequestEvent(
            id: result.1.id!,
            user: toUser(user: result.1.actor ?? result.1.author ?? result.1.commit?.author?.user),
            time: result.1.createdAt ?? result.1.commit?.committedDate ?? Date(),
            data: result.0
        )
    }
}

private func toPullRequest(dto: PullRequestDto, viewer: PullRequestDto.User) -> PullRequest {
    let events = timelineItemsToEvents(timelineItems: dto.timelineItems.nodes ?? []).sorted {
        $0.time > $1.time
    }
    
    let lastNonViewerUpdated = events.first { event in
        event.user.login != viewer.login
    }
    
    return PullRequest(
        id: dto.id,
        repository: toRepository(repository: dto.repository),
        author: toUser(user: dto.author),
        title: dto.title,
        number: dto.number,
        status: dto.isDraft ? PullRequest.Status.draft : (pullRequestStatus[dto.state] ?? PullRequest.Status.open),
        lastUpdated: dto.updatedAt,
        lastNonViewerUpdated: lastNonViewerUpdated?.time ?? dto.updatedAt,
        events: events,
        url: URL(string: dto.url) ?? URL(string: "https://invalid.data")!,
        additions: dto.additions,
        deletions: dto.deletions
    )
}

func toPullRequests(dtos: [PullRequestDto], viewer: PullRequestDto.User) -> [PullRequest] {
    return dtos.map({ toPullRequest(dto: $0, viewer: viewer) })
}
