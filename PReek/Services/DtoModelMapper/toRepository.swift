import Foundation

func toRepository(repository: PullRequestDto.Repository) -> Repository {
    Repository(
        name: repository.nameWithOwner,
        url: URL(string: repository.url) ?? URL(string: "https://invalid.data")!
    )
}
