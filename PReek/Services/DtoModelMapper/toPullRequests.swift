import Foundation
import MarkdownUI

private let pullRequestStatusMap = [
    PullRequestDto.State.OPEN: PullRequest.Status.open,
    PullRequestDto.State.MERGED: PullRequest.Status.merged,
    PullRequestDto.State.CLOSED: PullRequest.Status.closed,
]

private func toPullRequest(dto: PullRequestDto, viewer: PullRequestDto.User) -> PullRequest {
    let pullRequestUrl = URL(string: dto.url) ?? URL(string: "https://invalid.data")!

    let events = timelineItemsToEvents(timelineItems: dto.timelineItems.nodes ?? [], pullRequestUrl: pullRequestUrl).sorted {
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
        status: dto.isDraft ? PullRequest.Status.draft : (pullRequestStatusMap[dto.state] ?? PullRequest.Status.open),
        lastUpdated: dto.updatedAt,
        lastNonViewerUpdated: lastNonViewerUpdated?.time ?? dto.updatedAt,
        events: events,
        url: pullRequestUrl,
        additions: dto.additions,
        deletions: dto.deletions
    )
}

func toPullRequests(dtos: [PullRequestDto], viewer: PullRequestDto.User) -> [PullRequest] {
    return dtos.map { toPullRequest(dto: $0, viewer: viewer) }
}
