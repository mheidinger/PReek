import MarkdownUI
import SwiftUI

private struct NoneImageProvider: ImageProvider {
    public func makeImage(url _: URL?) -> some View {
        Text("< Image >")
    }
}

private struct NoneInlineImageProvider: InlineImageProvider {
    enum SomeError: Error {
        case someError
    }

    public func image(with _: URL, label _: String) async throws -> Image {
        throw SomeError.someError
    }
}

struct ClippedMarkdownView: View {
    let content: MarkdownContent

    @State private var contentHeight: CGFloat = 0
    @State private var isExpanded = false

    let maxHeight: CGFloat = 100

    var body: some View {
        GeometryReader { _ in
            Markdown(content)
                .markdownImageProvider(NoneImageProvider())
                .markdownInlineImageProvider(NoneInlineImageProvider())
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(
                    GeometryReader { contentGeometry in
                        Color.clear.preference(key: HeightPreferenceKey.self, value: contentGeometry.size.height)
                    }
                )
                .onPreferenceChange(HeightPreferenceKey.self) { height in
                    contentHeight = height
                }
                .frame(height: isExpanded ? nil : min(contentHeight, maxHeight), alignment: .top)
                .clipped()
                .if(!isExpanded && contentHeight > maxHeight) { view in
                    view
                        .mask {
                            LinearGradient(colors: [.black, .clear], startPoint: .center, endPoint: .bottom)
                        }
                }
                .if(contentHeight > maxHeight) { view in
                    view
                        .overlay(alignment: .bottomTrailing) {
                            Button(action: { isExpanded = !isExpanded }) {
                                Image(systemName: isExpanded ? "arrowtriangle.up.square" : "arrowtriangle.down.square")
                                    .imageScale(.large)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                }
        }
        .frame(height: isExpanded || contentHeight <= maxHeight ? contentHeight : maxHeight)
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
        ClippedMarkdownView(content: MarkdownContent("""
        # Too Large

        > This is a quote

        *More to come.*

        ![Some Image](https://example.com/some/image)

        Text with an inline ![Some Image](https://example.com/some/image) embedded.

        *Bla.*

        *Bla.*
        """))
        ClippedMarkdownView(content: MarkdownContent("""
        # Fits

        > This is a quote

        *Bla.*
        """))
    }
    .frame(height: 300, alignment: .top)
    .padding()
}
