#if os(macOS)
    import Combine
    import Foundation
    import OSLog

    /// Eligibility policy and conservative, non-forced Git worktree cleanup.
    @MainActor
    final class LocalActionsCleanup: ObservableObject {
        static let shared = LocalActionsCleanup()
        @Published private(set) var enabled: Bool
        let registry: LocalWorkspaceRegistry
        private let defaults: UserDefaults
        private var generation: UInt64 = 0
        private var cleaning = false
        private let logger = Logger(subsystem: "de.max-heidinger.PReek", category: "LocalActionsCleanup")

        init(registry: LocalWorkspaceRegistry? = nil, defaults: UserDefaults = .standard) {
            self.registry = registry ?? LocalWorkspaceRegistry()
            self.defaults = defaults
            enabled = defaults.bool(forKey: LocalActionsController.Preference.automaticCleanup.key)
        }

        func setEnabled(_ enabled: Bool) {
            defaults.set(enabled, forKey: LocalActionsController.Preference.automaticCleanup.key)
            self.enabled = enabled
            generation &+= 1
        }

        private var cleanupEnabled: Bool {
            enabled && defaults.bool(forKey: LocalActionsController.Preference.automaticCleanup.key)
        }

        func register(pullRequest: PullRequest, workspace: LocalWorkspaceService.PreparedWorkspace) throws {
            let identity = try LocalWorkspaceService.identity(for: pullRequest.url)
            let layout = workspace.layout
            let path = layout.workspace.path
            var next = registry.workspaces
            let index = next.firstIndex(where: { $0.workspace == path })
            let entry = LocalWorkspaceRegistry.Workspace(
                workspace: path,
                state: layout.state.path,
                clone: workspace.clone.path,
                pullRequest: identity.pullRequestKey,
                eligibleSince: pullRequest.isClosed
                    ? (index.flatMap { next[$0].eligibleSince } ?? Date().timeIntervalSince1970)
                    : nil
            )
            if let index {
                next[index] = entry
            } else {
                next.append(entry)
            }
            try save(next)
        }

        /// Called only after a successful complete refresh and canonical retention eviction.
        /// UI filters, missing incremental notifications, and failed refreshes never reach here.
        func updateTrackedPullRequests(_ pullRequests: [PullRequest], now: Date = Date()) {
            let tracked = Dictionary(pullRequests.compactMap { request -> (String, Bool)? in
                (try? LocalWorkspaceService.identity(for: request.url)).map { ($0.pullRequestKey, request.isClosed) }
            }, uniquingKeysWith: { $0 || $1 })
            var next = registry.workspaces
            for index in next.indices {
                let entry = next[index]
                if tracked[entry.pullRequest] == false {
                    next[index].eligibleSince = nil
                } else if entry.eligibleSince == nil {
                    next[index].eligibleSince = now.timeIntervalSince1970
                }
            }
            guard next != registry.workspaces else { return }
            do { try save(next) } catch {
                logger.error("Could not persist workspace cleanup eligibility: \(error.localizedDescription, privacy: .public)")
            }
        }

        func runIfNeeded(now: Date = Date()) {
            guard cleanupEnabled, !cleaning else { return }
            Task { await clean(now: now) }
        }

        /// Returns diagnostics for deterministic callers; never schedules background maintenance.
        @discardableResult
        func clean(now: Date = Date()) async -> [String] {
            guard cleanupEnabled, !cleaning, (try? registry.read()) != nil else { return [] }
            cleaning = true
            defer { cleaning = false }
            let snapshotGeneration = generation
            let entries = registry.workspaces
            var messages: [String] = []
            for entry in entries where Self.eligible(entry, now: now) {
                guard generation == snapshotGeneration, cleanupEnabled else { break }
                guard LocalWorkspaceSafety.exists(URL(fileURLWithPath: entry.workspace)) else { continue }
                do {
                    let (layout, identity) = try LocalWorkspaceSafety.Layout.validated(
                        workspace: entry.workspace,
                        state: entry.state,
                        clone: entry.clone,
                        pullRequest: entry.pullRequest
                    )
                    // Keep the stable-inode lock across inspection, revalidation, and removal.
                    let lock = try LocalWorkspaceLock(state: layout.state)
                    defer { withExtendedLifetime(lock) {} }
                    let inspection = try await Self.inspectWorkspace(
                        layout, clone: URL(fileURLWithPath: entry.clone), identity: identity
                    )
                    // Async Git inspection permits refreshes/toggles. Re-read the registry
                    // and marker immediately before non-forced removal, while still locked.
                    guard registryAllowsRemoval(
                        entry, entries: entries, generation: snapshotGeneration, now: now
                    ) else { continue }
                    _ = try LocalWorkspaceSafety.Layout.validated(
                        workspace: entry.workspace,
                        state: entry.state,
                        clone: entry.clone,
                        pullRequest: entry.pullRequest
                    )
                    try Self.checkState(layout.state)
                    guard try LocalWorkspaceSafety.preparedSHA(layout.state) == inspection.preparedSHA else {
                        throw LocalActionError(message: "The preparation marker changed during inspection.")
                    }
                    try await Self.removeWorkspace(
                        layout, clone: URL(fileURLWithPath: entry.clone), registration: inspection.registration,
                        common: inspection.common, branch: identity.branchReference
                    )
                    messages.append("Removed eligible workspace \(layout.workspace.path); its branch was retained.")
                } catch {
                    messages.append("Skipped \(entry.workspace): \(error.localizedDescription)")
                }
            }
            for message in messages {
                logger.info("\(message, privacy: .public)")
            }
            return messages
        }

        private static func inspectWorkspace(
            _ layout: LocalWorkspaceSafety.Layout,
            clone: URL,
            identity: LocalWorkspaceService.Identity
        ) async throws -> (preparedSHA: String, registration: URL, common: URL) {
            try checkState(layout.state)
            let prepared = try LocalWorkspaceSafety.preparedSHA(layout.state)
            let common = try await LocalWorkspaceSafety.validateClone(clone)
            try await LocalWorkspaceSafety.validateWorktree(layout.workspace, common: common, requireUnlocked: true)
            let branch = try await LocalWorkspaceSafety.git(layout.workspace, ["symbolic-ref", "-q", "HEAD"])
            guard branch == identity.branchReference,
                  try await LocalWorkspaceSafety.git(layout.workspace, ["rev-parse", "HEAD"]) == prepared
            else {
                throw LocalActionError(message: "The workspace has a different branch, checkout, or local commits.")
            }
            let registration = try await LocalWorkspaceSafety.gitPath(layout.workspace, "--absolute-git-dir")
            if let reason = try await LocalWorkspaceSafety.refreshWarning(layout.workspace, common: common) {
                throw LocalActionError(message: reason)
            }
            return (prepared, registration, common)
        }

        private func registryAllowsRemoval(
            _ entry: LocalWorkspaceRegistry.Workspace,
            entries: [LocalWorkspaceRegistry.Workspace],
            generation snapshotGeneration: UInt64,
            now: Date
        ) -> Bool {
            guard generation == snapshotGeneration, cleanupEnabled,
                  let current = try? registry.read() else { return false }
            return current.workspaces == entries
                && current.workspaces.contains(entry) && Self.eligible(entry, now: now)
        }

        private static func removeWorkspace(
            _ layout: LocalWorkspaceSafety.Layout,
            clone: URL,
            registration: URL,
            common: URL,
            branch: String
        ) async throws {
            // No additional await between the final metadata check and non-forced removal.
            if let reason = LocalWorkspaceSafety.operationWarning(registration: registration, common: common, branch: branch) {
                throw LocalActionError(message: reason)
            }
            // Git independently refuses dirty/locked worktrees. Never force; keep the branch.
            _ = try await LocalWorkspaceSafety.git(clone, ["worktree", "remove", "--", layout.workspace.path])
            let marker = layout.state.appendingPathComponent("prepared-sha")
            if LocalWorkspaceSafety.ownedFile(marker) {
                try FileManager.default.removeItem(at: marker)
            }
            try removeSessions(layout.state)
            // Retain the frozen workspace name and its state directory for recreation.
        }

        private static func eligible(_ entry: LocalWorkspaceRegistry.Workspace, now: Date) -> Bool {
            guard let since = entry.eligibleSince, since.isFinite, since >= 0 else { return false }
            return now.timeIntervalSince1970 - since >= 86400
        }

        private static func checkState(_ state: URL) throws {
            guard LocalWorkspaceSafety.ownedDirectory(state),
                  try Set(FileManager.default.contentsOfDirectory(atPath: state.path)).isSubset(of: ["prepared-sha", "sessions", "workspace-name"])
            else {
                throw LocalActionError(message: "The state directory contains unknown files.")
            }
            _ = try sessionFiles(state)
        }

        private static func sessionFiles(_ state: URL) throws -> [URL] {
            let sessions = state.appendingPathComponent("sessions", isDirectory: true)
            guard LocalWorkspaceSafety.exists(sessions) else { return [] }
            guard LocalWorkspaceSafety.ownedDirectory(sessions) else { throw LocalActionError(message: "The session directory is unsafe.") }
            let names = Set(LocalAgentSession.File.allCases.map(\.rawValue))
            var files: [URL] = []
            for session in try FileManager.default.contentsOfDirectory(at: sessions, includingPropertiesForKeys: nil) {
                guard UUID(uuidString: session.lastPathComponent) != nil, LocalWorkspaceSafety.ownedDirectory(session) else {
                    throw LocalActionError(message: "The session directory contains unknown data.")
                }
                for file in try FileManager.default.contentsOfDirectory(at: session, includingPropertiesForKeys: nil) {
                    guard names.contains(file.lastPathComponent), LocalWorkspaceSafety.ownedFile(file) else {
                        throw LocalActionError(message: "The session contains unknown or unsafe files.")
                    }
                    files.append(file)
                }
            }
            return files
        }

        private static func removeSessions(_ state: URL) throws {
            for file in try sessionFiles(state) {
                try FileManager.default.removeItem(at: file)
            }
            let sessions = state.appendingPathComponent("sessions", isDirectory: true)
            guard LocalWorkspaceSafety.ownedDirectory(sessions) else { return }
            for session in try FileManager.default.contentsOfDirectory(at: sessions, includingPropertiesForKeys: nil) {
                session.withUnsafeFileSystemRepresentation {
                    if let path = $0 {
                        _ = rmdir(path)
                    }
                }
            }
            sessions.withUnsafeFileSystemRepresentation {
                if let path = $0 {
                    _ = rmdir(path)
                }
            }
        }

        private func save(_ next: [LocalWorkspaceRegistry.Workspace]) throws {
            try registry.save(next)
            generation &+= 1
        }
    }
#endif
