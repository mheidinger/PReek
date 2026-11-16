import SwiftUI

#if os(iOS)
    enum Screen: String, CaseIterable, Hashable {
        case excludedUsers
    }
#endif

private struct ExternalActionCompletedKey: EnvironmentKey {
    static let defaultValue: (Bool) -> Void = { _ in }
}

private struct ExternalActionsAllowedKey: EnvironmentKey {
    static let defaultValue = true
}

private struct OfflineImportDataKey: EnvironmentKey {
    static let defaultValue: Data? = nil
}

extension EnvironmentValues {
    var externalActionsAllowed: Bool {
        get { self[ExternalActionsAllowedKey.self] }
        set { self[ExternalActionsAllowedKey.self] = newValue }
    }

    var offlineImportData: Data? {
        get { self[OfflineImportDataKey.self] }
        set { self[OfflineImportDataKey.self] = newValue }
    }

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
        if configViewModel.closeWindowOnLinkClick != modifierPressed {
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
                MainScreen(pullRequestsViewModel: pullRequestsViewModel)
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
}

#Preview {
    @ObservedObject var pullRequestViewModel = PullRequestsViewModel()
    pullRequestViewModel.triggerUpdatePullRequests()
    return ContentView(pullRequestsViewModel: pullRequestViewModel, configViewModel: ConfigViewModel(), closeWindow: {})
}
