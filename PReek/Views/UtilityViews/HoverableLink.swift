import SwiftUI

struct HoverableLink<Label: View>: View {
    let destination: URL
    let label: Label

    init(destination: URL, @ViewBuilder label: () -> Label) {
        self.destination = destination
        self.label = label()
    }

    var body: some View {
        Link(destination: destination) {
            label
        }
        #if os(macOS)
        .onHover { inside in
            if inside {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        #endif
    }
}

extension HoverableLink where Label == Text {
    init(_ titleKey: LocalizedStringKey, destination: URL) {
        self.init(destination: destination) {
            Text(titleKey)
        }
    }

    @_disfavoredOverload
    init<S>(_ title: S, destination: URL) where S: StringProtocol {
        self.init(destination: destination) {
            Text(title)
        }
    }
}

#Preview {
    HoverableLink(destination: URL(string: "https://example.com")!) {
        Text("Test Link")
    }
    .padding()
}
