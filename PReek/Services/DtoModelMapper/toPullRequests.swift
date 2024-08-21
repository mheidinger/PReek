import Foundation
import MarkdownUI

private let pullRequestStatusMap = [
    PullRequestDto.State.OPEN: PullRequest.Status.open,
    PullRequestDto.State.MERGED: PullRequest.Status.merged,
    PullRequestDto.State.CLOSED: PullRequest.Status.closed,
]

private func extractReviewCommentIds(timelineItems: [PullRequestDto.TimelineItem]?) -> [String] {
    guard let timelineItems = timelineItems else {
        return []
    }

    return timelineItems.flatMap { timelineItem in timelineItem.comments?.nodes ?? [] }.map { comment in comment.id }
}

private func extractReviewCount(opinionatedReviews: [PullRequestDto.LatestOpinionatedReview]?) -> ([User], [User]) {
    guard let opinionatedReviews = opinionatedReviews else {
        return ([], [])
    }

    var approvalFrom: [User] = []
    var changesRequestedFrom: [User] = []

    for review in opinionatedReviews {
        switch review.state {
        case .APPROVED:
            approvalFrom.append(toUser(review.author))
        case .CHANGES_REQUESTED:
            changesRequestedFrom.append(toUser(review.author))
        default:
            break
        }
    }
    return (approvalFrom, changesRequestedFrom)
}

private func toPullRequest(dto: PullRequestDto, viewer: PullRequestDto.User) -> PullRequest {
    let pullRequestUrl = URL(string: dto.url) ?? URL(string: "https://invalid.data")!

    let timelineEvents = timelineItemsToEvents(timelineItems: dto.timelineItems.nodes, pullRequestUrl: pullRequestUrl)
    let reviewCommentIds = extractReviewCommentIds(timelineItems: dto.timelineItems.nodes)
    let reviewThreadsCommentsEvents = reviewThreadsCommentsToEvents(reviewThreads: dto.reviewThreads.nodes, reviewCommentIds: reviewCommentIds, pullRequestUrl: pullRequestUrl)

    let events = (timelineEvents + reviewThreadsCommentsEvents).sorted {
        $0.time > $1.time
    }

    let lastNonViewerUpdated = events.first { event in
        event.user.login != viewer.login
    }

    let (approvalFrom, changesRequestedFrom) = extractReviewCount(opinionatedReviews: dto.latestOpinionatedReviews?.nodes)

    return PullRequest(
        id: dto.id,
        repository: toRepository(repository: dto.repository),
        author: toUser(dto.author),
        title: dto.title,
        number: dto.number,
        status: dto.isDraft ? PullRequest.Status.draft : (pullRequestStatusMap[dto.state] ?? PullRequest.Status.open),
        lastUpdated: dto.updatedAt,
        lastNonViewerUpdated: lastNonViewerUpdated?.time ?? dto.updatedAt,
        events: events,
        url: pullRequestUrl,
        additions: dto.additions,
        deletions: dto.deletions,
        approvalFrom: approvalFrom,
        changesRequestedFrom: changesRequestedFrom
    )
}

func toPullRequests(dtos: [PullRequestDto], viewer: PullRequestDto.User) -> [PullRequest] {
    return dtos.map { toPullRequest(dto: $0, viewer: viewer) }
}
