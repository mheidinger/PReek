import MarkdownUI
import SwiftUI

struct CommentView: View {
    var comment: MarkdownContent
    var prefix: String?

    var body: some View {
        VStack(alignment: .leading) {
            if let setPrefix = prefix {
                Text(setPrefix)
                    .foregroundStyle(.secondary)
            }
            ClippedMarkdownView(content: comment)
        }
    }
}

#Preview {
    VStack {
        CommentView(comment: MarkdownContent("""
        # Heading

        Some text
        """))
        Divider()
        CommentView(comment: MarkdownContent("""
        # Heading

        Some other text
        """), prefix: "One File xyz.abc")
    }
    .padding()
}
