#if os(macOS)
    import AppKit
    import SwiftUI

    @MainActor
    final class SettingsWindowController: NSWindowController {
        private static var shared: SettingsWindowController?

        static func present(configViewModel: ConfigViewModel) {
            let controller: SettingsWindowController
            if let shared {
                controller = shared
            } else {
                controller = SettingsWindowController(configViewModel: configViewModel)
                shared = controller
            }
            controller.showWindow(nil)
            controller.window?.deminiaturize(nil)
            controller.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }

        private init(configViewModel: ConfigViewModel) {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 900, height: 680),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = String(localized: "PReek Settings")
            window.contentMinSize = NSSize(width: 780, height: 560)
            window.isReleasedWhenClosed = false
            super.init(window: window)

            let content = NSHostingController(rootView: SettingsScreen(configViewModel: configViewModel))
            // Let the window constrain the scrollable pages, rather than resizing it to their content.
            content.sizingOptions = []
            window.contentViewController = content
            window.setContentSize(NSSize(width: 900, height: 680))
            window.center()
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            return nil
        }
    }
#endif
