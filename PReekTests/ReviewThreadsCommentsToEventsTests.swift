import Foundation
import MarkdownUI
import Testing

func toDate(minute: Int) -> Date {
    let components = DateComponents(year: 2024, month: 9, day: 11, hour: 13, minute: minute)
    return Calendar.current.date(from: components)!
}

func createComment(id: String, author: PullRequestDto.Actor, body: String, minute: Int) -> PullRequestDto.ReviewComment {
    PullRequestDto.ReviewComment(
        id: id,
        author: author,
        body: body,
        createdAt: toDate(minute: minute),
        path: "/path/to/file",
        replyTo: nil,
        url: "https://example.com"
    )
}

let urlString = "https://example.com"
let url = URL(string: urlString)!

let actor1 = PullRequestDto.Actor(login: "user-1", url: urlString, name: nil)
let actor2 = PullRequestDto.Actor(login: "user-2", url: urlString, name: nil)
let actor3 = PullRequestDto.Actor(login: "user-3", url: urlString, name: nil)

struct ReviewThreadsCommentsToEventsTests {
    @Test func mapSeparateReviewThreadsComments() async throws {
        let firstThreadCommentDtos: [PullRequestDto.ReviewComment] = [
            createComment(id: "comment-2", author: actor2, body: "comment-2", minute: 5),
        ]
        let secondThreadCommentDtos: [PullRequestDto.ReviewComment] = [
            createComment(id: "comment-1", author: actor1, body: "comment-1", minute: 0),
        ]
        let reviewThreadDtos: [PullRequestDto.ReviewThread] = [
            PullRequestDto.ReviewThread(comments: PullRequestDto.ReviewComments(nodes: firstThreadCommentDtos)),
            PullRequestDto.ReviewThread(comments: PullRequestDto.ReviewComments(nodes: secondThreadCommentDtos)),
        ]

        let events = reviewThreadsCommentsToEvents(reviewThreads: reviewThreadDtos, reviewCommentIds: [], pullRequestUrl: url)

        try #require(events.count == 2)
        #expect(events[0].id == "comment-1-event")
        #expect(events[0].user.login == "user-1")
        #expect(events[0].time == toDate(minute: 0))
        let event0Data = try #require(events[0].data as? EventCommentData)
        try #require(event0Data.comments.count == 1)
        #expect(event0Data.comments[0].id == "comment-1")
        #expect(event0Data.comments[0].content.renderPlainText() == "comment-1")

        #expect(events[1].id == "comment-2-event")
        #expect(events[1].user.login == "user-2")
        #expect(events[1].time == toDate(minute: 5))
        let event1Data = try #require(events[1].data as? EventCommentData)
        try #require(event1Data.comments.count == 1)
        #expect(event1Data.comments[0].id == "comment-2")
        #expect(event1Data.comments[0].content.renderPlainText() == "comment-2")
    }

    @Test func mergeReviewThreadsComments() async throws {
        let firstThreadCommentDtos: [PullRequestDto.ReviewComment] = [
            createComment(id: "comment-1", author: actor1, body: "comment-1", minute: 0),
        ]
        let secondThreadCommentDtos: [PullRequestDto.ReviewComment] = [
            createComment(id: "comment-2", author: actor1, body: "comment-2", minute: 1),
            createComment(id: "comment-3", author: actor2, body: "comment-3", minute: 2),
        ]
        let reviewThreadDtos: [PullRequestDto.ReviewThread] = [
            PullRequestDto.ReviewThread(comments: PullRequestDto.ReviewComments(nodes: firstThreadCommentDtos)),
            PullRequestDto.ReviewThread(comments: PullRequestDto.ReviewComments(nodes: secondThreadCommentDtos)),
        ]

        let events = reviewThreadsCommentsToEvents(reviewThreads: reviewThreadDtos, reviewCommentIds: [], pullRequestUrl: url)

        try #require(events.count == 2)
        #expect(events[0].id == "comment-1-event")
        #expect(events[0].user.login == "user-1")
        #expect(events[0].time == toDate(minute: 1))
        let event0Data = try #require(events[0].data as? EventCommentData)
        try #require(event0Data.comments.count == 2)
        #expect(event0Data.comments[0].id == "comment-1")
        #expect(event0Data.comments[1].id == "comment-2")

        #expect(events[1].id == "comment-3-event")
        #expect(events[1].user.login == "user-2")
        #expect(events[1].time == toDate(minute: 2))
        let event1Data = try #require(events[1].data as? EventCommentData)
        try #require(event1Data.comments.count == 1)
        #expect(event1Data.comments[0].id == "comment-3")
        #expect(event1Data.comments[0].content.renderPlainText() == "comment-3")
    }

    @Test func excludeReviewThreadsCommentsFromReviews() async throws {
        let firstThreadCommentDtos: [PullRequestDto.ReviewComment] = [
            createComment(id: "comment-1", author: actor1, body: "comment-1", minute: 0),
            createComment(id: "comment-2", author: actor1, body: "comment-2", minute: 1),
        ]
        let reviewThreadDtos: [PullRequestDto.ReviewThread] = [
            PullRequestDto.ReviewThread(comments: PullRequestDto.ReviewComments(nodes: firstThreadCommentDtos)),
        ]

        let events = reviewThreadsCommentsToEvents(reviewThreads: reviewThreadDtos, reviewCommentIds: ["comment-2"], pullRequestUrl: url)

        try #require(events.count == 1)
        #expect(events[0].id == "comment-1-event")
        #expect(events[0].user.login == "user-1")
        #expect(events[0].time == toDate(minute: 0))
        let event0Data = try #require(events[0].data as? EventCommentData)
        try #require(event0Data.comments.count == 1)
        #expect(event0Data.comments[0].id == "comment-1")
    }
}
