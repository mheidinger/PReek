#if DEBUG
    import SwiftUI
    #if os(macOS)
        import AppKit
    #endif

    /// Separate app entry point: never constructs PReekApp, its menu bar delegate, or live services.
    @MainActor
    struct DebugOfflineApp: App {
        private static var session: DebugOfflineSession?

        static func launch(options: DebugOfflineSession.Options) throws {
            session = try DebugOfflineSession(options: options)
            print("PReek offline debug: screen=\(options.screen.rawValue), state=\(options.state.rawValue); synthetic data, no live services")
            main()
        }

        var body: some Scene {
            WindowGroup {
                if let session = Self.session {
                    DebugOfflineRoot(session: session)
                    #if os(macOS)
                        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                            session.removeDisposablePreferences()
                        }
                    #endif
                }
            }
            #if os(macOS)
            .defaultSize(width: 900, height: 680)
            #endif
        }
    }

    @MainActor
    struct DebugOfflineRoot: View {
        let session: DebugOfflineSession
        #if os(macOS)
            var section: SettingsSection = .general
            @State private var launchAtLogin = false
        #endif

        var body: some View {
            content
                .environment(\.externalActionsAllowed, false)
                .environment(\.offlineImportData, session.importData)
                .environment(\.openURL, OpenURLAction { _ in .discarded })
            #if os(macOS)
                .environment(\.localActionsController, session.localActions)
            #endif
        }

        @ViewBuilder
        private var content: some View {
            if session.options.screen == .settings {
                #if os(macOS)
                    SettingsScreen(
                        configViewModel: session.config,
                        initialSection: section,
                        localActions: session.localActions,
                        cleanup: session.cleanup,
                        launchAtLogin: $launchAtLogin
                    )
                #else
                    NavigationStack {
                        SettingsScreen(configViewModel: session.config)
                            .navigationDestination(for: Screen.self) { _ in
                                ExcludedUsersScreen(configViewModel: session.config)
                            }
                    }
                #endif
            } else {
                ContentView(pullRequestsViewModel: session.model, configViewModel: session.config, closeWindow: {})
                #if os(macOS)
                    .frame(minWidth: 600, minHeight: 400)
                #endif
            }
        }
    }
#endif
