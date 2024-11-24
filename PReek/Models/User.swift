import Foundation

struct User: Equatable {
    let login: String
    private let _displayName: String?
    let url: URL?

    var displayName: String {
        return _displayName ?? login
    }

    init(login: String, displayName: String? = nil, url: URL? = nil) {
        self.login = login
        _displayName = displayName
        self.url = url
    }

    static func preview(login: String? = nil) -> User {
        User(
            login: login ?? "max-heidinger",
            displayName: login ?? "Max Heidinger",
            url: URL(string: "https://example.com")!
        )
    }
}
