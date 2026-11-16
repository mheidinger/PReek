#if os(macOS)
    import AppKit
    import Combine
    import SwiftUI

    struct PReekMacOSApp: App {
        @StateObject private var state: PReekAppState
        @NSApplicationDelegateAdaptor(MenuBarAppDelegate.self) private var appDelegate

        init() {
            let state = PReekAppState()
            _state = StateObject(wrappedValue: state)
            appDelegate.configure(
                pullRequestsViewModel: state.pullRequestsViewModel,
                configViewModel: state.configViewModel
            )
            state.start()
        }

        var body: some Scene {
            Settings {
                SettingsScreen(configViewModel: state.configViewModel)
            }
            .commands {
                SettingsWindowCommands(configViewModel: state.configViewModel)
            }
        }
    }

    @MainActor
    final class MenuBarAppDelegate: NSObject, NSApplicationDelegate {
        private var statusItem: NSStatusItem?
        private let popover = NSPopover()
        private var unreadSubscription: AnyCancellable?
        private var pullRequestsViewModel: PullRequestsViewModel?
        private var configViewModel: ConfigViewModel?

        func configure(pullRequestsViewModel: PullRequestsViewModel, configViewModel: ConfigViewModel) {
            self.pullRequestsViewModel = pullRequestsViewModel
            self.configViewModel = configViewModel
            let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            self.statusItem = statusItem
            statusItem.button?.target = self
            statusItem.button?.action = #selector(handleClick)
            statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
            statusItem.button?.toolTip = "PReek"

            popover.behavior = .transient
            popover.contentSize = NSSize(width: 600, height: 400)
            popover.delegate = self
            popover.contentViewController = makePopoverContentViewController()
            unreadSubscription = pullRequestsViewModel.$hasUnread
                .receive(on: RunLoop.main)
                .sink { [weak statusItem] hasUnread in
                    let image = NSImage(named: hasUnread ? "MenuBarIconUnread" : "MenuBarIcon")
                    image?.isTemplate = true
                    statusItem?.button?.image = image
                }
        }

        private func makePopoverContentViewController() -> NSHostingController<MenuBarContentView> {
            guard let pullRequestsViewModel, let configViewModel else {
                preconditionFailure(
                    "Menu bar content must be configured before presenting the popover."
                )
            }
            return NSHostingController(
                rootView: MenuBarContentView(
                    pullRequestsViewModel: pullRequestsViewModel,
                    configViewModel: configViewModel,
                    closeWindow: { [weak self] in self?.popover.performClose(nil) }
                )
            )
        }

        @objc private func handleClick(_ sender: NSStatusBarButton) {
            if NSApp.currentEvent?.type == .rightMouseUp {
                popover.performClose(nil)
                let menu = NSMenu()
                let settings = NSMenuItem(title: String(localized: "Settings"), action: #selector(openSettings), keyEquivalent: ",")
                settings.target = self
                menu.addItem(settings)
                menu.addItem(.separator())
                let quit = NSMenuItem(title: String(localized: "Quit App"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
                quit.target = NSApp
                menu.addItem(quit)
                statusItem?.menu = menu
                sender.performClick(nil)
                statusItem?.menu = nil
            } else if popover.isShown {
                popover.performClose(nil)
            } else {
                if popover.contentViewController == nil {
                    popover.contentViewController = makePopoverContentViewController()
                }
                popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }

        @MainActor
        @objc private func openSettings() {
            guard let configViewModel else { return }
            SettingsWindowController.present(configViewModel: configViewModel)
        }
    }

    extension MenuBarAppDelegate: NSPopoverDelegate {
        func popoverDidClose(_: Foundation.Notification) {
            pullRequestsViewModel?.setPresentationActive(false)
            // A closed popover can retain its hosting view without SwiftUI delivering onDisappear.
            // Recreate it on the next opening so transient disclosure state is reset as intended.
            popover.contentViewController = nil
        }
    }

    struct SettingsWindowCommands: Commands {
        var configViewModel: ConfigViewModel

        var body: some Commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings") {
                    SettingsWindowController.present(configViewModel: configViewModel)
                }
                .keyboardShortcut(",")
            }
        }
    }

    /// Keep presentation state with the window's content, not a scene-level observer.
    /// SwiftUI owns appearance and dismissal, so scene updates cannot accumulate observers.
    private struct MenuBarContentView: View {
        @ObservedObject var pullRequestsViewModel: PullRequestsViewModel
        @ObservedObject var configViewModel: ConfigViewModel
        var closeWindow: () -> Void
        @FocusState private var isContentFocused: Bool

        @State private var isPresented = false
        @State private var focusTask: Task<Void, Never>?

        var body: some View {
            ContentView(
                pullRequestsViewModel: pullRequestsViewModel,
                configViewModel: configViewModel,
                closeWindow: closeWindow
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

            if presented {
                focusTask = Task {
                    // Let AppKit finish its menu-opening navigation request before changing focus.
                    try? await Task.sleep(for: .milliseconds(100))
                    guard !Task.isCancelled, isPresented else { return }
                    isContentFocused = true
                }
            } else {
                isContentFocused = false
            }
        }
    }
#endif
