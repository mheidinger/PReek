#if os(macOS)
    import Foundation
    import Testing

    @MainActor
    struct LocalActionsCleanupTests {
        @MainActor
        private final class Fixture {
            let directory: URL
            let clone: URL
            let root: URL
            let support: URL
            let initial: String
            let now = Date(timeIntervalSince1970: 200_000)
            var cleanup: LocalActionsCleanup
            var number = 0
            let authority: String
            let suite = "LocalActionsCleanupTests.\(UUID().uuidString)"
            let defaults: UserDefaults

            init(authority: String = "fixture.invalid") async throws {
                self.authority = authority
                let scratch = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
                directory = try LocalWorkspaceSafety.physicalURL(scratch)
                clone = directory.appendingPathComponent("clone")
                root = directory.appendingPathComponent("worktrees with spaces ' \" and literal $(touch NEVER_EXECUTE)")
                support = directory.appendingPathComponent("support")
                defaults = UserDefaults(suiteName: suite)!
                cleanup = LocalActionsCleanup(registry: LocalWorkspaceRegistry(directory: support), defaults: defaults)
                _ = try await LocalCommand.checked("/usr/bin/git", ["init", "-b", "main", clone.path])
                _ = try await Self.git(clone, ["config", "user.name", "Fixture"])
                _ = try await Self.git(clone, ["config", "user.email", "fixture@example.invalid"])
                try Data("original\n".utf8).write(to: clone.appendingPathComponent("tracked.txt"))
                try Data("ignored/\n".utf8).write(to: clone.appendingPathComponent(".gitignore"))
                _ = try await Self.git(clone, ["add", "tracked.txt", ".gitignore"])
                _ = try await Self.git(clone, ["commit", "-m", "initial"])
                initial = try await Self.git(clone, ["rev-parse", "HEAD"])
                cleanup.setEnabled(true)
            }

            func remove() {
                defaults.removePersistentDomain(forName: suite)
                try? FileManager.default.removeItem(at: directory)
            }

            static func git(_ directory: URL, _ arguments: [String]) async throws -> String {
                try await LocalCommand.checked("/usr/bin/git", arguments, directory: directory,
                                               environment: ["GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": "/dev/null"])
                    .trimmingCharacters(in: .newlines)
            }

            func addWorkspace() async throws -> LocalWorkspaceRegistry.Workspace {
                number += 1
                let identity = try LocalWorkspaceService.identity(for: request().url)
                let layout = LocalWorkspaceSafety.Layout(root: root, identity: identity)
                let workspace = layout.workspace
                let state = layout.state
                try FileManager.default.createDirectory(at: state, withIntermediateDirectories: true)
                try FileManager.default.createDirectory(at: workspace.deletingLastPathComponent(), withIntermediateDirectories: true)
                _ = try await Self.git(clone, ["worktree", "add", "-b", "preek/" + identity.referenceSuffix, workspace.path, initial])
                try Data((initial + "\n").utf8).write(to: state.appendingPathComponent("prepared-sha"))
                try Data(layout.workspace.lastPathComponent.utf8).write(to: state.appendingPathComponent("workspace-name"))
                try cleanup.register(pullRequest: request(), workspace: LocalWorkspaceService.PreparedWorkspace(
                    layout: layout, clone: clone, headSHA: initial, baseSHA: initial
                ))
                cleanup.updateTrackedPullRequests([], now: now.addingTimeInterval(-86400))
                return try #require(configuration().workspaces.last)
            }

            /// Uses the production fetch/preparation path against a local bare remote.
            func prepareWorkspace(title: String = "Untitled") async throws -> LocalWorkspaceService.PreparedWorkspace {
                number += 1
                let remote = directory.appendingPathComponent("remote.git")
                _ = try await Self.git(directory, ["init", "--bare", remote.path])
                _ = try await Self.git(clone, ["push", remote.path, "\(initial):refs/heads/main", "\(initial):refs/pull/\(number)/head"])
                _ = try await Self.git(clone, ["remote", "add", "origin", "git@fixture.invalid:owner/repo.git"])
                let ssh = directory.appendingPathComponent("ssh-fixture")
                try Data("#!/bin/sh\nexec /usr/bin/git upload-pack '\(remote.path)'\n".utf8).write(to: ssh)
                try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: ssh.path)
                _ = try await Self.git(clone, ["config", "core.sshCommand", ssh.path])
                let metadata = LocalWorkspaceService.Metadata(headSHA: initial, baseSHA: initial, title: title)
                let prepared = try await LocalWorkspaceService.shared.prepare(
                    pullRequestURL: request().url, clone: clone, root: root
                ) { metadata }
                try cleanup.register(pullRequest: request(), workspace: prepared)
                cleanup.updateTrackedPullRequests([], now: now.addingTimeInterval(-86400))
                return prepared
            }

            func request() -> PullRequest {
                PullRequest(id: "pr-\(number)", repository: Repository(name: "owner/repo", url: URL(string: "https://\(authority)/owner/repo")!), author: User.preview(login: "author"), title: "PR", number: number, status: .open, lastUpdated: now, events: [], url: URL(string: "https://\(authority)/owner/repo/pull/\(number)")!, additions: 0, deletions: 0, approvalFrom: [], changesRequestedFrom: [])
            }

            func configuration() throws -> LocalWorkspaceRegistry.Snapshot {
                try cleanup.registry.read()
            }

            func rewrite(_ transform: (inout LocalWorkspaceRegistry.Snapshot) -> Void) throws {
                var next = try configuration()
                transform(&next)
                try cleanup.registry.save(next.workspaces)
                cleanup = LocalActionsCleanup(registry: LocalWorkspaceRegistry(directory: support), defaults: defaults)
            }

            func expectWorkspaceDirectoriesExist(_ entry: LocalWorkspaceRegistry.Workspace) {
                #expect(FileManager.default.fileExists(atPath: entry.workspace))
                #expect(FileManager.default.fileExists(atPath: entry.state))
            }
        }

        @Test func cleanupRetainsFrozenNameForRecreation() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let first = try await fixture.prepareWorkspace(title: "Fix refunds")
            _ = await fixture.cleanup.clean(now: fixture.now)
            #expect(!LocalWorkspaceSafety.exists(first.url))
            let metadata = LocalWorkspaceService.Metadata(headSHA: fixture.initial, baseSHA: fixture.initial, title: "Changed title")
            let recreated = try await LocalWorkspaceService.shared.prepare(
                pullRequestURL: fixture.request().url, clone: fixture.clone, root: fixture.root
            ) { metadata }
            #expect(recreated.url == first.url)
            #expect(recreated.url.lastPathComponent == "fix-refunds--pr-1")
            #expect(try await Fixture.git(recreated.url, ["rev-parse", "HEAD"]) == fixture.initial)
        }

        @Test(arguments: ["young", "fractionally-young", "future", "active", "disabled"])
        func preservesIneligibleWorkspaces(_ scenario: String) async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let entry = try await fixture.addWorkspace()
            try fixture.rewrite { config in
                switch scenario {
                case "young": config.workspaces[0].eligibleSince = fixture.now.timeIntervalSince1970 - 86000
                case "fractionally-young": config.workspaces[0].eligibleSince = fixture.now.timeIntervalSince1970 - 86399.75
                case "future": config.workspaces[0].eligibleSince = fixture.now.timeIntervalSince1970 + 86400
                case "active": config.workspaces[0].eligibleSince = nil
                default: fixture.cleanup.setEnabled(false)
                }
            }
            #expect(await fixture.cleanup.clean(now: fixture.now).isEmpty)
            fixture.expectWorkspaceDirectoriesExist(entry)
        }

        @Test func removesAtBoundaryRetainsBranchAndReusesStableLock() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let entry = try await fixture.addWorkspace()
            let workspace = URL(fileURLWithPath: entry.workspace)
            let state = URL(fileURLWithPath: entry.state)
            let branch = "refs/heads/preek/fixture.invalid/owner/repo/pr-1"
            let session = state.appendingPathComponent("sessions/\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: session, withIntermediateDirectories: true)
            for file in LocalAgentSession.File.allCases {
                try Data("generated context".utf8).write(to: session.appendingPathComponent(file.rawValue))
            }
            _ = await fixture.cleanup.clean(now: fixture.now)
            #expect(!FileManager.default.fileExists(atPath: workspace.path))
            #expect(!FileManager.default.fileExists(atPath: state.appendingPathComponent("prepared-sha").path))
            #expect(!FileManager.default.fileExists(atPath: session.path))
            #expect(FileManager.default.fileExists(atPath: state.appendingPathExtension("operation-lock").path))
            #expect(try await Fixture.git(fixture.clone, ["rev-parse", branch]) == fixture.initial)
            #expect(await fixture.cleanup.clean(now: fixture.now).isEmpty)
            _ = try await Fixture.git(fixture.clone, ["worktree", "add", workspace.path, String(branch.dropFirst("refs/heads/".count))])
            try FileManager.default.createDirectory(at: state, withIntermediateDirectories: true)
            try Data((fixture.initial + "\n").utf8).write(to: state.appendingPathComponent("prepared-sha"))
            _ = await fixture.cleanup.clean(now: fixture.now.addingTimeInterval(0.25))
            #expect(!FileManager.default.fileExists(atPath: workspace.path))
            #expect(!FileManager.default.fileExists(atPath: fixture.directory.appendingPathComponent("NEVER_EXECUTE").path))
        }

        @Test(arguments: ["fixture.invalid:8443", "fixture.invalid:443"])
        func removesWorkspaceWithExplicitHTTPSPort(_ authority: String) async throws {
            let fixture = try await Fixture(authority: authority)
            defer { fixture.remove() }
            let entry = try await fixture.addWorkspace()
            let identity = try LocalWorkspaceService.identity(for: fixture.request().url)
            #expect(URL(fileURLWithPath: entry.workspace).lastPathComponent == "untitled--pr-1")
            #expect(entry.state.hasSuffix("/\(identity.suffix)"))
            let messages = await fixture.cleanup.clean(now: fixture.now)
            #expect(messages.contains { $0.hasPrefix("Removed eligible workspace ") })
            #expect(!FileManager.default.fileExists(atPath: entry.workspace))
            let state = URL(fileURLWithPath: entry.state)
            #expect(!LocalWorkspaceSafety.exists(state.appendingPathComponent("prepared-sha")))
            #expect(try await Fixture.git(fixture.clone, ["rev-parse", "refs/heads/preek/" + identity.referenceSuffix]) == fixture.initial)
        }

        @Test(arguments: ["modified", "untracked", "ignored", "staged", "local-commit", "assume-unchanged", "skip-worktree", "submodule", "foreign-branch", "detached", "git-locked"])
        func preservesGitDataAndOwnership(_ scenario: String) async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let entry = try await fixture.addWorkspace()
            let workspace = URL(fileURLWithPath: entry.workspace)
            let state = URL(fileURLWithPath: entry.state)
            let tracked = workspace.appendingPathComponent("tracked.txt")
            switch scenario {
            case "modified", "staged", "local-commit":
                try Data("local change\n".utf8).write(to: tracked)
                if scenario == "staged" {
                    _ = try await Fixture.git(workspace, ["add", "tracked.txt"])
                }
                if scenario == "local-commit" {
                    _ = try await Fixture.git(workspace, ["commit", "-am", "local-only"])
                }
            case "untracked": try Data("user data\n".utf8).write(to: workspace.appendingPathComponent("untracked.txt"))
            case "ignored":
                try FileManager.default.createDirectory(at: workspace.appendingPathComponent("ignored"), withIntermediateDirectories: true)
                try Data("private data\n".utf8).write(to: workspace.appendingPathComponent("ignored/private.txt"))
            case "assume-unchanged", "skip-worktree":
                _ = try await Fixture.git(workspace, ["update-index", "--" + scenario, "tracked.txt"])
                try Data("hidden local data\n".utf8).write(to: tracked)
            case "submodule":
                _ = try await Fixture.git(workspace, ["update-index", "--add", "--cacheinfo", "160000,\(fixture.initial),module"])
                _ = try await Fixture.git(workspace, ["commit", "-m", "fixture submodule"])
                let head = try await Fixture.git(workspace, ["rev-parse", "HEAD"])
                try Data((head + "\n").utf8).write(to: state.appendingPathComponent("prepared-sha"))
            case "foreign-branch": _ = try await Fixture.git(workspace, ["branch", "-m", "user-owned-branch"])
            case "detached": _ = try await Fixture.git(workspace, ["checkout", "--detach"])
            default: _ = try await Fixture.git(fixture.clone, ["worktree", "lock", "--reason", "in use", workspace.path])
            }
            let head = try await Fixture.git(workspace, ["rev-parse", "HEAD"])
            let data = try Data(contentsOf: tracked)
            _ = await fixture.cleanup.clean(now: fixture.now)
            fixture.expectWorkspaceDirectoriesExist(entry)
            #expect(try Data(contentsOf: tracked) == data)
            #expect(try await Fixture.git(workspace, ["rev-parse", "HEAD"]) == head)
            if scenario == "untracked" {
                #expect(try String(contentsOf: workspace.appendingPathComponent("untracked.txt"), encoding: .utf8) == "user data\n")
            } else if scenario == "ignored" {
                #expect(try String(contentsOf: workspace.appendingPathComponent("ignored/private.txt"), encoding: .utf8) == "private data\n")
            }
        }

        @Test(arguments: ["merge", "bisect"])
        func preparedRegisteredWorkspaceSurvivesOperationThenCleansAfterAbort(_ operation: String) async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let prepared = try await fixture.prepareWorkspace()
            let entry = try #require(fixture.configuration().workspaces.last)
            let registration = try URL(fileURLWithPath: await Fixture.git(prepared.url, ["rev-parse", "--absolute-git-dir"]))
            let marker: URL
            let abort: [String]
            if operation == "merge" {
                // An empty side commit makes MERGE_HEAD the only non-clean state:
                // unchanged HEAD, clean index, and clean tracked/untracked files.
                _ = try await Fixture.git(fixture.clone, ["checkout", "-b", "side"])
                _ = try await Fixture.git(fixture.clone, ["commit", "--allow-empty", "-m", "empty side"])
                _ = try await Fixture.git(fixture.clone, ["checkout", "main"])
                _ = try await Fixture.git(prepared.url, ["merge", "--no-ff", "--no-commit", "side"])
                marker = registration.appendingPathComponent("MERGE_HEAD")
                abort = ["merge", "--abort"]
            } else {
                _ = try await Fixture.git(prepared.url, ["bisect", "start"])
                marker = registration.appendingPathComponent("BISECT_START")
                abort = ["bisect", "reset"]
            }
            #expect(try await Fixture.git(prepared.url, ["rev-parse", "HEAD"]) == prepared.headSHA)
            #expect(try await Fixture.git(prepared.url, ["status", "--porcelain", "--untracked-files=all"]).isEmpty)
            let operationData = try Data(contentsOf: marker)
            _ = await fixture.cleanup.clean(now: fixture.now)
            fixture.expectWorkspaceDirectoriesExist(entry)
            #expect(try Data(contentsOf: marker) == operationData)
            if operation == "merge" {
                #expect(LocalWorkspaceSafety.exists(registration.appendingPathComponent("MERGE_MSG")))
            }
            _ = try await Fixture.git(prepared.url, abort)
            #expect(!LocalWorkspaceSafety.exists(marker))
            _ = await fixture.cleanup.clean(now: fixture.now)
            #expect(!LocalWorkspaceSafety.exists(prepared.url))
            #expect(!LocalWorkspaceSafety.exists(prepared.state.appendingPathComponent("prepared-sha")))
            #expect(try await Fixture.git(fixture.clone, ["rev-parse", "refs/heads/preek/fixture.invalid/owner/repo/pr-1"]) == fixture.initial)
        }

        @Test(arguments: [
            "locked", "index.lock", "HEAD.lock", "MERGE_HEAD", "MERGE_AUTOSTASH", "AUTO_MERGE",
            "CHERRY_PICK_HEAD", "REVERT_HEAD", "REBASE_HEAD", "SQUASH_MSG",
            "sequencer", "rebase-merge", "rebase-apply", "BISECT_LOG", "BISECT_START",
        ])
        func preservesCleanWorktreeWithOperationMetadata(_ name: String) async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let entry = try await fixture.addWorkspace()
            let workspace = URL(fileURLWithPath: entry.workspace)
            let registration = try URL(fileURLWithPath: await Fixture.git(workspace, ["rev-parse", "--absolute-git-dir"]))
            let marker = registration.appendingPathComponent(name)
            let dataFile: URL
            if ["sequencer", "rebase-merge", "rebase-apply"].contains(name) {
                try FileManager.default.createDirectory(at: marker, withIntermediateDirectories: false)
                dataFile = marker.appendingPathComponent("todo")
            } else {
                dataFile = marker
            }
            let data = Data((fixture.initial + "\n").utf8)
            try data.write(to: dataFile)
            _ = await fixture.cleanup.clean(now: fixture.now)
            fixture.expectWorkspaceDirectoriesExist(entry)
            #expect(try Data(contentsOf: dataFile) == data)
            try FileManager.default.removeItem(at: marker)
            _ = await fixture.cleanup.clean(now: fixture.now)
            #expect(!LocalWorkspaceSafety.exists(workspace))
        }

        @Test(arguments: ["index.lock", "HEAD.lock", "packed-refs.lock", "refs/heads/preek/fixture.invalid/owner/repo/pr-1.lock"])
        func preservesCleanWorkspaceWithSharedGitLocks(_ name: String) async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let entry = try await fixture.addWorkspace()
            let lock = fixture.clone.appendingPathComponent(".git").appendingPathComponent(name)
            try FileManager.default.createDirectory(at: lock.deletingLastPathComponent(), withIntermediateDirectories: true)
            let bytes = Data("shared operation owns this lock\n".utf8)
            try bytes.write(to: lock)
            _ = await fixture.cleanup.clean(now: fixture.now)
            fixture.expectWorkspaceDirectoriesExist(entry)
            #expect(try Data(contentsOf: lock) == bytes)
            #expect(try await Fixture.git(URL(fileURLWithPath: entry.workspace), ["rev-parse", "HEAD"]) == fixture.initial)
            try FileManager.default.removeItem(at: lock)
            _ = await fixture.cleanup.clean(now: fixture.now)
            #expect(!LocalWorkspaceSafety.exists(URL(fileURLWithPath: entry.workspace)))
        }

        @Test func preservesUnknownStateFileBytes() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let entry = try await fixture.addWorkspace()
            let file = URL(fileURLWithPath: entry.state).appendingPathComponent("keep-me")
            try Data("keep me".utf8).write(to: file)
            _ = await fixture.cleanup.clean(now: fixture.now)
            fixture.expectWorkspaceDirectoriesExist(entry)
            #expect(try String(contentsOf: file, encoding: .utf8) == "keep me")
        }

        @Test func preservesPendingPreparationJournalBytes() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let entry = try await fixture.addWorkspace()
            let file = URL(fileURLWithPath: entry.state).appendingPathComponent("pending-preparation")
            try Data("incomplete preparation".utf8).write(to: file)
            _ = await fixture.cleanup.clean(now: fixture.now)
            fixture.expectWorkspaceDirectoriesExist(entry)
            #expect(try String(contentsOf: file, encoding: .utf8) == "incomplete preparation")
        }

        @Test func refusesMissingPreparationMarker() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let entry = try await fixture.addWorkspace()
            try FileManager.default.removeItem(at: URL(fileURLWithPath: entry.state).appendingPathComponent("prepared-sha"))
            _ = await fixture.cleanup.clean(now: fixture.now)
            fixture.expectWorkspaceDirectoriesExist(entry)
        }

        @Test func preservesMalformedPreparationMarker() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let entry = try await fixture.addWorkspace()
            let marker = URL(fileURLWithPath: entry.state).appendingPathComponent("prepared-sha")
            try Data("not a SHA\n".utf8).write(to: marker)
            _ = await fixture.cleanup.clean(now: fixture.now)
            fixture.expectWorkspaceDirectoriesExist(entry)
            #expect(try String(contentsOf: marker, encoding: .utf8) == "not a SHA\n")
        }

        @Test func refusesSymlinkPreparationMarkerAndPreservesTarget() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let entry = try await fixture.addWorkspace()
            let marker = URL(fileURLWithPath: entry.state).appendingPathComponent("prepared-sha")
            let saved = fixture.directory.appendingPathComponent("saved-preparation")
            let bytes = try Data(contentsOf: marker)
            try FileManager.default.moveItem(at: marker, to: saved)
            try FileManager.default.createSymbolicLink(at: marker, withDestinationURL: saved)
            _ = await fixture.cleanup.clean(now: fixture.now)
            fixture.expectWorkspaceDirectoriesExist(entry)
            #expect(try Data(contentsOf: saved) == bytes)
        }

        @Test func refusesSymlinkWorkspaceRoot() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let entry = try await fixture.addWorkspace()
            let alias = fixture.directory.appendingPathComponent("aliased-root")
            try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: fixture.root)
            try fixture.rewrite { config in
                config.workspaces[0] = LocalWorkspaceRegistry.Workspace(
                    workspace: alias.appendingPathComponent("fixture.invalid/owner/repo/untitled--pr-1").path,
                    state: alias.appendingPathComponent(".preek-state/fixture.invalid/owner/repo/pr-1").path,
                    clone: entry.clone, pullRequest: entry.pullRequest, eligibleSince: entry.eligibleSince
                )
            }
            _ = await fixture.cleanup.clean(now: fixture.now)
            fixture.expectWorkspaceDirectoriesExist(entry)
        }

        @Test func refusesForeignClone() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let entry = try await fixture.addWorkspace()
            let foreign = fixture.directory.appendingPathComponent("foreign")
            _ = try await LocalCommand.checked("/usr/bin/git", ["init", "-b", "main", foreign.path])
            try fixture.rewrite { config in
                config.workspaces[0] = LocalWorkspaceRegistry.Workspace(
                    workspace: entry.workspace, state: entry.state, clone: foreign.path,
                    pullRequest: entry.pullRequest, eligibleSince: entry.eligibleSince
                )
            }
            _ = await fixture.cleanup.clean(now: fixture.now)
            fixture.expectWorkspaceDirectoriesExist(entry)
        }

        @Test func refusesForeignStateAndPreservesItsMarker() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let entry = try await fixture.addWorkspace()
            let foreign = fixture.directory.appendingPathComponent("foreign")
            try FileManager.default.createDirectory(at: foreign, withIntermediateDirectories: true)
            let marker = foreign.appendingPathComponent("prepared-sha")
            let bytes = Data((fixture.initial + "\n").utf8)
            try bytes.write(to: marker)
            try fixture.rewrite { config in
                config.workspaces[0] = LocalWorkspaceRegistry.Workspace(
                    workspace: entry.workspace, state: foreign.path, clone: entry.clone,
                    pullRequest: entry.pullRequest, eligibleSince: entry.eligibleSince
                )
            }
            _ = await fixture.cleanup.clean(now: fixture.now)
            fixture.expectWorkspaceDirectoriesExist(entry)
            #expect(try Data(contentsOf: marker) == bytes)
        }

        @Test func preservesWorkspaceWhileOperationLockIsHeld() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let entry = try await fixture.addWorkspace()
            let lock = try LocalWorkspaceLock(state: URL(fileURLWithPath: entry.state))
            defer { withExtendedLifetime(lock) {} }
            _ = await fixture.cleanup.clean(now: fixture.now)
            fixture.expectWorkspaceDirectoriesExist(entry)
        }

        @Test func preservesUnknownSessionFileBytes() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let entry = try await fixture.addWorkspace()
            let session = URL(fileURLWithPath: entry.state).appendingPathComponent("sessions/\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: session, withIntermediateDirectories: true)
            let file = session.appendingPathComponent("keep-me")
            try Data("user data".utf8).write(to: file)
            _ = await fixture.cleanup.clean(now: fixture.now)
            fixture.expectWorkspaceDirectoriesExist(entry)
            #expect(try String(contentsOf: file, encoding: .utf8) == "user data")
        }

        @Test func refusesSymlinkSessionsAndPreservesTargetBytes() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let entry = try await fixture.addWorkspace()
            let file = fixture.directory.appendingPathComponent("keep-me")
            try Data("user data".utf8).write(to: file)
            try FileManager.default.createSymbolicLink(
                at: URL(fileURLWithPath: entry.state).appendingPathComponent("sessions"),
                withDestinationURL: fixture.directory
            )
            _ = await fixture.cleanup.clean(now: fixture.now)
            fixture.expectWorkspaceDirectoriesExist(entry)
            #expect(try String(contentsOf: file, encoding: .utf8) == "user data")
        }

        @Test func neverScansUnregisteredNeighbors() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let unregistered = try await fixture.addWorkspace()
            let registered = try await fixture.addWorkspace()
            try fixture.rewrite { $0.workspaces.removeFirst() }
            _ = await fixture.cleanup.clean(now: fixture.now)
            fixture.expectWorkspaceDirectoriesExist(unregistered)
            #expect(!FileManager.default.fileExists(atPath: registered.workspace))
        }

        @Test(arguments: ["reopen", "disable", "external-disable", "external-registry-change"])
        func refreshAndPreferenceChangesDuringInspectionPreventRemoval(_ scenario: String) async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let entry = try await fixture.addWorkspace()
            let cleanup = fixture.cleanup
            let task = Task { await cleanup.clean(now: fixture.now) }
            let lockPath = URL(fileURLWithPath: entry.state).appendingPathExtension("operation-lock").path
            // The stable lock is created before the first awaited Git inspection.
            let clock = ContinuousClock()
            let deadline = clock.now.advanced(by: .seconds(5))
            while !FileManager.default.fileExists(atPath: lockPath), clock.now < deadline {
                await Task.yield()
            }
            guard FileManager.default.fileExists(atPath: lockPath) else {
                task.cancel()
                _ = await task.value
                Issue.record("Cleanup did not acquire its operation lock before the timeout.")
                return
            }
            switch scenario {
            case "reopen": cleanup.updateTrackedPullRequests([fixture.request()], now: fixture.now)
            case "disable": cleanup.setEnabled(false)
            case "external-disable":
                fixture.defaults.set(false, forKey: LocalActionsController.Preference.automaticCleanup.key)
            default:
                var config = try fixture.configuration()
                config.workspaces[0].eligibleSince = nil
                try LocalWorkspaceRegistry(directory: fixture.support).save(config.workspaces)
            }
            _ = await task.value
            fixture.expectWorkspaceDirectoriesExist(entry)
        }
    }
#endif
