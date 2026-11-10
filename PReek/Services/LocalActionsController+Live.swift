#if os(macOS)
    import AppKit
    import Foundation

    @MainActor
    extension LocalActionsController {
        static let shared = LocalActionsController(
            defaults: .standard,
            dependencies: Dependencies(
                discoverEditors: { LocalEditor.discover() },
                chooseRepository: { key, reason, initialDirectory in
                    let panel = NSOpenPanel()
                    panel.title = String(localized: "Choose an existing local clone")
                    panel.message = [reason, String(localized: "Select your existing clone of \(key). PReek never clones repositories automatically.")]
                        .compactMap { $0 }.joined(separator: "\n\n")
                    panel.prompt = String(localized: "Use Clone")
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    panel.allowsMultipleSelection = false
                    panel.canCreateDirectories = false
                    panel.directoryURL = initialDirectory
                    NSApp.activate(ignoringOtherApps: true)
                    return panel.runModal() == .OK ? panel.url : nil
                },
                prepareWorkspace: { request, clone, root in
                    try await LocalWorkspaceService.shared.prepare(pullRequestURL: request, clone: clone, root: root) {
                        try await LocalPullRequestAPI.metadata(for: request)
                    }
                },
                registerWorkspace: { request, workspace in
                    try LocalActionsCleanup.shared.register(pullRequest: request, workspace: workspace)
                },
                openEditor: { editor, workspace in
                    _ = try await NSWorkspace.shared.open(
                        [workspace],
                        withApplicationAt: editor.applicationURL,
                        configuration: NSWorkspace.OpenConfiguration()
                    )
                },
                launchAgent: { action, pullRequestURL, workspace, executable in
                    try await LocalAgentLauncher.launch(action, pullRequestURL: pullRequestURL, workspace: workspace, executable: executable)
                },
                showError: { error in
                    let alert = NSAlert()
                    alert.alertStyle = .warning
                    alert.messageText = String(localized: "Could not complete local action")
                    alert.informativeText = error.localizedDescription
                    alert.addButton(withTitle: String(localized: "OK"))
                    NSApp.activate(ignoringOtherApps: true)
                    alert.runModal()
                },
                chooseWorkspaceUpdate: { warning in
                    let alert = NSAlert()
                    alert.alertStyle = .warning
                    alert.messageText = String(localized: "PR workspace update skipped")
                    alert.informativeText = warning
                    alert.addButton(withTitle: String(localized: "Open Unchanged"))
                    alert.addButton(withTitle: String(localized: "Force Update…"))
                    alert.addButton(withTitle: String(localized: "Cancel")).keyEquivalent = "\u{1b}"
                    NSApp.activate(ignoringOtherApps: true)
                    switch alert.runModal() {
                    case .alertFirstButtonReturn: return .openUnchanged
                    case .alertSecondButtonReturn: return .forceUpdate
                    default: return .cancel
                    }
                },
                confirmForceUpdate: { workspace in
                    let alert = NSAlert()
                    alert.alertStyle = .critical
                    alert.messageText = String(localized: "Discard all local workspace data?")
                    alert.informativeText = String(localized: "Before continuing, stop ALL processes using \(workspace.path), including editors, agents, builds, terminals, and Git operations. Force update removes and recreates this checkout at the latest PR revision. This deletes ALL uncommitted edits, staged changes, untracked and ignored files, local submodule data, unfinished Git operations, and worktree locks. The current committed HEAD is retained in a backup ref. This cannot be undone for uncommitted data.")
                    alert.addButton(withTitle: String(localized: "Cancel")).keyEquivalent = "\r"
                    alert.addButton(withTitle: String(localized: "Discard Local Data and Update")).hasDestructiveAction = true
                    NSApp.activate(ignoringOtherApps: true)
                    return alert.runModal() == .alertSecondButtonReturn
                },
                forceUpdateWorkspace: { request, workspace in
                    try await LocalWorkspaceService.shared.forceUpdate(pullRequestURL: request, workspace: workspace) {
                        try await LocalPullRequestAPI.metadata(for: request)
                    }
                }
            )
        )
    }
#endif
