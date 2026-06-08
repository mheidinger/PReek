import SwiftUI

/// Displays a time-derived string (e.g. "5 minutes ago") that needs to refresh as time passes.
///
/// Each instance owns its own `TimelineView` clock instead of subscribing to a shared timer, so
/// labels refresh independently while on screen (the timeline pauses when the view leaves the
/// hierarchy) and the per-instance `from: .now` phase staggers the work instead of recomputing
/// every label in one synchronized frame.
struct TimeSensitiveText: View {
    let getText: () -> String

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { _ in
            Text(getText())
        }
    }
}
