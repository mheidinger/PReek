import SwiftUI

struct PullRequestDetailView: View {
    var pullRequest: PullRequest

    private var onMarkUnread: () -> Void

    init(_ pullRequest: PullRequest, onMarkUnread: @escaping () -> Void) {
        self.pullRequest = pullRequest
        self.onMarkUnread = onMarkUnread
    }

    var body: some View {
        #if os(iOS)
            scrollContent
                .navigationTitle(pullRequest.repository.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button("Mark unread", systemImage: "envelope.badge", action: onMarkUnread)
                            Link(destination: pullRequest.url) {
                                Label("Open on GitHub", systemImage: "arrow.up.forward.square")
                            }
                        } label: {
                            Label("Actions", systemImage: "ellipsis.circle")
                        }
                    }
                }
        #else
            GeometryReader { _ in
                scrollContent
            }
        #endif
    }

    private var scrollContent: some View {
        ScrollView {
            LazyVStack {
                header

                Divider()

                // Only the outer stack is lazy; nested lazy stacks conflict during sizing.
                VStack {
                    DividedView(pullRequest.events) { event in
                        EventView(event)
                    } shouldHighlight: { event in
                        event.id == pullRequest.oldestUnreadEvent?.id ? String(localized: "New") : nil
                    }
                }
                .padding([.leading, .trailing, .bottom])
            }
        }
    }

    var header: some View {
        #if os(iOS)
            iOSHeader
        #else
            macOSHeader
        #endif
    }

    #if os(iOS)
        private var iOSHeader: some View {
            VStack(alignment: .leading, spacing: 12) {
                ViewThatFits(in: .horizontal) {
                    HStack {
                        repositoryLabel
                        Spacer()
                        StatusLabel(pullRequest.status)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        repositoryLabel
                        StatusLabel(pullRequest.status)
                    }
                }

                Text(pullRequest.title)
                    .font(.title2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .textSelection(.enabled)

                VStack(alignment: .leading, spacing: 4) {
                    Text("by \(pullRequest.author.displayName)")
                    TimeSensitiveText(getText: { pullRequest.lastUpdatedFormatted })
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                changeStatistics
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding([.top, .leading, .trailing])
        }
    #else
        private var macOSHeader: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(pullRequest.repository.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(pullRequest.numberFormatted)
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Spacer()

                    StatusLabel(pullRequest.status)
                }

                Text(pullRequest.title)
                    .font(.title3)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Text("by \(pullRequest.author.displayName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    TimeSensitiveText(getText: { pullRequest.lastUpdatedFormatted })
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                HStack {
                    changeStatistics
                        .font(.subheadline)

                    Spacer()

                    HoverableLink(destination: pullRequest.url) {
                        Image(systemName: "arrow.up.forward.square")
                    }
                }
            }
            .padding([.top, .leading, .trailing])
        }
    #endif

    private var changeStatistics: some View {
        HStack {
            Text(pullRequest.additionsFormatted)
                .foregroundStyle(.green)
            Text(pullRequest.deletionsFormatted)
                .foregroundStyle(.red)
        }
    }

    #if os(iOS)
        private var repositoryLabel: some View {
            HStack(alignment: .firstTextBaseline) {
                Text(pullRequest.repository.name)
                    .foregroundStyle(.primary)
                Text(pullRequest.numberFormatted)
                    .foregroundStyle(.secondary)
            }
            .font(.headline)
        }
    #endif
}

#Preview {
    NavigationStack {
        PullRequestDetailView(PullRequest.preview(id: "1", title: "long long long long long long long long long"), onMarkUnread: {})
    }
}
