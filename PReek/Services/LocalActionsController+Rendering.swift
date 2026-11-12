#if DEBUG && os(macOS)
    import AppKit
    import Foundation

    @MainActor
    extension LocalActionsController {
        /// The caller supplies disposable defaults; every external action is forbidden.
        static func rendering(defaults: UserDefaults) -> LocalActionsController {
            guard let icon = NSImage(systemSymbolName: "curlybraces", accessibilityDescription: "Fixture Editor") else {
                fatalError("Local actions rendering requires the curlybraces system symbol.")
            }
            let editor = LocalEditor(
                id: "invalid.preek.rendering.editor",
                name: "Fixture Editor",
                applicationURL: URL(fileURLWithPath: "/render.invalid/Applications/Fixture Editor.app"),
                icon: icon
            )
            let actions = [
                LocalAgentAction(
                    id: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
                    name: "Review PR",
                    prompt: "Review the pull request for correctness and maintainability. Report actionable findings without modifying files.",
                    kind: .review
                ),
                LocalAgentAction(
                    id: UUID(uuidString: "00000000-0000-4000-8000-000000000002")!,
                    name: "Address comments",
                    prompt: "Address unresolved review feedback while preserving local changes. Summarize changes and verification.",
                    kind: .address
                ),
                LocalAgentAction(
                    id: UUID(uuidString: "00000000-0000-4000-8000-000000000003")!,
                    name: "Explain changes",
                    prompt: "Explain the changes and their impact without modifying files or posting to GitHub.",
                    kind: .custom
                ),
            ]
            let mappings = [
                LocalRepositoryMapping(
                    id: "github.invalid/example/preek",
                    path: "/render.invalid/clones/example/preek"
                ),
            ]
            do {
                let encoder = JSONEncoder()
                try defaults.set(encoder.encode(actions), forKey: Preference.actions.key)
                try defaults.set(encoder.encode(mappings), forKey: Preference.repositoryMappings.key)
            } catch {
                fatalError("Could not encode local actions rendering fixtures: \(error)")
            }
            defaults.set("/render.invalid/workspaces", forKey: Preference.workspacePath.key)
            defaults.set("/render.invalid/bin/omp", forKey: Preference.ompPath.key)
            defaults.set(editor.id, forKey: Preference.editorID.key)
            defaults.set(false, forKey: Preference.automaticCleanup.key)

            return LocalActionsController(
                defaults: defaults,
                dependencies: Dependencies(
                    discoverEditors: { [editor] },
                    chooseRepository: { _, _, _ in
                        preconditionFailure("Repository pickers are forbidden during local actions rendering.")
                    },
                    prepareWorkspace: { _, _, _ in
                        preconditionFailure("Workspace preparation is forbidden during local actions rendering.")
                    },
                    registerWorkspace: { _, _ in
                        preconditionFailure("Workspace registration is forbidden during local actions rendering.")
                    },
                    openEditor: { _, _ in
                        preconditionFailure("Opening editors is forbidden during local actions rendering.")
                    },
                    launchAgent: { _, _, _, _ in
                        preconditionFailure("Launching agents is forbidden during local actions rendering.")
                    },
                    showError: { error in
                        preconditionFailure("Alerts are forbidden during local actions rendering: \(error)")
                    },
                    chooseWorkspaceUpdate: { _ in
                        preconditionFailure("Workspace update choices are forbidden during local actions rendering.")
                    },
                    confirmForceUpdate: { _ in
                        preconditionFailure("Destructive workspace confirmations are forbidden during local actions rendering.")
                    },
                    forceUpdateWorkspace: { _, _ in
                        preconditionFailure("Destructive workspace updates are forbidden during local actions rendering.")
                    }
                )
            )
        }
    }
#endif
