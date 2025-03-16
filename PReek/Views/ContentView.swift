import SwiftUI

enum Screen: String, CaseIterable, Hashable {
    case settings
    case excludedUsers
    case share
}

struct ContentView: View {
    @ObservedObject var pullRequestsViewModel: PullRequestsViewModel
    @ObservedObject var configViewModel: ConfigViewModel
    var closeWindow: () -> Void
    @Binding var resetPath: Bool

    @StateObject private var keyboardHandler: PullRequestsNavigationShortcutHandler

    @State private var showWelcomeScreen: Bool
    @Environment(\.openURL) private var openURL

    init(pullRequestsViewModel: PullRequestsViewModel, configViewModel: ConfigViewModel, closeWindow: @escaping () -> Void, resetPath: Binding<Bool>) {
        self.pullRequestsViewModel = pullRequestsViewModel
        self.configViewModel = configViewModel
        self.closeWindow = closeWindow
        _resetPath = resetPath
        _keyboardHandler = StateObject(wrappedValue: PullRequestsNavigationShortcutHandler(viewModel: pullRequestsViewModel))

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
                        await pullRequestsViewModel.updatePullRequests()
                    }
                )
            } else {
                navigationContent
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

    #if os(macOS)
        @State private var path = NavigationPath()
        var navigationContent: some View {
            NavigationStack(path: $path) {
                Group {
                    MainScreen(
                        pullRequestsViewModel: pullRequestsViewModel,
                        configViewModel: configViewModel
                    )
                    .onAppear {
                        keyboardHandler.disabled = false
                    }
                }
                .navigationDestination(for: Screen.self) { screen in
                    Group {
                        switch screen {
                        case .settings:
                            SettingsScreen(configViewModel: configViewModel)
                        case .share:
                            ShareScreen()
                        default:
                            EmptyView()
                        }
                    }
                    .onAppear {
                        keyboardHandler.disabled = true
                    }
                    .onDisappear {
                        keyboardHandler.disabled = false
                    }
                }
                .onChange(of: resetPath) {
                    if resetPath {
                        path = NavigationPath()
                        resetPath = false
                    }
                }
            }
        }
    #else
        var navigationContent: some View {
            TabView {
                MainScreen(
                    pullRequestsViewModel: pullRequestsViewModel,
                    configViewModel: configViewModel
                )
                .tabItem {
                    Label("Pull Requests", systemImage: "list.bullet")
                }

                NavigationStack {
                    SettingsScreen(configViewModel: configViewModel)
                }
                .navigationDestination(for: Screen.self) { screen in
                    Group {
                        switch screen {
                        case .excludedUsers:
                            ExcludedUsersScreen(configViewModel: configViewModel)
                        default:
                            EmptyView()
                        }
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
    return ContentView(pullRequestsViewModel: pullRequestViewModel, configViewModel: ConfigViewModel(), closeWindow: {}, resetPath: .constant(true))
}
