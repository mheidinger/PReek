import MarkdownUI
import SwiftUI

private struct NoneImageProvider: ImageProvider {
    func makeImage(url _: URL?) -> some View {
        Text("< Image >")
    }
}

private struct NoneInlineImageProvider: InlineImageProvider {
    enum SomeError: Error {
        case someError
    }

    func image(with _: URL, label _: String) async throws -> Image {
        throw SomeError.someError
    }
}

struct ClippedMarkdownView: View {
    let rawMarkdown: String

    @State private var isExpanded = false
    @State private var isOverflowing = false

    let maxHeight: CGFloat = 100

    private var content: MarkdownContent {
        MarkdownContentCache.content(rawMarkdown: rawMarkdown)
    }

    private var showClippedAffordances: Bool {
        isOverflowing && !isExpanded
    }

    var body: some View {
        Markdown(content)
            .markdownImageProvider(NoneImageProvider())
            .markdownInlineImageProvider(NoneInlineImageProvider())
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                GeometryReader { contentGeometry in
                    Color.clear.preference(
                        key: HeightPreferenceKey.self, value: contentGeometry.size.height
                    )
                }
            )
            .onPreferenceChange(HeightPreferenceKey.self) { height in
                isOverflowing = height > maxHeight
            }
            .frame(maxHeight: isExpanded ? nil : maxHeight, alignment: .top)
            .clipped()
            .mask(alignment: .top) {
                LinearGradient(
                    colors: [.black, showClippedAffordances ? .clear : .black],
                    startPoint: .center,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .bottomTrailing) {
                if isOverflowing {
                    Button(action: { isExpanded.toggle() }) {
                        Image(
                            systemName: isExpanded
                                ? "arrowtriangle.up.square" : "arrowtriangle.down.square"
                        )
                        .imageScale(.large)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
    }
}

struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview {
    VStack {
        ClippedMarkdownView(
            rawMarkdown: """
            # Too Large

            > This is a quote

            *More to come.*

            ![Some Image](https://example.com/some/image)

            Text with an inline ![Some Image](https://example.com/some/image) embedded.

            *Bla.*

            *Bla.*
            """
        )
        ClippedMarkdownView(
            rawMarkdown: """
            # Fits

            > This is a quote

            *Bla.*
            """
        )
    }
    .frame(height: 300, alignment: .top)
    .padding()
}
