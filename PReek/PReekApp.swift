import SwiftUI
import MenuBarExtraAccess

@main
struct PReekApp: App {
    @StateObject private var pullRequestsViewModel: PullRequestsViewModel
    @StateObject private var configViewModel = ConfigViewModel()
    
    @State private var isMenuPresented: Bool = false
    
    init() {
        let pullRequestsViewModel = PullRequestsViewModel()
        self._pullRequestsViewModel = StateObject(wrappedValue: pullRequestsViewModel)
        
#if DEBUG
        // Don't fetch real data for previews
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else {
            return
        }
#endif
        
        pullRequestsViewModel.triggerUpdatePullRequests()
        pullRequestsViewModel.startFetchTimer()
    }
    
    var body: some Scene {
        MenuBarExtra("PReek", image: pullRequestsViewModel.hasUnread ? "MenuBarIconUnread" : "MenuBarIcon") {
            ContentView(pullRequestsViewModel: pullRequestsViewModel, configViewModel: configViewModel, closeWindow: { isMenuPresented = false })
                .frame(width: 600, height: 400)
        }
        .menuBarExtraStyle(.window)
        .defaultSize(width: 600, height: 400)
        .menuBarExtraAccess(isPresented: $isMenuPresented)
    }
}
