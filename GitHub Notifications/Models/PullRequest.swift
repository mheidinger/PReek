//
//  PullRequest.swift
//  GitHub Notifications
//
//  Created by Max Heidinger on 24.05.24.
//

import Foundation

struct PullRequest: Identifiable {
    enum Status {
        case open
        case closed
        case merged
        case draft
    }
    
    let id: String
    let repository: Repository
    let author: User
    let title: String
    let number: Int
    let status: Status
    let lastUpdated: Date
    let events: [PullRequestEvent]
    let url: URL
    
    var numberFormatted: String {
        "#\(number.formatted(.number .grouping(.never)))"
    }
    
    static func preview(title: String? = nil, status: Status? = nil, events: [PullRequestEvent]? = nil) -> PullRequest {
        PullRequest(
            id: UUID().uuidString,
            repository: Repository(name: "t2/t2-graphql", url: URL(string: "https://example.com")!),
            author: User(login: "max-heidinger", url: URL(string: "https://example.com")!),
            title: title ?? "[TRIP-23251] Fix some things but the title is pretty long",
            number: 5312,
            status: status ?? .open,
            lastUpdated: Date(),
            events: events ?? [
                PullRequestEvent.previewMerged,
                PullRequestEvent.previewReview(),
                PullRequestEvent.previewComment
            ],
            url: URL(string: "https://example.com")!
        )
    }
}
