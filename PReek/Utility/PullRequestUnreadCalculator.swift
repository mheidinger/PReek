import Foundation

/// Utility for calculating unread status externally without mutating PullRequest instances
struct PullRequestUnreadCalculator {

    /// Result of unread calculation
    struct UnreadResult {
        let unread: Bool
        let oldestUnreadEvent: Event?
    }

    /// Calculate unread status for a pull request without mutating it
    /// - Parameters:
    ///   - pullRequest: The pull request to analyze
    ///   - viewer: Current viewer information
    ///   - readData: Read status data for this PR
    /// - Returns: UnreadResult containing calculated unread status and oldest unread event
    static func calculateUnread(
        for pullRequest: PullRequest,
        viewer: Viewer?,
        readData: ReadData?
    ) -> UnreadResult {
        guard let readData else {
            return UnreadResult(unread: true, oldestUnreadEvent: nil)
        }

        // Try event ID based calculation first
        if let eventBasedResult = calculateUnreadFromEventId(
            events: pullRequest.events,
            viewer: viewer,
            lastMarkedAsReadEventId: readData.eventId
        ) {
            return eventBasedResult
        }

        // Fallback to time-based approach
        return calculateUnreadFromDate(
            events: pullRequest.events,
            lastUpdated: pullRequest.lastUpdated,
            viewer: viewer,
            readDate: readData.date
        )
    }

    /// Calculate unread status based on event ID
    private static func calculateUnreadFromEventId(
        events: [Event],
        viewer: Viewer?,
        lastMarkedAsReadEventId: Event.ID?
    ) -> UnreadResult? {
        guard let lastMarkedAsReadEventId else {
            return nil
        }

        let lastReadEventIndex = events.firstIndex(where: { $0.id == lastMarkedAsReadEventId })
        guard let lastReadEventIndex else {
            return nil
        }

        let newerNonViewerEvents = Array(events.prefix(upTo: lastReadEventIndex))
            .filter { event in event.user.login != viewer?.login }

        if newerNonViewerEvents.isEmpty {
            return UnreadResult(unread: false, oldestUnreadEvent: nil)
        }

        return UnreadResult(unread: true, oldestUnreadEvent: newerNonViewerEvents.last)
    }

    /// Calculate unread status based on date comparison
    private static func calculateUnreadFromDate(
        events: [Event],
        lastUpdated: Date,
        viewer: Viewer?,
        readDate: Date
    ) -> UnreadResult {
        let nonViewerEvents = events.filter { event in event.user.login != viewer?.login }
        let lastMarkedAsReadComparisonDate = nonViewerEvents.first?.time ?? lastUpdated

        let unread = readDate < lastMarkedAsReadComparisonDate
        let oldestUnreadEvent = nonViewerEvents.reversed().first { event in
            event.time > readDate
        }

        return UnreadResult(unread: unread, oldestUnreadEvent: oldestUnreadEvent)
    }
}