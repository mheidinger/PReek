import Foundation

struct NotificationDto: Decodable {
    struct Subject: Decodable {
        var type: String
        var url: String?
    }

    struct Repository: Decodable {
        var name: String
        var owner: RepositoryOwner
    }

    struct RepositoryOwner: Decodable {
        var login: String
    }

    var subject: Subject
    var repository: Repository
}
