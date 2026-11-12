import SwiftUI

#if os(iOS)
    enum Screen: String, CaseIterable, Hashable {
        case excludedUsers
    }
#endif

private struct ExternalActionCompletedKey: EnvironmentKey {
    static let defaultValue: (Bool) -> Void = { _ in }
}

extension EnvironmentValues {
    /// Receives the Command-key state captured when an external action was requested.
    var externalActionCompleted: (Bool) -> Void {
        get { self[ExternalActionCompletedKey.self] }
        set { self[ExternalActionCompletedKey.self] = newValue }
    }
}

struct ContentView: View {
    @ObservedObject var pullRequestsViewModel: PullRequestsViewModel
    @ObservedObject var configViewModel: ConfigViewModel
    var closeWindow: () -> Void

    @State private var showWelcomeScreen: Bool
    @Environment(\.openURL) private var openURL

    init(pullRequestsViewModel: PullRequestsViewModel, configViewModel: ConfigViewModel, closeWindow: @escaping () -> Void) {
        self.pullRequestsViewModel = pullRequestsViewModel
        self.configViewModel = configViewModel
        self.closeWindow = closeWindow

        showWelcomeScreen = configViewModel.token.isEmpty
    }

    private func openURLAdditionalAction(modifierPressed: Bool) {
        if ConfigService.closeWindowOnLinkClick != modifierPressed {
            closeWindow()
        }
    }

    var body: some View {
        Group {
            if showWelcomeScreen {
                WelcomeScreen(
                    configViewModel: configViewModel,
                    testConnection: pullRequestsViewModel.testConnection,
                    dismissWelcomeView: {
                        await MainActor.run {
                            pullRequestsViewModel.error = nil
                            showWelcomeScreen = false
                        }
                        await pullRequestsViewModel.updatePullRequestsAndApply()
                    }
                )
            } else {
                navigationContent
            }
        }
        .environmentObject(configViewModel)
        .environment(\.externalActionCompleted, openURLAdditionalAction)
        .environment(\.openURL, OpenURLAction { destination in
            openURL(destination)
            #if os(macOS)
                openURLAdditionalAction(modifierPressed: NSEvent.modifierFlags.contains(.command))
            #endif
            return .handled
        })
    }

    #if os(macOS)
        var navigationContent: some View {
            MainScreen(pullRequestsViewModel: pullRequestsViewModel)
        }
    #else
        var navigationContent: some View {
            TabView {
                MainScreen(pullRequestsViewModel: pullRequestsViewModel)
                    .tabItem {
                        Label("Pull Requests", systemImage: "list.bullet")
                    }

                NavigationStack {
                    SettingsScreen(configViewModel: configViewModel)
                        .navigationDestination(for: Screen.self) { _ in
                            ExcludedUsersScreen(configViewModel: configViewModel)
                        }
                }
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
            }
        }
    #endif
}

#Preview {
    @ObservedObject var pullRequestViewModel = PullRequestsViewModel()
    pullRequestViewModel.triggerUpdatePullRequests()
    return ContentView(pullRequestsViewModel: pullRequestViewModel, configViewModel: ConfigViewModel(), closeWindow: {})
}
