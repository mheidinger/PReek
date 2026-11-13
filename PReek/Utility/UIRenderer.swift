#if DEBUG && os(macOS)
    import AppKit
    import SwiftUI

    /// View rasterization only: no screen capture, normal app bootstrap, or global input events.
    @MainActor
    enum UIRenderer {
        private struct Failure: LocalizedError {
            let message: String
            var errorDescription: String? {
                message
            }
        }

        private struct Report: Encodable {
            let output: String
            let pixelsWide: Int
            let pixelsHigh: Int
            let visibleWindows: Int
            let applicationActive: Bool
            let activationProhibited: Bool
            let foregroundUnchanged: Bool
        }

        /// A bitmap's scale must also reach AppKit's layer-backed controls, not just its pixel size.
        private final class RenderWindow: NSWindow {
            var renderScale: CGFloat = 1
            override var backingScaleFactor: CGFloat {
                renderScale
            }
        }

        static func run(arguments: [String]) throws {
            if arguments == ["--render-ui", "--help"] {
                print(UIRenderOptions.usage)
                return
            }
            // Validate the entire request before creating any AppKit objects or dependencies.
            let options = try UIRenderOptions.parse(arguments)
            let foregroundBefore = NSWorkspace.shared.frontmostApplication?.processIdentifier
            let app = NSApplication.shared
            guard app.setActivationPolicy(.prohibited), !app.isActive else {
                throw Failure(message: "The render process must remain inactive with activation prohibited.")
            }
            app.appearance = NSAppearance(named: options.appearance == .light ? .aqua : .darkAqua)
            NSTimeZone.default = TimeZone(secondsFromGMT: 0)!
            let session = try DebugOfflineSession(options: .init(
                state: DebugOfflineSession.State(rawValue: options.state.rawValue)!,
                screen: options.screen == .settings ? .settings : .main
            ))
            defer { session.removeDisposablePreferences() }
            let expectedCount = options.state == .loaded ? DebugOfflineSession.pullRequests.count : 0
            guard session.model.pullRequests.count == expectedCount else {
                throw Failure(message: "The requested pull request fixture was unexpectedly filtered out.")
            }
            try render(DebugOfflineRoot(session: session, section: options.section),
                       options: options, foregroundBefore: foregroundBefore)
        }

        private static func render<Content: View>(
            _ content: Content, options: UIRenderOptions, foregroundBefore: pid_t?
        ) throws {
            let size = NSSize(width: options.width, height: options.height)
            let view = content
                .environment(\.colorScheme, options.appearance == .light ? .light : .dark)
                .environment(\.controlActiveState, .active)
                .environment(\.locale, Locale(identifier: "en_US"))
                .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
                .environment(\.openURL, OpenURLAction { _ in
                    preconditionFailure("Opening URLs is forbidden during UI rendering.")
                })
                .transaction { $0.animation = nil }
                .frame(width: size.width, height: size.height)
                .background(Color(nsColor: .windowBackgroundColor))
            let hosting = NSHostingView(rootView: view)
            hosting.sizingOptions = []
            let window = RenderWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.borderless], backing: .buffered, defer: false
            )
            window.renderScale = CGFloat(options.scale)
            window.isReleasedWhenClosed = false
            window.animationBehavior = .none
            window.appearance = NSApp.appearance
            window.contentView = hosting
            hosting.frame = NSRect(origin: .zero, size: size)
            hosting.layoutSubtreeIfNeeded()
            // Native controls and lazy SwiftUI containers need a main-run-loop layout pass.
            RunLoop.main.run(until: Date().addingTimeInterval(0.25))
            hosting.layoutSubtreeIfNeeded()

            guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
                throw Failure(message: "Could not allocate the view bitmap.")
            }
            bitmap.size = size
            hosting.effectiveAppearance.performAsCurrentDrawingAppearance {
                hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
            }
            guard let png = bitmap.representation(using: .png, properties: [:]) else {
                throw Failure(message: "Could not encode the view PNG.")
            }
            let app = NSApplication.shared
            let visibleWindows = app.windows.filter(\.isVisible).count
            guard visibleWindows == 0, app.keyWindow == nil, !app.isActive,
                  app.activationPolicy() == .prohibited
            else {
                throw Failure(message: "UI rendering must not activate the process or show a window.")
            }
            try png.write(to: options.output, options: .atomic)
            let report = Report(
                output: options.output.path,
                pixelsWide: bitmap.pixelsWide,
                pixelsHigh: bitmap.pixelsHigh,
                visibleWindows: visibleWindows,
                applicationActive: app.isActive,
                activationProhibited: app.activationPolicy() == .prohibited,
                foregroundUnchanged: foregroundBefore == NSWorkspace.shared.frontmostApplication?.processIdentifier
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try print(String(decoding: encoder.encode(report), as: UTF8.self))
            // The window was never ordered, made key, or shown. Process exit releases the host.
            withExtendedLifetime(window) {}
        }
    }
#endif
