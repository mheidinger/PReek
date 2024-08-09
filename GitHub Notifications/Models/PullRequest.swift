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
    let lastNonViewerUpdated: Date
    let events: [PullRequestEvent]
    let url: URL
    let additions: Int
    let deletions: Int
    
    var numberFormatted: String {
        "#\(number.formatted(.number .grouping(.never)))"
    }
    
    var lastUpdatedFormatted: String {
        let formattedTime = lastUpdated.formatted(date: .omitted, time: .shortened)
        if (Calendar.current.isDateInToday(lastUpdated)) {
            return "updated at \(formattedTime)"
        }
        if (Calendar.current.isDateInYesterday(lastUpdated)) {
            return "updated yesterday at \(formattedTime)"
        }
        let formattedDate = lastUpdated.formatted(
            Date.FormatStyle()
                .month(.abbreviated)
                .day(.defaultDigits)
        )
        return "updated \(formattedDate) at \(formattedTime)"
    }
    
    var additionsFormatted: String {
        "+\(additions.formatted(.number))"
    }
    
    var deletionsFormatted: String {
        "-\(deletions.formatted(.number))"
    }
    
    var filesUrl: URL {
        url.appendingPathComponent("files")
    }
    
    static func preview(title: String? = nil, status: Status? = nil, events: [PullRequestEvent]? = nil, lastUpdated: Date? = nil) -> PullRequest {
        PullRequest(
            id: UUID().uuidString,
            repository: Repository(name: "t2/t2-graphql", url: URL(string: "https://example.com")!),
            author: User(login: "max-heidinger", url: URL(string: "https://example.com")!),
            title: title ?? "[TRIP-23251] Fix some things but the title is pretty long",
            number: 5312,
            status: status ?? .open,
            lastUpdated: lastUpdated ?? Date(),
            lastNonViewerUpdated: Date(),
            events: events ?? [
                PullRequestEvent.previewMerged,
                PullRequestEvent.previewReview(),
                PullRequestEvent.previewComment
            ],
            url: URL(string: "https://example.com")!,
            additions: 123456,
            deletions: 654321
        )
    }
}
