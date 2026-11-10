#if os(macOS)
    import AppKit
    import SwiftUI

    /// A separate window remains usable when the MenuBarExtra popover dismisses.
    @MainActor
    final class LocalAgentPromptWindowController: NSWindowController, NSWindowDelegate {
        private static var openWindows: [UUID: LocalAgentPromptWindowController] = [:]
        private let windowID = UUID()
        private var launchTask: Task<Void, Never>?

        static func present(for pullRequest: PullRequest, actionCompleted: @escaping (Bool) -> Void) {
            let controller = LocalAgentPromptWindowController(pullRequest: pullRequest, actionCompleted: actionCompleted)
            openWindows[controller.windowID] = controller
            controller.showWindow(nil)
            controller.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }

        private init(pullRequest: PullRequest, actionCompleted: @escaping (Bool) -> Void) {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 650, height: 490),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Local agent — \(pullRequest.repository.name) #\(pullRequest.number)"
            window.minSize = NSSize(width: 520, height: 400)
            window.isReleasedWhenClosed = false
            super.init(window: window)
            window.delegate = self
            let content = NSHostingView(rootView: LocalAgentPromptEditor(pullRequest: pullRequest, launch: { [weak self] action, save, modifierPressed in
                self?.launch(action, for: pullRequest, save: save, modifierPressed: modifierPressed, actionCompleted: actionCompleted)
            }, close: { [weak self] in
                self?.close()
            }))
            content.sizingOptions = []
            window.contentView = content
            window.setContentSize(NSSize(width: 650, height: 490))
            window.center()
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            return nil
        }

        func windowWillClose(_: Foundation.Notification) {
            launchTask?.cancel()
            Self.openWindows.removeValue(forKey: windowID)
        }

        private func launch(
            _ action: LocalAgentAction,
            for pullRequest: PullRequest,
            save: Bool,
            modifierPressed: Bool,
            actionCompleted: @escaping (Bool) -> Void
        ) {
            guard launchTask == nil else { return }
            // The window owns preparation; either Cancel or the title-bar close cancels it.
            launchTask = Task { [weak self] in
                defer { self?.launchTask = nil }
                let localActions = LocalActionsController.shared
                guard await localActions.launch(.agent(action), for: pullRequest),
                      !Task.isCancelled else { return }
                if save {
                    localActions.agentActions.append(action)
                }
                actionCompleted(modifierPressed)
                self?.close()
            }
        }
    }

    @MainActor
    private struct LocalAgentPromptEditor: View {
        let pullRequest: PullRequest
        let launch: (LocalAgentAction, Bool, Bool) -> Void
        let close: () -> Void

        @ObservedObject private var localActions = LocalActionsController.shared
        @State private var prompt = ""
        @State private var saveAction = false
        @State private var name = ""

        private var canLaunch: Bool {
            !localActions.isPreparing(pullRequest)
                && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && (!saveAction || !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Custom prompt")
                    .font(.title2)
                Text("\(pullRequest.repository.name) #\(pullRequest.number): \(pullRequest.title)")
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
                TextEditor(text: $prompt)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 180)
                    .border(.secondary.opacity(0.3))
                    .accessibilityLabel("Agent prompt")
                Toggle("Save as a reusable action", isOn: $saveAction)
                if saveAction {
                    TextField("Action name", text: $name)
                        .textFieldStyle(.roundedBorder)
                }
                Text("Runs locally in Ghostty. Local changes are preserved unless you explicitly confirm Force Update. The agent is instructed not to push or post to GitHub.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    Button("Cancel", action: close)
                        .keyboardShortcut(.cancelAction)
                    Button(action: requestLaunch) {
                        if localActions.isPreparing(pullRequest) {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Open in Ghostty")
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canLaunch)
                }
            }
            .padding(20)
            .frame(width: 650, height: 490)
        }

        private func requestLaunch() {
            let shouldSave = saveAction
            let action = LocalAgentAction(
                name: shouldSave ? name.trimmingCharacters(in: .whitespacesAndNewlines) : "Custom prompt",
                prompt: prompt,
                kind: .custom
            )
            let modifierPressed = NSEvent.modifierFlags.contains(.command)
            launch(action, shouldSave, modifierPressed)
        }
    }
#endif
