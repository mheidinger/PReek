import SwiftUI

struct DividedView<Content: View>: View {
    typealias ShouldHighlightFunc<T> = ((T) -> String?)?

    private let content: Content
    private let shouldHighlight: ShouldHighlightFunc<Int>

    // Initializer for full content without data
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
        shouldHighlight = nil
    }

    // Initializer for data-driven content with optional highlighting, without additional content
    init<T: Identifiable, ItemContent: View, C: Collection>(
        _ data: C,
        @ViewBuilder content: @escaping (T) -> ItemContent,
        shouldHighlight: ShouldHighlightFunc<T> = nil
    ) where C.Element == T, Content == TupleView<(ForEach<C, T.ID, ItemContent>, EmptyView)> {
        self.init(
            data,
            content: content,
            shouldHighlight: shouldHighlight,
            additionalContent: { EmptyView() }
        )
    }

    // Initializer for data-driven content with optional highlighting and additional content
    init<T: Identifiable, ItemContent: View, AdditionalContent: View, C: Collection>(
        _ data: C,
        @ViewBuilder content: @escaping (T) -> ItemContent,
        shouldHighlight: ShouldHighlightFunc<T> = nil,
        @ViewBuilder additionalContent: () -> AdditionalContent
    ) where C.Element == T, Content == TupleView<(ForEach<C, T.ID, ItemContent>, AdditionalContent)> {
        self.content = TupleView((
            ForEach(data, id: \.id) { item in
                content(item)
            },
            additionalContent()
        ))
        self.shouldHighlight = shouldHighlight.map { highlight in
            { index in
                guard index < data.count else { return nil }
                let item = data[data.index(data.startIndex, offsetBy: index)]
                return highlight(item)
            }
        }
    }

    var body: some View {
        _VariadicView.Tree(DividedLayout(shouldHighlight: shouldHighlight)) {
            content
        }
    }

    private struct DividedLayout: _VariadicView_MultiViewRoot {
        let shouldHighlight: ShouldHighlightFunc<Int>

        @ViewBuilder
        func body(children: _VariadicView.Children) -> some View {
            let last = children.last?.id

            ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                child

                if child.id != last {
                    if let shouldHighlight = shouldHighlight, let highlightText = shouldHighlight(index) {
                        HighlightedDivider(highlightText: highlightText)
                    } else {
                        Divider()
                    }
                }
            }
        }
    }
}

private struct HighlightedDivider: View {
    var highlightText: String

    var body: some View {
        Divider()
            .frame(height: 1)
            .overlay(.highlight)
            .background(alignment: .bottomLeading) {
                Text(highlightText)
                    .font(.footnote)
                    .foregroundStyle(.highlight)
            }
            .padding(.top, 4)
    }
}

#Preview {
    struct Item: Identifiable {
        let id = UUID()
        let title: String
        let isNew: Bool
    }

    let items = [
        Item(title: "Alpha", isNew: false),
        Item(title: "Beta", isNew: false),
        Item(title: "Gamma", isNew: true),
    ]

    return VStack {
        DividedView {
            Text("Alpha")
            Text("Beta")
            Text("Gamma")
        }
        Spacer()
        DividedView(items) { item in
            Text(item.title)
        }
        Spacer()
        DividedView(items) { item in
            Text(item.title)
        } shouldHighlight: { item in
            item.isNew ? "New" : nil
        } additionalContent: {
            Button(action: {}) {
                Label("Load More", systemImage: "ellipsis.circle")
            }
        }
    }
    .padding()
}
