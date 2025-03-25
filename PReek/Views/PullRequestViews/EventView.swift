import MarkdownUI
import SwiftUI

func eventDataToActionLabel(data: EventData) -> LocalizedStringKey {
    let reviewLabels = [
        EventReviewData.State.approve: LocalizedStringKey("approved"),
        EventReviewData.State.changesRequested: LocalizedStringKey("requested changes"),
        EventReviewData.State.comment: LocalizedStringKey("commented"),
        EventReviewData.State.dismissed: LocalizedStringKey("reviewed (dismissed)"),
    ]

    switch data {
    case is EventClosedData:
        return LocalizedStringKey("closed")
    case let pushedData as EventPushedData:
        return pushedData.isForcePush ? LocalizedStringKey("force pushed") : LocalizedStringKey("pushed")
    case is EventMergedData:
        return LocalizedStringKey("merged")
    case let reviewData as EventReviewData:
        return reviewLabels[reviewData.state] ?? LocalizedStringKey("reviewed")
    case is EventCommentData:
        return LocalizedStringKey("commented")
    case is ReadyForReviewData:
        return LocalizedStringKey("marked ready")
    case is EventRenamedTitleData:
        return LocalizedStringKey("renamed")
    case is EventReopenedData:
        return LocalizedStringKey("reopened")
    case is EventReviewRequestedData:
        return LocalizedStringKey("requested review")
    case is EventConvertToDraftData:
        return LocalizedStringKey("converted to draft")
    case let autoMergeEnabledData as EventAutoMergeEnabledData:
        return LocalizedStringKey("enabled auto-merge (\(autoMergeEnabledData.variant.rawValue))")
    case is EventAutoMergeDisabledData:
        return LocalizedStringKey("disabled auto-merge")
    default:
        return LocalizedStringKey("unknown")
    }
}

struct EventView: View {
    var event: Event

    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    init(_ event: Event) {
        self.event = event
    }

    var body: some View {
        VStack(alignment: .leading) {
            if horizontalSizeClass == .compact {
                compactEventHeader
            } else {
                eventHeader
            }
            EventDataView(event.data)
                .padding(.leading, 20)
                .padding(.top, 2)
        }
    }

    var eventHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(event.user.displayName)
            Spacer()
            Text(eventDataToActionLabel(data: event.data))
            TimeSensitiveText(getText: { event.timeFormatted })
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .trailing)
            HoverableLink(destination: event.url) {
                Image(systemName: "arrow.up.forward.square")
            }
        }
    }

    var compactEventHeader: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .firstTextBaseline) {
                Text(event.user.displayName)
                    .fontWeight(.medium)
                Spacer()
                Text(event.timeFormatted)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 130, alignment: .trailing)
                HoverableLink(destination: event.url) {
                    Image(systemName: "arrow.up.forward.square")
                        .font(.subheadline)
                }
            }
            Text(eventDataToActionLabel(data: event.data))
                .font(.subheadline)
        }
    }
}

#Preview {
    let pullRequestEvents = [
        Event.previewClosed,
        Event.previewCommit(),
        Event.previewCommit(commits: [
            Commit(id: "1", messageHeadline: "my first commit has a really long commit message!", url: URL(string: "https://example.com")!, parentId: nil),
        ]),
        Event.previewCommit(commits: [
            Commit(id: "1", messageHeadline: "my first commit!", url: URL(string: "https://example.com")!, parentId: "2"),
            Commit(id: "2", messageHeadline: "my second commit!", url: URL(string: "https://example.com")!, parentId: "3"),
            Commit(id: "3", messageHeadline: "my third commit!", url: URL(string: "https://example.com")!, parentId: nil),
        ]),
        Event.previewMerged,
        Event.previewReview(),
        Event.previewComment,
        Event.previewReopened,
        Event.previewForcePushed,
        Event.previewRenamedTitle,
        Event.previewReviewRequested,
        Event.previewReadyForReview,
        Event.previewConvertToDraft,
        Event.previewAutoMergeEnabled,
        Event.previewAutoMergeDisabled,
    ]

    return ScrollView {
        VStack {
            DividedView {
                ForEach(pullRequestEvents) { pullRequestEvent in
                    EventView(pullRequestEvent)
                }
            }
        }
        .padding()
    }
}
