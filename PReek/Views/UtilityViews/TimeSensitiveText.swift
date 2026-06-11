import SwiftUI

/// Displays a time-derived string (e.g. "5 minutes ago") that refreshes as time passes.
///
/// Renders a plain `Text` rather than wrapping each label in a `TimelineView`. A `TimelineView` is
/// a layout container with dynamic content, so SwiftUI cannot cache the subtree's size/alignment;
/// with one in every PR/event row nested inside alignment-resolving stacks, that re-resolution
/// compounds super-linearly and can hang layout. A plain `Text` keeps the row layout static.
///
/// `getText()` is recomputed directly in `body` so the value is always current on any re-render.
/// A per-instance timer simply forces a re-render periodically so the label keeps advancing while
/// the view is otherwise idle. The text is intentionally NOT cached in `@State`: caching it made
/// labels stick at their initial value whenever the timer did not fire.
struct TimeSensitiveText: View {
    let getText: () -> String

    @State private var refreshToken = 0
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    init(getText: @escaping () -> String) {
        self.getText = getText
    }

    var body: some View {
        // Mutating `refreshToken` on each tick invalidates this view, so `body` re-evaluates and
        // `getText()` is recomputed against the current date.
        Text(getText())
            .onReceive(timer) { _ in
                refreshToken &+= 1
            }
    }
}
