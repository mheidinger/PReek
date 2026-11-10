#if os(macOS)
    import AppKit
    import Combine
    import Foundation

    struct LocalRepositoryMapping: Codable, Identifiable, Equatable {
        var id: String
        var path: String
    }

    /// Owns shared preferences and workspace preparation for editor and agent actions.
    @MainActor
    final class LocalActionsController: ObservableObject {
        enum Destination {
            case editor
            case agent(LocalAgentAction)
        }

        /// Resolved before preparation so settings changes cannot switch the requested application.
        private enum Handoff {
            case editor(LocalEditor)
            case agent(LocalAgentAction, executable: String)
        }

        enum WorkspaceUpdateChoice {
            case openUnchanged, forceUpdate, cancel
        }

        /// Side-effect boundaries; production wiring lives in LocalActionsController+Live.
        struct Dependencies {
            var discoverEditors: () -> [LocalEditor]
            var chooseRepository: (_ key: String, _ reason: String?, _ initialDirectory: URL) -> URL?
            var prepareWorkspace: (_ pullRequest: URL, _ clone: URL, _ root: URL) async throws -> LocalWorkspaceService.PreparedWorkspace
            var registerWorkspace: (_ pullRequest: PullRequest, _ workspace: LocalWorkspaceService.PreparedWorkspace) async throws -> Void
            var openEditor: (_ editor: LocalEditor, _ workspace: URL) async throws -> Void
            var launchAgent: (_ action: LocalAgentAction, _ pullRequestURL: URL, _ workspace: LocalWorkspaceService.PreparedWorkspace, _ executable: String) async throws -> Void
            var showError: (Error) -> Void
            var chooseWorkspaceUpdate: (String) -> WorkspaceUpdateChoice
            var confirmForceUpdate: (URL) -> Bool
            var forceUpdateWorkspace: (URL, LocalWorkspaceService.PreparedWorkspace) async throws -> LocalWorkspaceService.PreparedWorkspace
        }

        @Published var agentActions: [LocalAgentAction] {
            didSet { persist(agentActions, key: .actions) }
        }

        @Published var workspacePath: String {
            didSet { defaults.set(workspacePath, forKey: Preference.workspacePath.key) }
        }

        @Published var ompPath: String {
            didSet { defaults.set(ompPath, forKey: Preference.ompPath.key) }
        }

        @Published var selectedEditorID: String? {
            didSet { defaults.set(selectedEditorID, forKey: Preference.editorID.key) }
        }

        @Published private(set) var installedEditors: [LocalEditor]
        @Published private(set) var repositoryMappings: [LocalRepositoryMapping] {
            didSet { persist(repositoryMappings, key: .repositoryMappings) }
        }

        @Published private(set) var preparingPullRequests: Set<URL> = []

        private let defaults: UserDefaults

        private let dependencies: Dependencies

        init(defaults: UserDefaults, dependencies: Dependencies) {
            self.defaults = defaults
            self.dependencies = dependencies
            Preference.migrate(in: defaults)
            agentActions = Self.decode([LocalAgentAction].self, from: defaults, key: .actions) ?? LocalAgentAction.defaults
            repositoryMappings = Self.decode([LocalRepositoryMapping].self, from: defaults, key: .repositoryMappings) ?? []
            workspacePath = defaults.string(forKey: Preference.workspacePath.key)
                ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".preek").path
            ompPath = defaults.string(forKey: Preference.ompPath.key) ?? "/opt/homebrew/bin/omp"
            installedEditors = dependencies.discoverEditors()
            selectedEditorID = LocalEditor.preferredID(
                savedID: defaults.string(forKey: Preference.editorID.key),
                installedIDs: installedEditors.map(\.id)
            )
        }

        var selectedEditor: LocalEditor? {
            installedEditors.first { $0.id == selectedEditorID }
        }

        var editorActionTitle: String {
            selectedEditor.map { "Open in \($0.name)" } ?? "Editor unavailable"
        }

        func refreshEditors() {
            installedEditors = dependencies.discoverEditors()
            selectedEditorID = LocalEditor.preferredID(savedID: selectedEditorID, installedIDs: installedEditors.map(\.id))
        }

        func addAgentAction() {
            agentActions.append(LocalAgentAction(name: "Custom action", prompt: "", kind: .custom))
        }

        func removeAgentAction(id: UUID) {
            agentActions.removeAll { $0.id == id && $0.kind == .custom }
        }

        func removeRepositoryMapping(id: String) {
            repositoryMappings.removeAll { $0.id == id }
        }

        func changeRepositoryMapping(id: String) {
            _ = chooseRepository(for: id)
        }

        func isPreparing(_ pullRequest: PullRequest) -> Bool {
            preparingPullRequests.contains(pullRequest.url)
        }

        @discardableResult
        func launch(_ destination: Destination, for pullRequest: PullRequest) async -> Bool {
            guard preparingPullRequests.insert(pullRequest.url).inserted else { return false }
            defer { preparingPullRequests.remove(pullRequest.url) }
            // Let SwiftUI display the busy state before validation or a folder picker.
            await Task.yield()

            do {
                try Task.checkCancellation()
                let handoff = try resolve(destination)
                guard var workspace = try await prepareWorkspace(for: pullRequest) else { return false }
                try Task.checkCancellation()
                if let warning = workspace.updateWarning {
                    let choice = dependencies.chooseWorkspaceUpdate(warning)
                    try Task.checkCancellation()
                    switch choice {
                    case .cancel:
                        return false
                    case .openUnchanged:
                        break
                    case .forceUpdate:
                        guard dependencies.confirmForceUpdate(workspace.url) else { return false }
                        try Task.checkCancellation()
                        workspace = try await dependencies.forceUpdateWorkspace(pullRequest.url, workspace)
                        try Task.checkCancellation()
                    }
                }
                switch handoff {
                case let .editor(editor):
                    try await dependencies.openEditor(editor, workspace.url)
                case let .agent(action, executable):
                    try await dependencies.launchAgent(action, pullRequest.url, workspace, executable)
                }
                try Task.checkCancellation()
                return true
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return false }
                dependencies.showError(error)
                return false
            }
        }

        private func resolve(_ destination: Destination) throws -> Handoff {
            switch destination {
            case .editor:
                guard let editor = selectedEditor else {
                    throw LocalActionError(message: "Select an installed editor in Settings → Local actions.")
                }
                return .editor(editor)
            case let .agent(action):
                guard action.hasPrompt else {
                    throw LocalActionError(message: "Enter a prompt for this action in Settings before launching it.")
                }
                let program = ompPath.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !program.isEmpty else {
                    throw LocalActionError(message: "Enter the OMP executable path in Settings.")
                }
                let executable = program.hasPrefix("~") ? try expandedAbsolutePath(program, label: "OMP executable") : program
                return .agent(action, executable: executable)
            }
        }

        private func prepareWorkspace(for pullRequest: PullRequest) async throws -> LocalWorkspaceService.PreparedWorkspace? {
            let identity = try LocalWorkspaceService.identity(for: pullRequest.url)
            let root = try URL(fileURLWithPath: expandedAbsolutePath(workspacePath, label: "Workspace root"), isDirectory: true)
            var candidate = repositoryMappings.first(where: { $0.id == identity.repositoryKey })
                .map { URL(fileURLWithPath: $0.path, isDirectory: true) }
                ?? chooseRepository(for: identity.repositoryKey)

            while let clone = candidate {
                try Task.checkCancellation()
                let workspace: LocalWorkspaceService.PreparedWorkspace
                do {
                    workspace = try await dependencies.prepareWorkspace(pullRequest.url, clone, root)
                } catch let error as LocalWorkspaceService.InvalidRepository {
                    try Task.checkCancellation()
                    removeRepositoryMapping(id: identity.repositoryKey)
                    candidate = chooseRepository(for: identity.repositoryKey, reason: error.localizedDescription)
                    continue
                }
                try Task.checkCancellation()
                try await dependencies.registerWorkspace(pullRequest, workspace)
                try Task.checkCancellation()
                return workspace
            }
            return nil
        }

        private func chooseRepository(for key: String, reason: String? = nil) -> URL? {
            let initialDirectory = repositoryMappings.first(where: { $0.id == key })
                .map { URL(fileURLWithPath: $0.path, isDirectory: true) }
                ?? FileManager.default.homeDirectoryForCurrentUser
            guard let url = dependencies.chooseRepository(key, reason, initialDirectory) else { return nil }

            let canonicalURL = url.resolvingSymlinksInPath()
            let mapping = LocalRepositoryMapping(id: key, path: canonicalURL.path)
            if let index = repositoryMappings.firstIndex(where: { $0.id == key }) {
                repositoryMappings[index] = mapping
            } else {
                repositoryMappings.append(mapping)
            }
            return canonicalURL
        }

        private func expandedAbsolutePath(_ path: String, label: String) throws -> String {
            let value = path.trimmingCharacters(in: .whitespacesAndNewlines)
            let expanded = (value as NSString).expandingTildeInPath
            guard expanded.hasPrefix("/"), !expanded.contains("\0") else {
                throw LocalActionError(message: "\(label) must be an absolute path or begin with ~/.")
            }
            return expanded
        }

        enum Preference: String {
            case actions, workspacePath, ompPath, editorID, repositoryMappings, automaticCleanup

            var key: String {
                "localActions.\(rawValue)"
            }

            /// One-time cutover; preserve existing choices without retaining old preference aliases.
            static func migrate(in defaults: UserDefaults) {
                for preference in [Preference.actions, .workspacePath, .ompPath, .editorID, .repositoryMappings] {
                    let oldKey = "localAgent.\(preference.rawValue)"
                    if defaults.object(forKey: preference.key) == nil, let value = defaults.object(forKey: oldKey) {
                        defaults.set(value, forKey: preference.key)
                    }
                    defaults.removeObject(forKey: oldKey)
                }
            }
        }

        private func persist(_ value: some Encodable, key: Preference) {
            if let data = try? JSONEncoder().encode(value) {
                defaults.set(data, forKey: key.key)
            }
        }

        private static func decode<T: Decodable>(_ type: T.Type, from defaults: UserDefaults, key: Preference) -> T? {
            defaults.data(forKey: key.key).flatMap { try? JSONDecoder().decode(type, from: $0) }
        }
    }
#endif
