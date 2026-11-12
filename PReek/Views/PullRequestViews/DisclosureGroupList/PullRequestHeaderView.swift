import SwiftUI

private func usersToString(_ users: [User]) -> String {
    return users.map {
        $0.displayName
    }.joined(separator: "\n")
}

struct PullRequestHeaderView: View, Equatable {
    var pullRequest: PullRequest
    var setRead: (PullRequest.ID, Bool) -> Void
    var viewerLogin: String?

    @Environment(\.colorScheme) var colorScheme
    #if os(macOS)
        @Environment(\.localActionsController) private var localActionsController
    #endif

    init(_ pullRequest: PullRequest, setRead: @escaping (PullRequest.ID, Bool) -> Void, viewerLogin: String? = nil) {
        self.pullRequest = pullRequest
        self.setRead = setRead
        self.viewerLogin = viewerLogin
    }

    static func == (lhs: PullRequestHeaderView, rhs: PullRequestHeaderView) -> Bool {
        lhs.pullRequest.id == rhs.pullRequest.id &&
            lhs.pullRequest.unread == rhs.pullRequest.unread &&
            lhs.pullRequest.title == rhs.pullRequest.title &&
            lhs.pullRequest.lastUpdated == rhs.pullRequest.lastUpdated &&
            lhs.pullRequest.status == rhs.pullRequest.status &&
            lhs.pullRequest.author.login == rhs.pullRequest.author.login &&
            lhs.viewerLogin == rhs.viewerLogin
    }

    var body: some View {
        HStack(spacing: 10) {
            StatusIcon(pullRequest.status)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    HoverableLink(pullRequest.repository.name, destination: pullRequest.repository.url)
                        .foregroundStyle(.primary)
                    Text(pullRequest.numberFormatted)
                        .foregroundColor(.secondary)
                }

                HoverableLink(destination: pullRequest.url) {
                    Text(pullRequest.title)
                        .font(.headline)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .foregroundStyle(.primary)

                details
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            #if os(macOS)
                LocalActionsMenu(
                    pullRequest: pullRequest,
                    viewerLogin: viewerLogin,
                    localActions: localActionsController ?? .shared
                )
            #endif

            Button(action: { setRead(pullRequest.id, pullRequest.unread) }) {
                Image(systemName: pullRequest.unread ? "circle.fill" : "circle")
                    .imageScale(.medium)
                    .foregroundStyle(pullRequest.unread ? .accent : .gray)
            }
            .buttonStyle(.borderless)
        }
    }

    var authorText: some View {
        Text("by \(pullRequest.author.displayName)")
            .lineLimit(1)
            .truncationMode(.tail)
    }

    var details: some View {
        HStack(spacing: 5) {
            authorText
                .if(pullRequest.author.login != pullRequest.author.displayName) { view in
                    view.help(pullRequest.author.login)
                }

            Text("·")

            TimeSensitiveText(getText: { pullRequest.lastUpdatedFormatted })

            Text("·")

            HStack(spacing: 2) {
                Text(pullRequest.additionsFormatted)
                    .foregroundStyle(.success)
                Text(pullRequest.deletionsFormatted)
                    .foregroundStyle(.failure)
            }
            .drawingGroup() // Prevent MacOS to randomly draw this upside down

            if !pullRequest.approvalFrom.isEmpty {
                Text("·")

                HStack(spacing: 1) {
                    Text("\(pullRequest.approvalFrom.count)")
                    ResourceIcon(image: .check)
                        .frame(width: 13)
                        .foregroundColor(.success)
                        .padding(.top, 1)
                }
                .help(usersToString(pullRequest.approvalFrom))
            }
            if !pullRequest.changesRequestedFrom.isEmpty {
                if pullRequest.approvalFrom.isEmpty {
                    Text("·")
                }

                HStack(spacing: 2) {
                    Text("\(pullRequest.changesRequestedFrom.count)")
                    ResourceIcon(image: .fileDiff)
                        .frame(width: 12)
                        .foregroundColor(.failure)
                        .padding(.top, 2)
                }
                .help(usersToString(pullRequest.changesRequestedFrom))
            }
        }
        .foregroundStyle(.secondary)
        .textScale(.secondary)
        .padding(.top, -3)
    }
}

#Preview {
    PullRequestHeaderView(
        PullRequest.preview(title: "long long long long long long long long long long long long long long long long long"),
        setRead: { _, _ in }
    )
    .padding()
}
