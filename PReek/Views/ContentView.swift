import SwiftUI

struct ContentView: View {
    var closeWindow: () -> Void
    
    @ObservedObject var pullRequestsViewModel = PullRequestsViewModel()
    @ObservedObject var configViewModel = ConfigViewModel()
    @State var settingsOpen = false
    
    init(closeWindow: @escaping () -> Void) {
        self.closeWindow = closeWindow
        pullRequestsViewModel.triggerFetchPullRequests()
        pullRequestsViewModel.startFetchTimer()
    }
    
    func modifierLinkAction(modifierPressed: Bool) {
        if ConfigService.closeWindowOnLinkClick != modifierPressed {
            closeWindow()
        }
    }
    
    var body: some View {
        if settingsOpen {
            SettingsView(settingsOpen: $settingsOpen, configViewModel: configViewModel)
        } else {
            mainPage
        }
    }
    
    @ViewBuilder
    var content: some View {
        if !pullRequestsViewModel.pullRequests.isEmpty {
            PullRequestsView(pullRequests: pullRequestsViewModel.pullRequests, toggleRead: pullRequestsViewModel.toggleRead)
        } else if pullRequestsViewModel.hasError {
            Image(systemName: "icloud.slash")
                .font(.largeTitle)
        } else if pullRequestsViewModel.isRefreshing {
            ProgressView()
        } else {
            Text("Nothing here...")
        }
    }
    
    @ViewBuilder
    var mainPage: some View {
        VStack {
            content
                .frame(maxHeight: .infinity, alignment: .center)
            
            StatusBarView(
                lastUpdated: pullRequestsViewModel.lastUpdated,
                hasError: pullRequestsViewModel.hasError,
                onRefresh: pullRequestsViewModel.triggerFetchPullRequests,
                isRefreshing: pullRequestsViewModel.isRefreshing,
                markAllRead: pullRequestsViewModel.markAllAsRead,
                settingsOpen: $settingsOpen
            )
        }
        .environment(\.closeMenuBarWindowModifierLinkAction, modifierLinkAction)
    }
}

#Preview(traits: .fixedLayout(width: 600, height: 400)) {
    ContentView(closeWindow: {})
}
