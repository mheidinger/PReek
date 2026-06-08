import Foundation

func toComment(commentDto: PullRequestDto.ReviewComment) -> Comment? {
    if commentDto.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return nil
    }

    return Comment(
        id: commentDto.id,
        content: commentDto.body,
        fileReference: commentDto.path,
        isReply: commentDto.replyTo != nil
    )
}
