import Foundation

func toUser(_ actor: PullRequestDto.Actor?) -> User {
    guard let actor = actor else {
        return User(login: "Unknown", url: nil)
    }

    return User(
        login: actor.login,
        displayName: actor.name,
        url: URL(string: actor.url)
    )
}
