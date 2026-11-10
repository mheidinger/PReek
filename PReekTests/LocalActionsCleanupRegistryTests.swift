#if os(macOS)
    import Foundation
    import Testing

    @MainActor
    struct LocalActionsCleanupRegistryTests {
        private func request(_ status: PullRequest.Status = .open) -> PullRequest {
            PullRequest(id: "pr", repository: Repository(name: "owner/repo", url: URL(string: "https://github.com/owner/repo")!), author: User.preview(login: "author"), title: "PR", number: 7, status: status, lastUpdated: Date(), events: [], url: URL(string: "https://github.com/owner/repo/pull/7")!, additions: 0, deletions: 0, approvalFrom: [], changesRequestedFrom: [])
        }

        private func read(_ cleanup: LocalActionsCleanup) throws -> LocalWorkspaceRegistry.Snapshot {
            try cleanup.registry.read()
        }

        private func workspace(root: URL, clone: URL) throws -> LocalWorkspaceService.PreparedWorkspace {
            try LocalWorkspaceService.PreparedWorkspace(
                layout: LocalWorkspaceSafety.Layout(
                    root: root.resolvingSymlinksInPath(),
                    identity: LocalWorkspaceService.identity(for: request().url)
                ),
                clone: clone, headSHA: String(repeating: "a", count: 40), baseSHA: String(repeating: "b", count: 40)
            )
        }

        @Test func keepsOneEligibilityClockAcrossClosedMergedAndRemoved() throws {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let suite = "LocalActionsCleanupRegistryTests.\(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            defer { try? FileManager.default.removeItem(at: directory) }
            let cleanup = LocalActionsCleanup(registry: LocalWorkspaceRegistry(directory: directory), defaults: defaults)
            try cleanup.register(pullRequest: request(), workspace: workspace(root: directory.appendingPathComponent("worktrees"), clone: directory.appendingPathComponent("clone")))
            let first = Date(timeIntervalSince1970: 100_000)
            cleanup.updateTrackedPullRequests([request(.closed)], now: first)
            cleanup.updateTrackedPullRequests([request(.merged)], now: first.addingTimeInterval(100))
            cleanup.updateTrackedPullRequests([], now: first.addingTimeInterval(200))
            #expect(try read(cleanup).workspaces.first?.eligibleSince == first.timeIntervalSince1970)
            cleanup.updateTrackedPullRequests([request()], now: first.addingTimeInterval(300))
            #expect(try read(cleanup).workspaces.first?.eligibleSince == nil)
            cleanup.updateTrackedPullRequests([], now: first.addingTimeInterval(400))
            #expect(try read(cleanup).workspaces.first?.eligibleSince == first.addingTimeInterval(400).timeIntervalSince1970)
        }

        @Test func rootChangesKeepOldWorkspacesAndPersistEligibility() throws {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let suite = "LocalActionsCleanupRegistryTests.\(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            defer { try? FileManager.default.removeItem(at: directory) }
            let cleanup = LocalActionsCleanup(registry: LocalWorkspaceRegistry(directory: directory), defaults: defaults)
            let old = directory.appendingPathComponent("old")
            let new = directory.appendingPathComponent("new")
            let clone = directory.appendingPathComponent("clone")
            try cleanup.register(pullRequest: request(), workspace: workspace(root: old, clone: clone))
            try cleanup.register(pullRequest: request(), workspace: workspace(root: new, clone: clone))
            let now = Date(timeIntervalSince1970: 200_000)
            cleanup.updateTrackedPullRequests([], now: now)
            cleanup.setEnabled(true)
            let reloaded = LocalActionsCleanup(registry: LocalWorkspaceRegistry(directory: directory), defaults: defaults)
            let entries = try read(reloaded).workspaces
            #expect(reloaded.enabled)
            #expect(Set(entries.map(\.workspace)) == Set([old, new].map { $0.resolvingSymlinksInPath().appendingPathComponent("github.com/owner/repo/untitled--pr-7").path }))
            #expect(entries.allSatisfy { $0.eligibleSince == now.timeIntervalSince1970 })
        }
    }
#endif
