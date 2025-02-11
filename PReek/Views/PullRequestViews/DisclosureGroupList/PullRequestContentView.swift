import SwiftUI

struct PullRequestContentView: View {
    @State var eventLimit = 0

    var pullRequest: PullRequest

    init(_ pullRequest: PullRequest) {
        eventLimit = min(pullRequest.events.count, 5)
        self.pullRequest = pullRequest
    }

    func loadMore() {
        eventLimit = min(pullRequest.events.count, eventLimit + 5)
    }

    var noEventsBody: some View {
        Text("No Events")
            .foregroundStyle(.secondary)
    }

    var eventsBody: some View {
        VStack {
            DividedView(pullRequest.events[0 ..< eventLimit]) { event in
                EventView(event)
            } shouldHighlight: { event in
                event.id == pullRequest.oldestUnreadEvent?.id ? String(localized: "New") : nil
            } additionalContent: {
                if self.eventLimit < pullRequest.events.count {
                    Button(action: loadMore) {
                        Label("Load More", systemImage: "ellipsis.circle")
                    }
                }
            }
        }
        .padding(.leading, 30)
        .padding(.trailing)
        .padding(.vertical, 5)
    }

    var body: some View {
        if pullRequest.events.isEmpty {
            noEventsBody
        }
        eventsBody
    }
}

#Preview {
    PullRequestContentView(PullRequest.preview())
        .padding()
}
