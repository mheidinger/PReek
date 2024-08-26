import SwiftUI

struct DividedView<Content: View>: View {
    private let content: Content
    private let shouldHighlight: ((Int) -> Bool)?

    // Initializer for full content without data
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
        shouldHighlight = nil
    }

    // Initializer for data-driven content with optional highlighting
    init<T: Identifiable, ItemContent: View>(_ data: [T], @ViewBuilder content: @escaping (T) -> ItemContent, shouldHighlight: ((T) -> Bool)? = nil) where Content == ForEach<[T], T.ID, ItemContent> {
        self.content = ForEach(data) { item in
            content(item)
        }
        self.shouldHighlight = shouldHighlight.map { highlight in
            { index in
                highlight(data[index])
            }
        }
    }

    var body: some View {
        _VariadicView.Tree(DividedLayout(shouldHighlight: shouldHighlight)) {
            content
        }
    }

    private struct DividedLayout: _VariadicView_MultiViewRoot {
        let shouldHighlight: ((Int) -> Bool)?

        @ViewBuilder
        func body(children: _VariadicView.Children) -> some View {
            let last = children.last?.id

            ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                child

                if child.id != last {
                    if let shouldHighlight = shouldHighlight, shouldHighlight(index) {
                        HighlightedDivider()
                    } else {
                        Divider()
                    }
                }
            }
        }
    }
}

private struct HighlightedDivider: View {
    var body: some View {
        Divider()
            .frame(height: 1)
            .overlay(.orange)
            .background(alignment: .bottomLeading) {
                Text("New")
                    .font(.footnote)
                    .foregroundStyle(.orange)
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
        Item(title: "Beta", isNew: true),
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
            item.isNew
        }
    }
    .padding()
}
