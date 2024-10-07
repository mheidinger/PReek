import SwiftUI

struct ContentView: View {
    enum Screen {
        case settings
        case welcome
        case main
    }

    @ObservedObject var pullRequestsViewModel: PullRequestsViewModel
    @ObservedObject var configViewModel: ConfigViewModel

    var closeWindow: () -> Void

    @State var currentScreen: Screen

    @Environment(\.openURL) private var openURL

    init(pullRequestsViewModel: PullRequestsViewModel, configViewModel: ConfigViewModel, closeWindow: @escaping () -> Void) {
        self.pullRequestsViewModel = pullRequestsViewModel
        self.configViewModel = configViewModel
        self.closeWindow = closeWindow
        currentScreen = configViewModel.token.isEmpty ? .welcome : .main
    }

    private func openURLAdditionalAction(modifierPressed: Bool) {
        if ConfigService.closeWindowOnLinkClick != modifierPressed {
            closeWindow()
        }
    }

    private func testConnection() async -> Error? {
        await pullRequestsViewModel.updatePullRequests()
        return pullRequestsViewModel.error
    }

    var body: some View {
        switch currentScreen {
        case .settings:
            SettingsView(configViewModel: configViewModel, closeSettings: { currentScreen = .main })
        case .welcome:
            WelcomeView(configViewModel: configViewModel, testConnection: testConnection, dismissWelcomeView: { currentScreen = .main })
        case .main:
            mainPage
        }
    }

    @ViewBuilder var content: some View {
        if !pullRequestsViewModel.pullRequests.isEmpty {
            PullRequestsView(pullRequestsViewModel.pullRequests, toggleRead: pullRequestsViewModel.toggleRead)
        } else if pullRequestsViewModel.error != nil {
            Image(systemName: "icloud.slash")
                .font(.largeTitle)
        } else if pullRequestsViewModel.isRefreshing {
            ProgressView()
        } else {
            Text("You are done for today! 🎉")
                .font(.title2)
        }
    }

    var mainPage: some View {
        VStack {
            content
                .frame(maxHeight: .infinity, alignment: .center)

            StatusBarView(
                pullRequestsViewModel: pullRequestsViewModel,
                openSettings: { currentScreen = .settings }
            )
            .background(.background.opacity(0.7))
        }
        .background(.background.opacity(0.5))
        .environment(\.openURL, OpenURLAction { destination in
            openURL(destination)
            openURLAdditionalAction(modifierPressed: NSEvent.modifierFlags.contains(.command))
            return .handled
        })
    }
}

#Preview(traits: .fixedLayout(width: 600, height: 400)) {
    @ObservedObject var pullRequestViewModel = PullRequestsViewModel()
    pullRequestViewModel.triggerUpdatePullRequests()
    return ContentView(pullRequestsViewModel: pullRequestViewModel, configViewModel: ConfigViewModel(), closeWindow: {})
}
