import SwiftUI

struct PullRequestListItem: View {
    var pullRequest: PullRequest

    init(_ pullRequest: PullRequest) {
        self.pullRequest = pullRequest
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack {
                Spacer()
                    .frame(maxHeight: 5)

                StatusIcon(pullRequest.status)

                Spacer()
                    .frame(maxHeight: 10)

                Image(systemName: pullRequest.unread ? "circle.fill" : "circle")
                    .imageScale(.medium)
                    .foregroundStyle(pullRequest.unread ? .accent : .gray)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(pullRequest.repository.name)
                        .foregroundStyle(.primary)
                    Text(pullRequest.numberFormatted)
                        .foregroundColor(.secondary)
                }

                Text(pullRequest.title)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)

                details
            }
        }
    }

    var details: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Text("by \(pullRequest.author.displayName)")

                Text("·")

                DateSensitiveText(getText: { pullRequest.lastUpdatedFormattedShort })
            }

            HStack(spacing: 5) {
                HStack(spacing: 2) {
                    Text(pullRequest.additionsFormatted)
                        .foregroundStyle(.success)
                    Text(pullRequest.deletionsFormatted)
                        .foregroundStyle(.failure)
                }

                if !pullRequest.approvalFrom.isEmpty || !pullRequest.changesRequestedFrom.isEmpty {
                    Text("·")

                    HStack(spacing: 5) {
                        if !pullRequest.approvalFrom.isEmpty {
                            HStack(spacing: 1) {
                                Text("\(pullRequest.approvalFrom.count)")
                                ResourceIcon(image: .check)
                                    .frame(width: 13)
                                    .foregroundColor(.success)
                            }
                        }
                        if !pullRequest.changesRequestedFrom.isEmpty {
                            HStack(spacing: 2) {
                                Text("\(pullRequest.changesRequestedFrom.count)")
                                ResourceIcon(image: .fileDiff)
                                    .frame(width: 12)
                                    .foregroundColor(.failure)
                                    .padding(.top, 1)
                            }
                        }
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
    List {
        PullRequestListItem(PullRequest.preview(title: "long long long long long long long long long long long long long long long long long", lastUpdated: Calendar.current.date(byAdding: .day, value: -3, to: Date())!))
    }
}
