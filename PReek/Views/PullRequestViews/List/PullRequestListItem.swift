import SwiftUI

struct PullRequestListItem: View, Equatable {
    var pullRequest: PullRequest

    #if os(iOS)
        @ScaledMetric(relativeTo: .subheadline) private var reviewIconSize = 13
        @ScaledMetric(relativeTo: .subheadline) private var statusIconSize = 16
    #endif

    init(_ pullRequest: PullRequest) {
        self.pullRequest = pullRequest
    }

    static func == (lhs: PullRequestListItem, rhs: PullRequestListItem) -> Bool {
        lhs.pullRequest.id == rhs.pullRequest.id &&
            lhs.pullRequest.unread == rhs.pullRequest.unread &&
            lhs.pullRequest.title == rhs.pullRequest.title &&
            lhs.pullRequest.lastUpdated == rhs.pullRequest.lastUpdated &&
            lhs.pullRequest.status == rhs.pullRequest.status &&
            lhs.pullRequest.approvalFrom.count == rhs.pullRequest.approvalFrom.count &&
            lhs.pullRequest.changesRequestedFrom.count == rhs.pullRequest.changesRequestedFrom.count
    }

    var body: some View {
        #if os(iOS)
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .center, spacing: 6) {
                    StatusIcon(pullRequest.status, size: statusIconSize)
                    Text(pullRequest.repository.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(pullRequest.numberFormatted)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if pullRequest.unread {
                        Spacer()
                        Circle()
                            .fill(.tint)
                            .frame(width: 8, height: 8)
                            .accessibilityHidden(true)
                    }
                }

                Text(pullRequest.title)
                    .font(.headline)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                details
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityValue(Text(pullRequest.unread ? "Unread" : "Read"))
        #else
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
        #endif
    }

    var details: some View {
        #if os(iOS)
            VStack(alignment: .leading, spacing: 4) {
                ViewThatFits(in: .horizontal) {
                    authorAndTimeRow
                    VStack(alignment: .leading, spacing: 2) {
                        Text("by \(pullRequest.author.displayName)")
                        TimeSensitiveText(getText: { pullRequest.lastUpdatedFormattedShort })
                    }
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        changeStatistics
                        reviewStatistics
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        changeStatistics
                        reviewStatistics
                    }
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        #else
            VStack(alignment: .leading, spacing: 0) {
                authorAndTimeRow

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
        #endif
    }

    private var authorAndTimeRow: some View {
        HStack(spacing: 5) {
            Text("by \(pullRequest.author.displayName)")
            Text("·")
            TimeSensitiveText(getText: { pullRequest.lastUpdatedFormattedShort })
        }
    }

    #if os(iOS)
        private var changeStatistics: some View {
            HStack(spacing: 5) {
                Text(pullRequest.additionsFormatted)
                    .foregroundStyle(.success)
                Text(pullRequest.deletionsFormatted)
                    .foregroundStyle(.failure)
            }
        }

        private var reviewStatistics: some View {
            HStack(spacing: 8) {
                if !pullRequest.approvalFrom.isEmpty {
                    HStack(spacing: 1) {
                        Text("\(pullRequest.approvalFrom.count)")
                        ResourceIcon(image: .check)
                            .frame(width: reviewIconSize, height: reviewIconSize)
                            .foregroundStyle(.success)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("Approvals: \(pullRequest.approvalFrom.count)"))
                }
                if !pullRequest.changesRequestedFrom.isEmpty {
                    HStack(spacing: 2) {
                        Text("\(pullRequest.changesRequestedFrom.count)")
                        ResourceIcon(image: .fileDiff)
                            .frame(width: reviewIconSize, height: reviewIconSize)
                            .foregroundStyle(.failure)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("Changes requested: \(pullRequest.changesRequestedFrom.count)"))
                }
            }
        }
    #endif
}

#Preview {
    List {
        PullRequestListItem(PullRequest.preview(title: "long long long long long long long long long long long long long long long long long", lastUpdated: Calendar.current.date(byAdding: .day, value: -3, to: Date())!))
    }
}
