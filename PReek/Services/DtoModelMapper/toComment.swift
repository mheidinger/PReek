import Foundation
import MarkdownUI

func toComment(commentDto: PullRequestDto.ReviewComment) -> Comment {
    Comment(
        id: commentDto.id,
        content: MarkdownContent(commentDto.body),
        fileReference: commentDto.path,
        isReply: commentDto.replyTo != nil
    )
}
