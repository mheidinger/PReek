#if DEBUG
    import Foundation
    import SwiftUI
    import TipKit

    /// Constructed only after an explicit offline request, before any live app dependencies.
    @MainActor
    final class DebugOfflineSession {
        enum State: String { case loaded, empty, loading, error }
        enum Screen: String { case main, settings, welcome }

        struct Options {
            var state: State = .loaded
            var screen: Screen = .main

            static let usage = """
            Usage: PReek --debug-offline [--state loaded|empty|loading|error] [--screen main|settings|welcome]
                   PReek --debug-offline --help
            Debug only, iOS and macOS. Synthetic data, isolated preferences, no Keychain or live services.
            macOS interactive mode opens a separate window, not the live menu bar app.
            For unattended macOS checks use --render-ui instead.
            """

            static func parse(_ arguments: [String]) throws -> Options {
                guard arguments.first == "--debug-offline" else { throw Failure(message: usage) }
                var result = Options()
                var seen = Set<String>()
                var index = 1
                while index < arguments.count {
                    let key = arguments[index]
                    guard seen.insert(key).inserted, index + 1 < arguments.count else {
                        throw Failure(message: usage)
                    }
                    let value = arguments[index + 1]
                    switch key {
                    case "--state":
                        guard let state = State(rawValue: value) else { throw Failure(message: usage) }
                        result.state = state
                    case "--screen":
                        guard let screen = Screen(rawValue: value) else { throw Failure(message: usage) }
                        result.screen = screen
                    default:
                        throw Failure(message: usage)
                    }
                    index += 2
                }
                return result
            }
        }

        struct Failure: LocalizedError {
            let message: String
            var errorDescription: String? {
                message
            }
        }

        let options: Options
        let defaults: UserDefaults
        let store: MemoryConfigStore
        let model: PullRequestsViewModel
        let importData: Data
        let config: ConfigViewModel
        private let domain: String
        let scratch: URL
        #if os(macOS)
            let localActions: LocalActionsController
            let cleanup: LocalActionsCleanup
        #endif

        init(options: Options) throws {
            self.options = options
            domain = "de.max-heidinger.PReek.DebugOffline.\(UUID().uuidString)"
            guard let defaults = UserDefaults(suiteName: domain) else {
                throw Failure(message: "Could not create isolated debug preferences.")
            }
            self.defaults = defaults
            defaults.set(true, forKey: "showClosed")
            defaults.set(true, forKey: "showRead")
            scratch = FileManager.default.temporaryDirectory.appendingPathComponent(domain, isDirectory: true)
            try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
            try Tips.configure([.datastoreLocation(.url(scratch.appendingPathComponent("Tips")))])
            store = MemoryConfigStore(values: ConfigValues(
                token: options.screen == .welcome ? nil : "synthetic-offline-token",
                gitHubEnterpriseUrl: "https://github.example.invalid",
                onStartFetchWeeks: 4,
                deleteAfterWeeks: 12,
                excludedUsers: ["build-bot", "dependency-bot"]
            ))
            importData = try JSONEncoder().encode(ShareConfig.v1(ShareConfigDataV1(
                token: "synthetic-offline-token",
                gitHubEnterpriseUrl: "https://github.example.invalid",
                onStartFetchWeeks: 4, deleteAfterWeeks: 12,
                deleteOnlyClosed: true, excludedUsers: ["build-bot", "dependency-bot"]
            )))
            config = ConfigViewModel(store: store)
            let requests = options.state == .loaded ? Self.pullRequests : []
            let failure = options.state == .error ? Failure(message: "Synthetic offline connection failure") : nil
            let snapshot = PullRequestsViewModel.OfflineSnapshot(
                pullRequests: options.state == .empty || options.state == .error ? [] : Self.pullRequests,
                viewer: Self.viewer,
                lastUpdated: Self.referenceDate,
                error: failure
            )
            model = PullRequestsViewModel(
                initialPullRequests: requests,
                defaults: defaults,
                configStore: store,
                initialState: .init(
                    lastUpdated: Self.referenceDate,
                    isRefreshing: options.state == .loading,
                    error: failure,
                    viewer: Self.viewer
                ),
                dataSource: .offline(snapshot)
            )
            #if os(macOS)
                localActions = LocalActionsController.rendering(defaults: defaults)
                cleanup = LocalActionsCleanup(registry: LocalWorkspaceRegistry(directory: scratch), defaults: defaults)
            #endif
        }

        func removeDisposablePreferences() {
            defaults.removePersistentDomain(forName: domain)
            try? FileManager.default.removeItem(at: scratch)
        }

        static let referenceDate = Date(timeIntervalSince1970: 1_577_880_000)
        static let viewer = Viewer(login: "reviewer", scopes: nil)
        static var pullRequests: [PullRequest] {
            let repository = Repository(name: "example/PReek", url: URL(string: "https://github.example.invalid/example/PReek")!)
            let author = User(login: "contributor", displayName: "Example Contributor")
            let titles = [
                "Make pull request notifications easier to review",
                "A deliberately long pull request title to exercise wrapping and truncation at narrow widths, keeping the list compact while the full title remains available in the detail view",
                "Ship the new settings navigation",
            ]
            let statuses: [PullRequest.Status] = [.open, .draft, .merged]
            return titles.enumerated().map { index, title in
                let requestURL = repository.url.appendingPathComponent("pull/\(101 + index)")
                let updated = referenceDate.addingTimeInterval(Double(-index * 3600))
                let event = Event(
                    id: "offline-event-\(index)", user: author, time: updated,
                    data: EventCommentData(url: nil, comments: [
                        Comment(id: "offline-comment-\(index)", content: """
                        ## Offline review

                        Synthetic pull request content for **layout and navigation** checks. No GitHub connection is used.

                        A longer comment should remain readable in the detail view, including when larger accessibility text is enabled. The content below also exercises horizontal scrolling without widening the entire screen.

                        ```swift
                        let pullRequest = PullRequest(title: "A deliberately long line that must scroll horizontally instead of clipping the detail or its navigation controls", repository: "example/PReek")
                        ```

                        **End of offline review.**
                        """, fileReference: nil, isReply: false),
                    ]), pullRequestUrl: requestURL
                )
                var events = [event]
                if index == 1 {
                    events.append(Event(
                        id: "offline-rename", user: author, time: updated.addingTimeInterval(-60),
                        data: EventRenamedTitleData(
                            currentTitle: title,
                            previousTitle: "A previous pull request title that is long enough to require multiple lines on an iPhone"
                        ), pullRequestUrl: requestURL
                    ))
                    events.append(Event(
                        id: "offline-review-request", user: author, time: updated.addingTimeInterval(-120),
                        data: EventReviewRequestedData(requestedReviewers: [
                            "example-reviewer-with-a-long-login", "another-reviewer",
                        ]), pullRequestUrl: requestURL
                    ))
                }
                return PullRequest(
                    id: "offline-pr-\(index)", repository: repository, author: author,
                    title: title, number: 101 + index, status: statuses[index],
                    lastUpdated: updated, events: events, url: requestURL,
                    additions: 120 + index, deletions: 18 + index,
                    approvalFrom: [User(login: "reviewer")],
                    changesRequestedFrom: index == 1 ? [User(login: "another-reviewer")] : []
                )
            }
        }
    }
#endif
