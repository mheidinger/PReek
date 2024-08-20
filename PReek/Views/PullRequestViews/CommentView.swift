import MarkdownUI
import SwiftUI

struct CommentView: View {
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
    VStack {
        CommentView(comment: Comment(id: UUID().uuidString, content: MarkdownContent("""
        # Heading

        Some text
        """), fileReference: "file.abc:L123", isReply: true))
        Divider()
        CommentView(comment: Comment(id: UUID().uuidString, content: MarkdownContent("""
        # Heading

        Some other text
        """), fileReference: nil, isReply: false))
    }
    .padding()
}
