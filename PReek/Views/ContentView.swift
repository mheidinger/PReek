import SwiftUI

enum Screen: String, CaseIterable, Hashable {
    case settings
    case excludedUsers
}

struct ContentView: View {
    @ObservedObject var pullRequestsViewModel: PullRequestsViewModel
    @ObservedObject var configViewModel: ConfigViewModel

    @StateObject private var keyboardHandler: PullRequestsNavigationShortcutHandler

    var closeWindow: () -> Void

    @State private var showWelcomeScreen: Bool
    @Environment(\.openURL) private var openURL

    init(pullRequestsViewModel: PullRequestsViewModel, configViewModel: ConfigViewModel, closeWindow: @escaping () -> Void) {
        self.pullRequestsViewModel = pullRequestsViewModel
        self.configViewModel = configViewModel
        self.closeWindow = closeWindow
        _keyboardHandler = StateObject(wrappedValue: PullRequestsNavigationShortcutHandler(viewModel: pullRequestsViewModel))

        showWelcomeScreen = configViewModel.token.isEmpty
    }

    private func openURLAdditionalAction(modifierPressed: Bool) {
        if ConfigService.closeWindowOnLinkClick != modifierPressed {
            closeWindow()
        }
    }

    var body: some View {
        NavigationStack {
            VStack {
                if showWelcomeScreen {
                    WelcomeScreen(
                        configViewModel: configViewModel,
                        testConnection: pullRequestsViewModel.testConnection,
                        dismissWelcomeView: {
                            await MainActor.run {
                                pullRequestsViewModel.error = nil
                                showWelcomeScreen = false
                            }
                            await pullRequestsViewModel.updatePullRequests()
                        }
                    )
                } else {
                    MainScreen(
                        pullRequestsViewModel: pullRequestsViewModel,
                        configViewModel: configViewModel
                    )
                    .onAppear {
                        keyboardHandler.disabled = false
                    }
                }
            }
            .navigationDestination(for: Screen.self) { screen in
                Group {
                    switch screen {
                    case .settings:
                        SettingsView(configViewModel: configViewModel)
                    case .excludedUsers:
                        ExcludedUsersScreen(configViewModel: configViewModel)
                    }
                }
                .onAppear {
                    keyboardHandler.disabled = true
                }
                .onDisappear {
                    keyboardHandler.disabled = false
                }
            }
        }
        .environment(\.openURL, OpenURLAction { destination in
            openURL(destination)
            #if os(macOS)
                openURLAdditionalAction(modifierPressed: NSEvent.modifierFlags.contains(.command))
            #endif
            return .handled
        })
    }
}

#Preview {
    @ObservedObject var pullRequestViewModel = PullRequestsViewModel()
    pullRequestViewModel.triggerUpdatePullRequests()
    return ContentView(pullRequestsViewModel: pullRequestViewModel, configViewModel: ConfigViewModel(), closeWindow: {})
}
