import OSLog
import SwiftUI
import TipKit

@main
struct PReekApp: App {
    private let logger = Logger()

    @StateObject private var pullRequestsViewModel: PullRequestsViewModel
    @StateObject private var configViewModel = ConfigViewModel()

    init() {
        let pullRequestsViewModel = PullRequestsViewModel()
        _pullRequestsViewModel = StateObject(wrappedValue: pullRequestsViewModel)

        #if DEBUG
            // Don't fetch real data for previews
            guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else {
                return
            }
        #endif

        do {
            try Tips.configure()
        } catch {
            logger.error("Error initializing tips: \(error)")
        }

        pullRequestsViewModel.triggerUpdatePullRequests()
        pullRequestsViewModel.startFetchTimer()
    }

    var body: some Scene {
        #if os(macOS)
            MenuBarExtra("PReek", image: pullRequestsViewModel.hasUnread ? "MenuBarIconUnread" : "MenuBarIcon") {
                MenuBarContentView(
                    pullRequestsViewModel: pullRequestsViewModel,
                    configViewModel: configViewModel
                )
            }
            .menuBarExtraStyle(.window)
            .defaultSize(width: 600, height: 400)
        #else
            WindowGroup {
                ContentView(pullRequestsViewModel: pullRequestsViewModel, configViewModel: configViewModel, closeWindow: {}, resetPath: .constant(false))
            }
        #endif
    }
}

#if os(macOS)
    /// Keep presentation state with the window's content, not a scene-level observer.
    /// SwiftUI owns appearance and dismissal, so scene updates cannot accumulate observers.
    private struct MenuBarContentView: View {
        @ObservedObject var pullRequestsViewModel: PullRequestsViewModel
        @ObservedObject var configViewModel: ConfigViewModel
        @Environment(\.dismiss) private var dismiss
        @FocusState private var isContentFocused: Bool

        @State private var isPresented = false
        @State private var focusTask: Task<Void, Never>?
        @State private var resetTask: Task<Void, Never>?
        @State private var resetPath = false

        var body: some View {
            ContentView(
                pullRequestsViewModel: pullRequestsViewModel,
                configViewModel: configViewModel,
                closeWindow: { dismiss() },
                resetPath: $resetPath
            )
            .frame(width: 600, height: 400)
            .focused($isContentFocused)
            .onAppear { setPresented(true) }
            .onDisappear { setPresented(false) }
        }

        private func setPresented(_ presented: Bool) {
            guard isPresented != presented else { return }
            isPresented = presented
            pullRequestsViewModel.setPresentationActive(presented)

            focusTask?.cancel()
            resetTask?.cancel()

            if presented {
                focusTask = Task {
                    // Let AppKit finish its menu-opening navigation request before changing focus.
                    try? await Task.sleep(for: .milliseconds(100))
                    guard !Task.isCancelled, isPresented else { return }
                    isContentFocused = true
                }
            } else {
                isContentFocused = false
                resetTask = Task {
                    try? await Task.sleep(for: .seconds(5))
                    guard !Task.isCancelled, !isPresented else { return }
                    resetPath = true
                }
            }
        }
    }
#endif
