import OSLog
import SwiftUI
import TipKit

/// Owns the live models; platform apps attach their lifecycle before starting services.
@MainActor
final class PReekAppState: ObservableObject {
    let pullRequestsViewModel = PullRequestsViewModel()
    let configViewModel = ConfigViewModel()

    private let logger = Logger()

    func start() {
        #if DEBUG
            // Don't fetch real data for previews.
            guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else {
                return
            }
        #endif

        do {
            try Tips.configure()
        } catch {
            logger.error("Error initializing tips: \(error)")
        }

        pullRequestsViewModel.triggerUpdatePullRequests()
        pullRequestsViewModel.startFetchTimer()
    }
}
