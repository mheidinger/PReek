import Foundation

struct ReadData: Codable {
    var date: Date
    var eventId: String? // Optional in case of inconsistent state

    private(set) var lastProcessedReadEventId: String?

    private enum CodingKeys: String, CodingKey {
        case date, eventId
        /// Preserve the existing approval marker across upgrades.
        case lastProcessedReadEventId = "lastProcessedApprovalId"
    }

    init(date: Date = .distantPast, eventId: String? = nil) {
        self.date = date
        self.eventId = eventId
    }

    /// Apply each viewer approval or merge once, acknowledging only activity through that event.
    /// The processed ID survives manual read/unread changes and preference round trips.
    /// Returns whether persisted state changed, even if the read boundary was already newer.
    @discardableResult
    mutating func processReadEvents(
        in pullRequest: PullRequest,
        viewer: Viewer,
        markApprovedPullRequestsAsRead: Bool = true,
        markMergedPullRequestsAsRead: Bool = true
    ) -> Bool {
        guard
            let actionIndex = pullRequest.events.firstIndex(where: {
                $0.user.login == viewer.login &&
                    ((markMergedPullRequestsAsRead && $0.data is EventMergedData) ||
                        (markApprovedPullRequestsAsRead && ($0.data as? EventReviewData)?.state == .approve))
            })
        else { return false }
        let action = pullRequest.events[actionIndex]
        if let processedIndex = pullRequest.events.firstIndex(where: {
            $0.id == lastProcessedReadEventId
        }) {
            guard actionIndex < processedIndex else { return false }
        }
        lastProcessedReadEventId = action.id

        // Event order takes precedence over timestamps, as in the unread calculator.
        if let readIndex = pullRequest.events.firstIndex(where: { $0.id == eventId }) {
            guard actionIndex < readIndex else { return true }
        } else if date >= action.time {
            return true
        }
        date = action.time
        eventId = action.id
        return true
    }
}
