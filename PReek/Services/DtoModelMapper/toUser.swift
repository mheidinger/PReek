import Foundation

func toUser(user: PullRequestDto.User?) -> User {
    guard let user = user else {
        return User(login: "Unknown", url: nil)
    }

    return User(
        login: user.login,
        displayName: user.name,
        url: URL(string: user.url)
    )
}
