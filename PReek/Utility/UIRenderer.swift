#if DEBUG && os(macOS)
    import AppKit
    import SwiftUI

    /// View rasterization only: no screen capture, normal app bootstrap, or global input events.
    @MainActor
    enum UIRenderer {
        private struct Failure: LocalizedError {
            let message: String
            var errorDescription: String? {
                message
            }
        }

        private struct Report: Encodable {
            let output: String
            let pixelsWide: Int
            let pixelsHigh: Int
            let visibleWindows: Int
            let applicationActive: Bool
            let activationProhibited: Bool
            let foregroundUnchanged: Bool
        }

        /// A bitmap's scale must also reach AppKit's layer-backed controls, not just its pixel size.
        private final class RenderWindow: NSWindow {
            var renderScale: CGFloat = 1
            override var backingScaleFactor: CGFloat {
                renderScale
            }
        }

        static func run(arguments: [String]) throws {
            if arguments == ["--render-ui", "--help"] {
                print(UIRenderOptions.usage)
                return
            }
            // Validate the entire request before creating any AppKit objects or dependencies.
            let options = try UIRenderOptions.parse(arguments)
            let foregroundBefore = NSWorkspace.shared.frontmostApplication?.processIdentifier
            let app = NSApplication.shared
            guard app.setActivationPolicy(.prohibited), !app.isActive else {
                throw Failure(message: "The render process must remain inactive with activation prohibited.")
            }
            app.appearance = NSAppearance(named: options.appearance == .light ? .aqua : .darkAqua)
            NSTimeZone.default = TimeZone(secondsFromGMT: 0)!

            let domain = "de.max-heidinger.PReek.UIRender.\(UUID().uuidString)"
            guard let defaults = UserDefaults(suiteName: domain) else {
                throw Failure(message: "Could not create an isolated preference domain.")
            }
            let scratch = FileManager.default.temporaryDirectory.appendingPathComponent(domain, isDirectory: true)
            defer {
                defaults.removePersistentDomain(forName: domain)
                try? FileManager.default.removeItem(at: scratch)
            }
            try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
            defaults.set(true, forKey: "showClosed")
            defaults.set(true, forKey: "showRead")

            let store = MemoryConfigStore(values: ConfigValues(
                token: "synthetic-render-token",
                gitHubEnterpriseUrl: "https://github.example.invalid",
                onStartFetchWeeks: 4,
                deleteAfterWeeks: 12,
                excludedUsers: ["build-bot", "dependency-bot"]
            ))
            let localActions = LocalActionsController.rendering(defaults: defaults)
            switch options.screen {
            case .settings:
                let config = ConfigViewModel(store: store)
                let cleanup = LocalActionsCleanup(registry: LocalWorkspaceRegistry(directory: scratch), defaults: defaults)
                try render(SettingsRenderScene(
                    config: config, section: options.section, localActions: localActions, cleanup: cleanup
                ), options: options, foregroundBefore: foregroundBefore)
            case .main:
                let requests = options.state == .loaded ? pullRequests : []
                let model = PullRequestsViewModel(
                    initialPullRequests: requests,
                    defaults: defaults,
                    configStore: store,
                    initialState: .init(
                        lastUpdated: referenceDate,
                        isRefreshing: options.state == .loading,
                        error: options.state == .error ? Failure(message: "Synthetic connection failure") : nil,
                        viewer: Viewer(login: "reviewer", scopes: nil)
                    )
                )
                guard model.pullRequests.count == requests.count,
                      zip(model.pullRequests, requests).allSatisfy({ $0.id == $1.id })
                else {
                    throw Failure(message: "The requested pull request fixture was unexpectedly filtered out.")
                }
                try render(MainScreen(pullRequestsViewModel: model)
                    .environment(\.localActionsController, localActions),
                    options: options, foregroundBefore: foregroundBefore)
            }
        }

        private struct SettingsRenderScene: View {
            let config: ConfigViewModel
            let section: SettingsSection
            let localActions: LocalActionsController
            let cleanup: LocalActionsCleanup
            @State private var launchAtLogin = false

            var body: some View {
                SettingsScreen(
                    configViewModel: config,
                    initialSection: section,
                    localActions: localActions,
                    cleanup: cleanup,
                    launchAtLogin: $launchAtLogin
                )
            }
        }

        private static func render<Content: View>(
            _ content: Content, options: UIRenderOptions, foregroundBefore: pid_t?
        ) throws {
            let size = NSSize(width: options.width, height: options.height)
            let view = content
                .environment(\.colorScheme, options.appearance == .light ? .light : .dark)
                .environment(\.controlActiveState, .active)
                .environment(\.locale, Locale(identifier: "en_US"))
                .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
                .environment(\.openURL, OpenURLAction { _ in
                    preconditionFailure("Opening URLs is forbidden during UI rendering.")
                })
                .transaction { $0.animation = nil }
                .frame(width: size.width, height: size.height)
                .background(Color(nsColor: .windowBackgroundColor))
            let hosting = NSHostingView(rootView: view)
            hosting.sizingOptions = []
            let window = RenderWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.borderless], backing: .buffered, defer: false
            )
            window.renderScale = CGFloat(options.scale)
            window.isReleasedWhenClosed = false
            window.animationBehavior = .none
            window.appearance = NSApp.appearance
            window.contentView = hosting
            hosting.frame = NSRect(origin: .zero, size: size)
            hosting.layoutSubtreeIfNeeded()
            // Native controls and lazy SwiftUI containers need a main-run-loop layout pass.
            RunLoop.main.run(until: Date().addingTimeInterval(0.25))
            hosting.layoutSubtreeIfNeeded()

            guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
                throw Failure(message: "Could not allocate the view bitmap.")
            }
            bitmap.size = size
            hosting.effectiveAppearance.performAsCurrentDrawingAppearance {
                hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
            }
            guard let png = bitmap.representation(using: .png, properties: [:]) else {
                throw Failure(message: "Could not encode the view PNG.")
            }
            let app = NSApplication.shared
            let visibleWindows = app.windows.filter(\.isVisible).count
            guard visibleWindows == 0, app.keyWindow == nil, !app.isActive,
                  app.activationPolicy() == .prohibited
            else {
                throw Failure(message: "UI rendering must not activate the process or show a window.")
            }
            try png.write(to: options.output, options: .atomic)
            let report = Report(
                output: options.output.path,
                pixelsWide: bitmap.pixelsWide,
                pixelsHigh: bitmap.pixelsHigh,
                visibleWindows: visibleWindows,
                applicationActive: app.isActive,
                activationProhibited: app.activationPolicy() == .prohibited,
                foregroundUnchanged: foregroundBefore == NSWorkspace.shared.frontmostApplication?.processIdentifier
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try print(String(decoding: encoder.encode(report), as: UTF8.self))
            // The window was never ordered, made key, or shown. Process exit releases the host.
            withExtendedLifetime(window) {}
        }

        // Historical timestamps avoid relative-time drift; no live or random PR data is used.
        private static let referenceDate = Date(timeIntervalSince1970: 1_577_880_000)
        private static var pullRequests: [PullRequest] {
            let repository = Repository(name: "example/PReek", url: URL(string: "https://github.example.invalid/example/PReek")!)
            let author = User(login: "contributor", displayName: "Example Contributor")
            let reviewer = User(login: "reviewer")
            let titles = [
                "Make pull request notifications easier to review",
                "A deliberately long pull request title to exercise wrapping and truncation at narrow menu widths",
                "Ship the new settings navigation",
            ]
            let statuses: [PullRequest.Status] = [.open, .draft, .merged]
            return titles.enumerated().map { index, title in
                let requestURL = repository.url.appendingPathComponent("pull/\(101 + index)")
                let updated = referenceDate.addingTimeInterval(Double(-index * 3600))
                let event = Event(
                    id: "render-event-\(index)", user: author, time: updated,
                    data: EventClosedData(url: nil), pullRequestUrl: requestURL
                )
                return PullRequest(
                    id: "render-pr-\(index)", repository: repository, author: author,
                    title: title, number: 101 + index, status: statuses[index],
                    lastUpdated: updated, events: [event],
                    url: requestURL,
                    additions: 120 + index, deletions: 18 + index,
                    approvalFrom: [reviewer], changesRequestedFrom: index == 1 ? [User(login: "another-reviewer")] : []
                )
            }
        }
    }
#endif
