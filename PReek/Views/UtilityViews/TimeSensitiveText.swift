import Combine
import SwiftUI

/// A single, app-wide clock that ticks periodically so every time-derived label can refresh in
/// lockstep off one reliable timer instead of each label owning its own `Timer.publish` publisher.
///
/// One long-lived publisher (owned by this singleton) is far more dependable than dozens of
/// per-view `autoconnect()` timers whose lifecycles get tangled up inside `LazyVStack` rows and
/// `EquatableView` boundaries — the previous per-instance approach "occasionally did not fire",
/// which froze labels that had no other reason to re-render.
final class TimeRefreshClock: ObservableObject {
    static let shared = TimeRefreshClock()

    @Published private(set) var now = Date()

    private var cancellable: AnyCancellable?

    private init() {
        cancellable = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                self?.now = date
            }
    }
}

/// Displays a time-derived string (e.g. "5 minutes ago") that refreshes as time passes.
///
/// Renders a plain `Text` rather than wrapping each label in a `TimelineView`. A `TimelineView` is
/// a layout container with dynamic content, so SwiftUI cannot cache the subtree's size/alignment;
/// with one in every PR/event row nested inside alignment-resolving stacks, that re-resolution
/// compounds super-linearly and can hang layout. A plain `Text` keeps the row layout static.
///
/// Refreshing is driven by the shared `TimeRefreshClock`: observing it invalidates this leaf on
/// every tick, so `getText()` is recomputed against the current date. Because the leaf depends on
/// the clock directly, it keeps advancing even when an ancestor is wrapped in `.equatable()` and
/// would otherwise suppress all incidental re-renders (as the PR header is).
struct TimeSensitiveText: View {
    let getText: () -> String

    @ObservedObject private var clock = TimeRefreshClock.shared

    init(getText: @escaping () -> String) {
        self.getText = getText
    }

    var body: some View {
        // `clock.now` is read so the tick is registered as a dependency; the value itself is only
        // a trigger — `getText()` always computes against the real current date.
        let _ = clock.now
        Text(getText())
    }
}
