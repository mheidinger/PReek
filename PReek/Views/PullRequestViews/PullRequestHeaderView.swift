import SwiftUI

private let statusToIcon: [PullRequest.Status: ImageResource] = [
    PullRequest.Status.draft: .prDraft,
    PullRequest.Status.open: .prOpen,
    PullRequest.Status.merged: .prMerged,
    PullRequest.Status.closed: .prClosed,
]

private func usersToString(_ users: [User]) -> String {
    return users.map {
        $0.displayName
    }.joined(separator: "\n")
}

struct PullRequestHeaderView: View {
    var pullRequest: PullRequest
    var toggleRead: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            Image(statusToIcon[pullRequest.status] ?? .prOpen)
                .foregroundStyle(.primary)
                .imageScale(.large)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        ModifierLink(destination: pullRequest.repository.url) {
                            Text(pullRequest.repository.name)
                        }
                        ModifierLink(destination: pullRequest.url) {
                            Text(pullRequest.numberFormatted)
                        }
                        .foregroundColor(.secondary)
                    }
                    HStack {
                        ModifierLink(destination: pullRequest.url) {
                            Text(pullRequest.title)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                        }
                        .font(.headline)
                    }
                    details
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: pullRequest.markedAsRead ? "circle" : "circle.fill")
                .imageScale(.medium)
                .foregroundStyle(.blue)
                .onTapGesture(perform: toggleRead)
        }
        .padding(.leading)
        .frame(maxWidth: .infinity)
    }

    var details: some View {
        HStack(spacing: 5) {
            if let authorUrl = pullRequest.author.url {
                ModifierLink(destination: authorUrl) {
                    Text("by \(pullRequest.author.displayName)")
                }
            } else {
                Text("by \(pullRequest.author.displayName)")
            }

            Text("·")

            Text("\(pullRequest.lastUpdatedFormatted)")

            Text("·")

            ModifierLink(destination: pullRequest.filesUrl) {
                HStack(spacing: 2) {
                    Text(pullRequest.additionsFormatted)
                        .foregroundStyle(.success)
                    Text(pullRequest.deletionsFormatted)
                        .foregroundStyle(.failure)
                }
            }

            if !pullRequest.approvalFrom.isEmpty || !pullRequest.changesRequestedFrom.isEmpty {
                Text("·")

                HStack(spacing: 5) {
                    if !pullRequest.approvalFrom.isEmpty {
                        HStack(spacing: 1) {
                            Text("\(pullRequest.approvalFrom.count)")
                            IconView(image: .check)
                                .frame(width: 13)
                                .foregroundColor(.success)
                        }
                        .help(usersToString(pullRequest.approvalFrom))
                    }
                    if !pullRequest.changesRequestedFrom.isEmpty {
                        HStack(spacing: 2) {
                            Text("\(pullRequest.changesRequestedFrom.count)")
                            IconView(image: .fileDiff)
                                .frame(width: 12)
                                .foregroundColor(.failure)
                                .padding(.top, 1)
                        }
                        .help(usersToString(pullRequest.changesRequestedFrom))
                    }
                }
            }
        }
        .foregroundStyle(.secondary)
        .textScale(.secondary)
        .padding(.top, -3)
    }
}

#Preview {
    PullRequestHeaderView(pullRequest: PullRequest.preview(), toggleRead: {})
        .padding()
}
