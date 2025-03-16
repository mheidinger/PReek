import SwiftUI

struct PullRequestDetailView: View {
    var pullRequest: PullRequest
    var setRead: (String, Bool) -> Void

    init(_ pullRequest: PullRequest, setRead: @escaping (String, Bool) -> Void) {
        self.pullRequest = pullRequest
        self.setRead = setRead
    }

    var body: some View {
        ScrollView {
            VStack {
                header

                Divider()

                VStack {
                    DividedView(pullRequest.events) { event in
                        EventView(event)
                    } shouldHighlight: { event in
                        event.id == pullRequest.oldestUnreadEvent?.id ? String(localized: "New") : nil
                    }
                }
                .padding()
            }
        }
        .onAppear {
            setRead(pullRequest.id, true)
        }
        .toolbar {
            Button("Mark unread") {
                setRead(pullRequest.id, false)
            }
        }
    }

    var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Group {
                    HStack {
                        Text(pullRequest.repository.name)
                        Text(pullRequest.numberFormatted)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("by \(pullRequest.author.displayName)")
                        Text("·")
                        DateSensitiveText(getText: { pullRequest.lastUpdatedFormatted })
                    }

                    HStack(spacing: 2) {
                        Text(pullRequest.additionsFormatted)
                            .foregroundStyle(.success)
                        Text(pullRequest.deletionsFormatted)
                            .foregroundStyle(.failure)
                    }
                }
                .font(.subheadline)

                HStack {
                    StatusIcon(pullRequest.status)
                        .padding(.top, 3)
                        .padding(.trailing, 5)
                    Text(pullRequest.title)
                        .font(.title)
                        .lineLimit(2)
                    HoverableLink(destination: pullRequest.url) {
                        Image(systemName: "arrow.up.forward.square")
                    }
                }
            }
            Spacer()
        }
        .padding([.top, .leading, .trailing])
    }
}

#Preview {
    PullRequestDetailView(PullRequest.preview(id: "1", title: "long long long long long long long long long"), setRead: { _, _ in })
}
