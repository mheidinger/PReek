#if os(macOS)
    import SwiftUI

    @MainActor
    struct LocalActionsSettingsView: View {
        @ObservedObject private var localActions = LocalActionsController.shared
        @ObservedObject private var cleanup = LocalActionsCleanup.shared

        var body: some View {
            workspaceSettings
            agentSettings
            repositorySettings
        }

        private var workspaceSettings: some View {
            Section("Local actions") {
                TextField("Workspace root", text: $localActions.workspacePath)
                    .help("Persistent PR worktrees are created below this folder. An absolute path or ~/ is supported.")
                editorPicker
                Text("Installed supported editors are detected automatically and opened directly; no editor CLI installation is needed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Requires Git and a configured GitHub account. Agent actions also require Ghostty 1.3 or newer and OMP. PReek prepares the shared PR worktree before opening either application.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Automatically clean up worktrees", isOn: Binding(
                    get: { cleanup.enabled },
                    set: { cleanup.setEnabled($0) }
                ))
                Text("Removes unchanged worktrees after a PR has been closed, merged, or untracked for 24 hours. Checks after successful refreshes while PReek is running, including after enabling cleanup. Open editors and agents do not prevent cleanup; unsaved buffers are not protected.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .onAppear { localActions.refreshEditors() }
        }

        private var editorPicker: some View {
            Picker("Editor", selection: $localActions.selectedEditorID) {
                if localActions.selectedEditor == nil {
                    Text(localActions.selectedEditorID == nil ? "No installed editors found" : "Selected editor not installed")
                        .tag(localActions.selectedEditorID)
                }
                ForEach(localActions.installedEditors) { editor in
                    Label {
                        Text(editor.name)
                    } icon: {
                        Image(nsImage: editor.icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                    }
                    .tag(Optional(editor.id))
                }
            }
            .disabled(localActions.installedEditors.isEmpty)
        }

        private var agentSettings: some View {
            Section("Saved local agent actions") {
                TextField("OMP executable", text: $localActions.ompPath)
                    .help("The OMP executable path, normally /opt/homebrew/bin/omp, or a command on your login shell's PATH.")
                ForEach($localActions.agentActions) { $action in
                    DisclosureGroup(action.displayName) {
                        TextField("Action name", text: $action.name)
                        Text("Prompt")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $action.prompt)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 120)
                            .border(.secondary.opacity(0.3))
                            .accessibilityLabel("Prompt for \(action.name)")
                        if action.kind == .custom {
                            Button("Delete action", role: .destructive) {
                                localActions.removeAgentAction(id: action.id)
                            }
                        }
                    }
                }
                Button("Add action", systemImage: "plus") {
                    localActions.addAgentAction()
                }
                Text("Saved actions launch with one click from a pull request. Prompts are editable and saved automatically. All actions are instructed to preserve local changes and never push or post to GitHub.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        private var repositorySettings: some View {
            Section("Local action repositories") {
                if localActions.repositoryMappings.isEmpty {
                    Text("Choose an existing local clone the first time you launch an action for each repository. PReek never clones automatically.")
                        .foregroundStyle(.secondary)
                }
                ForEach(localActions.repositoryMappings.sorted(by: { $0.id < $1.id })) { mapping in
                    repositoryRow(mapping)
                }
                Text("Mappings are separate for each GitHub host and owner/repository. Forgetting a mapping does not delete its clone or any worktree. Clean worktrees update before opening. For local changes, choose Open Unchanged, Force Update, or Cancel. Confirming Force Update deletes all uncommitted workspace data, including ignored files and submodule data; the committed HEAD is backed up.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        private func repositoryRow(_ mapping: LocalRepositoryMapping) -> some View {
            VStack(alignment: .leading, spacing: 6) {
                Text(mapping.id)
                    .font(.headline)
                Text(mapping.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                HStack {
                    Button("Change folder…") {
                        localActions.changeRepositoryMapping(id: mapping.id)
                    }
                    Button("Forget mapping", role: .destructive) {
                        localActions.removeRepositoryMapping(id: mapping.id)
                    }
                }
            }
        }
    }
#endif
