import MarkdownUI
import SwiftUI

struct CommentsView: View {
    var comments: [Comment]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(comments) { comment in
                CommentView(comment: comment)
            }
        }
    }
}

private struct CommentView: View {
    var comment: Comment

    var body: some View {
        VStack(alignment: .leading) {
            if let setPrefix = comment.displayPrefix {
                Text(setPrefix)
                    .foregroundStyle(.secondary)
            }
            ClippedMarkdownView(content: comment.content)
        }
    }
}

#Preview {
    let comments = [
        Comment(id: UUID().uuidString, content: MarkdownContent("""
        # Heading

        Some text
        """), fileReference: "file.abc:L123", isReply: true),
        Comment(id: UUID().uuidString, content: MarkdownContent("""
        # Heading

        Some other text
        """), fileReference: nil, isReply: false),
    ]

    return CommentsView(comments: comments)
        .padding()
        .frame(height: 250)
}
