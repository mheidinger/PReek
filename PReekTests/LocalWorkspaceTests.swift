#if os(macOS)
    import Foundation
    import Testing

    struct LocalWorkspaceTests {
        private actor MetadataSnapshots {
            let initial: LocalWorkspaceService.Metadata
            let refreshed: LocalWorkspaceService.Metadata
            private(set) var requests = 0

            init(initial: LocalWorkspaceService.Metadata, refreshed: LocalWorkspaceService.Metadata) {
                self.initial = initial
                self.refreshed = refreshed
            }

            func next() -> LocalWorkspaceService.Metadata {
                requests += 1
                return requests == 1 ? initial : refreshed
            }
        }

        @Test(arguments: [
            ("  Fix: Café / Refunds! 🚀  ", "fix-cafe-refunds--pr-2147483647"),
            ("ＦＩＸ refund", "fix-refund--pr-2147483647"),
            ("../../Fix\\refund:now", "fix-refund-now--pr-2147483647"),
            ("🚀 修复", "untitled--pr-2147483647"),
            ("", "untitled--pr-2147483647"),
            (String(repeating: "a", count: 100), String(repeating: "a", count: 49) + "--pr-2147483647"),
            (String(repeating: "a", count: 48) + " b", String(repeating: "a", count: 48) + "--pr-2147483647"),
        ])
        func workspaceNamesAreSafeAndBounded(_ title: String, _ expected: String) throws {
            let identity = try LocalWorkspaceService.identity(for: #require(URL(string: "https://github.com/owner/repo/pull/2147483647")))
            #expect(identity.workspaceName(title: title) == expected)
        }

        @Test func titleChangesNeverMoveAnExistingWorkspace() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let first = try await fixture.prepare(title: "Fix refund calculation")
            #expect(first.url.lastPathComponent == "fix-refund-calculation--pr-1")
            #expect(first.url.deletingLastPathComponent().lastPathComponent == "repo")
            let renamed = try await fixture.prepare(root: fixture.directory.appendingPathComponent("new root"), title: "Different title")
            #expect(renamed.url == first.url && renamed.state == first.state)
            _ = try await Fixture.git(first.url, ["checkout", "--detach"])
            let detached = try await fixture.reuseOffline()
            #expect(detached.url == first.url && detached.updateWarning != nil)
            let metadata = LocalWorkspaceService.Metadata(headSHA: fixture.head, baseSHA: fixture.base, title: "Another title")
            let forced = try await LocalWorkspaceService.shared.forceUpdate(pullRequestURL: fixture.request, workspace: detached) { metadata }
            #expect(forced.url == first.url)
            #expect(try await Fixture.git(forced.url, ["rev-parse", "HEAD"]) == fixture.head)
        }

        @Test func namedPreparationResumesAtItsFrozenPathAfterHookFailure() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            try fixture.installCheckoutHook("printf 'keep hook data\\n' > hook-data.txt\nexit 1")
            await #expect(throws: (any Error).self) {
                _ = try await fixture.prepare(title: "Original title")
            }
            try fixture.installCheckoutHook("exit 0")
            let recovered = try await fixture.reuseOffline()
            #expect(recovered.url.lastPathComponent == "original-title--pr-1")
            #expect(try String(contentsOf: recovered.url.appendingPathComponent("hook-data.txt"), encoding: .utf8) == "keep hook data\n")
            #expect(recovered.updateWarning != nil)
        }

        @Test(arguments: ["../outside", "wrong--pr-2", String(repeating: "a", count: 64) + "--pr-1"])
        func refusesInvalidSavedWorkspaceNames(_ name: String) async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let workspace = try await fixture.prepare(title: "Original title")
            try Data(name.utf8).write(to: workspace.state.appendingPathComponent("workspace-name"))
            await #expect(throws: (any Error).self) { _ = try await fixture.prepare(title: "New title") }
            #expect(try await Fixture.git(workspace.url, ["rev-parse", "HEAD"]) == fixture.head)
        }

        @Test(arguments: ["symlink", "foreign-path", "foreign-registration"])
        func forceNeverDeletesUnrelatedOrRedirectedDirectories(_ scenario: String) async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let workspace = try await fixture.prepare()
            let sentinel = fixture.directory.appendingPathComponent("unrelated/keep.txt")
            try FileManager.default.createDirectory(at: sentinel.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("keep\n".utf8).write(to: sentinel)
            var selected = workspace.url
            if scenario == "symlink" {
                selected = fixture.directory.appendingPathComponent("alias")
                try FileManager.default.createSymbolicLink(at: selected, withDestinationURL: workspace.url)
            } else if scenario == "foreign-path" {
                selected = sentinel.deletingLastPathComponent()
            } else {
                let registration = try await LocalWorkspaceSafety.gitPath(workspace.url, "--absolute-git-dir")
                try Data("/unrelated/.git\n".utf8).write(to: registration.appendingPathComponent("gitdir"))
            }
            let forged = try LocalWorkspaceService.PreparedWorkspace(
                layout: scenario == "foreign-registration" ? workspace.layout
                    : LocalWorkspaceSafety.Layout(root: selected, identity: LocalWorkspaceService.identity(for: fixture.request)),
                clone: workspace.clone,
                headSHA: workspace.headSHA, baseSHA: workspace.baseSHA
            )
            await #expect(throws: (any Error).self) {
                _ = try await LocalWorkspaceService.shared.forceUpdate(pullRequestURL: fixture.request, workspace: forged) {
                    Issue.record("Invalid paths must be rejected before fetching")
                    throw CancellationError()
                }
            }
            #expect(try String(contentsOf: sentinel, encoding: .utf8) == "keep\n")
            #expect(LocalWorkspaceSafety.exists(workspace.url.appendingPathComponent("tracked.txt")))
        }

        @Test(arguments: [
            "modified", "staged", "untracked", "ignored", "nested-repository", "submodule",
            "assume-unchanged", "skip-worktree", "locked", "index.lock", "HEAD.lock",
            "merge", "rebase", "sequencer", "bisect", "detached", "other-branch",
        ])
        func confirmedForceReplacesAllLocalWorkspaceState(_ scenario: String) async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let workspace = try await fixture.prepare()
            try Data("committed local work\n".utf8).write(to: workspace.url.appendingPathComponent("local.txt"))
            _ = try await Fixture.git(workspace.url, ["add", "local.txt"])
            _ = try await Fixture.git(workspace.url, ["commit", "-m", "local commit"])
            let local = try await Fixture.git(workspace.url, ["rev-parse", "HEAD"])
            let registration = try await LocalWorkspaceSafety.gitPath(workspace.url, "--absolute-git-dir")
            switch scenario {
            case "modified", "staged", "assume-unchanged", "skip-worktree":
                if scenario == "assume-unchanged" || scenario == "skip-worktree" {
                    _ = try await Fixture.git(workspace.url, ["update-index", "--" + scenario, "tracked.txt"])
                }
                try Data("discard me\n".utf8).write(to: workspace.url.appendingPathComponent("tracked.txt"))
                if scenario == "staged" {
                    _ = try await Fixture.git(workspace.url, ["add", "tracked.txt"])
                }
            case "untracked", "ignored":
                if scenario == "ignored" {
                    try Data("discard.txt\n".utf8).write(to: fixture.clone.appendingPathComponent(".git/info/exclude"))
                }
                try Data("discard me\n".utf8).write(to: workspace.url.appendingPathComponent("discard.txt"))
            case "nested-repository":
                _ = try await Fixture.git(workspace.url, ["init", "nested"])
            case "submodule":
                _ = try await Fixture.git(workspace.url, ["-c", "protocol.file.allow=always", "submodule", "add", "-b", "main", fixture.remote.path, "module"])
                try Data("submodule local data\n".utf8).write(to: workspace.url.appendingPathComponent("module/private.txt"))
            case "locked", "index.lock", "HEAD.lock", "merge", "bisect":
                let marker = scenario == "merge" ? "MERGE_HEAD" : scenario == "bisect" ? "BISECT_START" : scenario
                try Data((local + "\n").utf8).write(to: registration.appendingPathComponent(marker))
            case "rebase", "sequencer":
                try FileManager.default.createDirectory(at: registration.appendingPathComponent(scenario == "rebase" ? "rebase-merge" : "sequencer"), withIntermediateDirectories: false)
            case "detached": _ = try await Fixture.git(workspace.url, ["checkout", "--detach"])
            default: _ = try await Fixture.git(workspace.url, ["checkout", "-b", "my-other-branch"])
            }
            try await fixture.advanceRemote(replacingHead: true, advanceBase: true)
            let main = try await Fixture.git(fixture.clone, ["rev-parse", "HEAD"])
            let skipped = try await fixture.reuseOffline()
            #expect(skipped.updateWarning != nil)
            let metadata = LocalWorkspaceService.Metadata(headSHA: fixture.head, baseSHA: fixture.base, title: "Untitled")
            let updated = try await LocalWorkspaceService.shared.forceUpdate(pullRequestURL: fixture.request, workspace: skipped) { metadata }
            let identity = try LocalWorkspaceService.identity(for: fixture.request)
            #expect(updated.updateWarning == nil)
            #expect(try await Fixture.git(updated.url, ["rev-parse", "HEAD"]) == fixture.head)
            #expect(try await Fixture.git(updated.url, ["symbolic-ref", "HEAD"]) == identity.branchReference)
            #expect(try await Fixture.git(updated.url, ["status", "--porcelain", "--ignored"]).isEmpty)
            #expect(try LocalWorkspaceSafety.preparedSHA(updated.state) == fixture.head)
            #expect(updated.baseSHA == fixture.base)
            #expect(try await Fixture.git(fixture.clone, ["rev-parse", "HEAD"]) == main)
            let backups = try await Fixture.git(fixture.clone, ["for-each-ref", "--format=%(objectname)", "refs/preek/\(identity.referenceSuffix)/backups/"])
            #expect(backups.split(separator: "\n").contains(Substring(local)))
            #expect(try await LocalWorkspaceSafety.refreshWarning(updated.url, common: fixture.clone.appendingPathComponent(".git")) == nil)
            for name in ["discard.txt", "nested", "module", "local.txt"] {
                #expect(!LocalWorkspaceSafety.exists(updated.url.appendingPathComponent(name)))
            }
        }

        @Test func forceFetchFailureLeavesLocalDataUntouched() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let workspace = try await fixture.prepare()
            let file = workspace.url.appendingPathComponent("tracked.txt")
            let bytes = Data("keep local edits\n".utf8)
            try bytes.write(to: file)
            await #expect(throws: (any Error).self) {
                _ = try await LocalWorkspaceService.shared.forceUpdate(pullRequestURL: fixture.request, workspace: workspace) {
                    throw LocalActionError(message: "Network unavailable")
                }
            }
            #expect(try Data(contentsOf: file) == bytes)
            #expect(try await Fixture.git(workspace.url, ["rev-parse", "HEAD"]) == fixture.head)
        }

        @Test(arguments: [false, true])
        func refreshesCleanCheckoutIncludingReplacedCommitsAndSavedMarkers(_ replace: Bool) async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let first = try await fixture.prepare()
            let originalMain = try await Fixture.git(fixture.clone, ["rev-parse", "HEAD"])
            try await fixture.advanceRemote(replacingHead: replace, advanceBase: true)
            let refreshed = try await fixture.prepare(root: fixture.directory.appendingPathComponent("different root"))
            let identity = try LocalWorkspaceService.identity(for: fixture.request)
            #expect(refreshed.url == first.url && refreshed.root == first.root)
            #expect(refreshed.headSHA == fixture.head && refreshed.baseSHA == fixture.base)
            #expect(refreshed.updateWarning == nil)
            #expect(try await Fixture.git(refreshed.url, ["rev-parse", "HEAD"]) == fixture.head)
            #expect(try LocalWorkspaceSafety.preparedSHA(refreshed.state) == fixture.head)
            #expect(try await Fixture.git(fixture.clone, ["rev-parse", identity.headReference]) == fixture.head)
            #expect(try await Fixture.git(fixture.clone, ["rev-parse", identity.baseReference]) == fixture.base)
            #expect(try await Fixture.git(fixture.clone, ["rev-parse", "HEAD"]) == originalMain)
        }

        @Test(arguments: [false, true])
        func cleanLocalCommitsRemainReachableAcrossRefreshesAndReflogExpiry(_ forcePush: Bool) async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let workspace = try await fixture.prepare()
            try Data("my local commit\n".utf8).write(to: workspace.url.appendingPathComponent("local.txt"))
            _ = try await Fixture.git(workspace.url, ["add", "local.txt"])
            _ = try await Fixture.git(workspace.url, ["commit", "-m", "local work"])
            let local = try await Fixture.git(workspace.url, ["rev-parse", "HEAD"])
            if forcePush {
                try await fixture.advanceRemote(replacingHead: true)
            }
            let refreshed = try await fixture.prepare()
            #expect(refreshed.headSHA == fixture.head)
            let identity = try LocalWorkspaceService.identity(for: fixture.request)
            let prefix = "refs/preek/\(identity.referenceSuffix)/backups/"
            let backups = try await Fixture.git(fixture.clone, ["for-each-ref", "--format=%(refname) %(objectname)", prefix])
            let backup = try #require(backups.split(separator: "\n").first(where: { $0.hasSuffix(" " + local) }))
            #expect(backup.hasPrefix(prefix))
            try await fixture.advanceRemote()
            _ = try await fixture.prepare()
            _ = try await Fixture.git(fixture.clone, ["reflog", "expire", "--expire=now", "--all"])
            _ = try await Fixture.git(fixture.clone, ["gc", "--prune=now"])
            let backupRef = try String(#require(backup.split(separator: " ").first))
            #expect(try await Fixture.git(fixture.clone, ["rev-parse", backupRef]) == local)
            #expect(try await Fixture.git(fixture.clone, ["show", "\(backupRef):local.txt"]) == "my local commit")
        }

        @Test(arguments: [
            "modified", "staged", "untracked", "ignored", "assume-unchanged", "skip-worktree",
            "submodule", "locked", "index-lock", "merge", "rebase",
        ])
        func unsafeCheckoutsSkipRefreshOfflineAndPreserveData(_ scenario: String) async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let workspace = try await fixture.prepare()
            let originalHead = fixture.head
            let originalBase = fixture.base
            let registration = try URL(fileURLWithPath: await Fixture.git(workspace.url, ["rev-parse", "--absolute-git-dir"]))
            let tracked = workspace.url.appendingPathComponent("tracked.txt")
            switch scenario {
            case "modified", "staged", "assume-unchanged", "skip-worktree":
                if scenario == "assume-unchanged" || scenario == "skip-worktree" {
                    _ = try await Fixture.git(workspace.url, ["update-index", "--\(scenario)", "tracked.txt"])
                }
                try Data("precious local data\n".utf8).write(to: tracked)
                if scenario == "staged" {
                    _ = try await Fixture.git(workspace.url, ["add", "tracked.txt"])
                }
            case "untracked":
                try Data("precious local data\n".utf8).write(to: workspace.url.appendingPathComponent("untracked.txt"))
            case "ignored":
                try Data("ignored.txt\n".utf8).write(to: fixture.clone.appendingPathComponent(".git/info/exclude"))
                try Data("precious local data\n".utf8).write(to: workspace.url.appendingPathComponent("ignored.txt"))
            case "submodule":
                _ = try await Fixture.git(workspace.url, ["update-index", "--add", "--cacheinfo", "160000", originalHead, "submodule"])
            case "locked", "index-lock", "merge":
                let name = scenario == "locked" ? "locked" : scenario == "index-lock" ? "index.lock" : "MERGE_HEAD"
                try Data((originalHead + "\n").utf8).write(to: registration.appendingPathComponent(name))
            default:
                try FileManager.default.createDirectory(at: registration.appendingPathComponent("rebase-merge"), withIntermediateDirectories: true)
            }
            try await fixture.advanceRemote(replacingHead: true, advanceBase: true)
            let reused = try await fixture.reuseOffline()
            let identity = try LocalWorkspaceService.identity(for: fixture.request)
            #expect(reused.headSHA == originalHead && reused.baseSHA == originalBase)
            #expect(reused.updateWarning != nil)
            #expect(try await Fixture.git(workspace.url, ["rev-parse", "HEAD"]) == originalHead)
            #expect(try LocalWorkspaceSafety.preparedSHA(workspace.state) == originalHead)
            #expect(try await Fixture.git(fixture.clone, ["rev-parse", identity.baseReference]) == originalBase)
            if ["modified", "staged", "assume-unchanged", "skip-worktree"].contains(scenario) {
                #expect(try String(contentsOf: tracked, encoding: .utf8) == "precious local data\n")
            }
            if scenario == "staged" {
                #expect(try await Fixture.git(workspace.url, ["show", ":tracked.txt"]) == "precious local data")
            }
            if scenario == "untracked" || scenario == "ignored" {
                #expect(try String(contentsOf: workspace.url.appendingPathComponent("\(scenario).txt"), encoding: .utf8) == "precious local data\n")
            }
        }

        @Test(arguments: [false, true])
        func rechecksEditsAndHeadCreatedDuringFetch(_ commit: Bool) async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let workspace = try await fixture.prepare()
            let originalHead = fixture.head
            try await fixture.advanceRemote()
            let metadata = LocalWorkspaceService.Metadata(headSHA: fixture.head, baseSHA: fixture.base, title: "Untitled")
            let refreshed = try await LocalWorkspaceService.shared.prepare(
                pullRequestURL: fixture.request, clone: fixture.clone, root: fixture.root
            ) {
                try Data("created during fetch\n".utf8).write(to: workspace.url.appendingPathComponent("tracked.txt"))
                if commit {
                    _ = try await Fixture.git(workspace.url, ["commit", "-am", "concurrent local commit"])
                }
                return metadata
            }
            #expect(refreshed.updateWarning != nil)
            let actual = try await Fixture.git(workspace.url, ["rev-parse", "HEAD"])
            #expect(refreshed.headSHA == actual)
            #expect(commit ? actual != originalHead : actual == originalHead)
            #expect(try String(contentsOf: workspace.url.appendingPathComponent("tracked.txt"), encoding: .utf8) == "created during fetch\n")
            #expect(try LocalWorkspaceSafety.preparedSHA(workspace.state) == originalHead)
        }

        @Test(arguments: ["metadata", "fetch", "mismatch"])
        func cleanExistingCheckoutDoesNotSilentlyLaunchStaleOnNetworkFailure(_ failure: String) async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let workspace = try await fixture.prepare()
            let originalHead = fixture.head
            let originalBase = fixture.base
            try await fixture.advanceRemote()
            if failure == "fetch" {
                try FileManager.default.removeItem(at: fixture.remote)
            }
            let details = LocalWorkspaceService.Metadata(
                headSHA: failure == "mismatch" ? originalHead : fixture.head, baseSHA: fixture.base, title: "Untitled"
            )
            await #expect(throws: (any Error).self) {
                _ = try await LocalWorkspaceService.shared.prepare(
                    pullRequestURL: fixture.request, clone: fixture.clone, root: fixture.root
                ) {
                    if failure == "metadata" {
                        throw LocalActionError(message: "offline")
                    }
                    return details
                }
            }
            let identity = try LocalWorkspaceService.identity(for: fixture.request)
            #expect(try await Fixture.git(workspace.url, ["rev-parse", "HEAD"]) == originalHead)
            #expect(try LocalWorkspaceSafety.preparedSHA(workspace.state) == originalHead)
            #expect(try await Fixture.git(fixture.clone, ["rev-parse", identity.baseReference]) == originalBase)
        }

        @Test func cleanPendingRecoveryRefreshesToLatestBeforeHandoff() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            try fixture.installCheckoutHook("exit 1")
            await #expect(throws: (any Error).self) { _ = try await fixture.prepare() }
            try fixture.installCheckoutHook("exit 0")
            try await fixture.advanceRemote(replacingHead: true, advanceBase: true)
            let recovered = try await fixture.prepare()
            #expect(recovered.headSHA == fixture.head && recovered.baseSHA == fixture.base)
            #expect(recovered.updateWarning == nil)
            #expect(try LocalWorkspaceSafety.preparedSHA(recovered.state) == fixture.head)
            #expect(!LocalWorkspaceSafety.exists(recovered.state.appendingPathComponent("pending-preparation")))
        }

        @Test(arguments: ["owner/repo", "contributor/fork"], [false, true])
        func plainPushUpdatesOnlyTheActualPRHeadBranch(_ headRepository: String, _ reuse: Bool) async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let pushTarget = fixture.directory.appendingPathComponent("push-target.git")
            _ = try await Fixture.git(fixture.directory, ["init", "--bare", pushTarget.path])
            let branch = "feature/review-fixes"
            _ = try await Fixture.git(fixture.clone, ["push", pushTarget.path, "\(fixture.head):refs/heads/\(branch)"])
            let ssh = fixture.directory.appendingPathComponent("ssh-fixture")
            let transport = """
            #!/bin/sh
            case "$*" in
              *"git-receive-pack '\(headRepository).git'"*) exec /usr/bin/git receive-pack '\(pushTarget.path)';;
              *git-receive-pack*) exit 73;;
              *) exec /usr/bin/git upload-pack '\(fixture.remote.path)';;
            esac
            """
            try Data((transport + "\n").utf8).write(to: ssh)
            _ = try await Fixture.git(fixture.clone, ["config", "push.default", "simple"])
            _ = try await Fixture.git(fixture.clone, ["config", "remote.pushDefault", "origin"])
            if reuse {
                _ = try await fixture.prepare()
            }
            // Cover initial creation and repair of existing worktrees without a push target.
            let metadata = LocalWorkspaceService.Metadata(
                headSHA: fixture.head, baseSHA: fixture.base, title: "Untitled",
                pushDestination: .init(repository: headRepository, branch: branch)
            )
            let workspace = try await LocalWorkspaceService.shared.prepare(
                pullRequestURL: fixture.request, clone: fixture.clone, root: fixture.root
            ) { metadata }
            try Data("fix from PR checkout\n".utf8).write(to: workspace.url.appendingPathComponent("tracked.txt"))
            _ = try await Fixture.git(workspace.url, ["commit", "-am", "address review"])
            let localHead = try await Fixture.git(workspace.url, ["rev-parse", "HEAD"])
            // No destination or refspec supplied: exercise the same command editors use.
            _ = try await Fixture.git(workspace.url, ["push"])
            #expect(try await Fixture.git(pushTarget, ["rev-parse", "refs/heads/\(branch)"]) == localHead)
            #expect(try await Fixture.git(pushTarget, ["for-each-ref", "--format=%(refname)", "refs/heads/"]) == "refs/heads/\(branch)")
            #expect(try await Fixture.git(fixture.remote, ["rev-parse", "refs/pull/1/head"]) == fixture.head)
            #expect(try await Fixture.git(fixture.clone, ["rev-parse", "HEAD"]) == fixture.base)
            #expect(try await Fixture.git(fixture.clone, ["config", "remote.pushDefault"]) == "origin")
            #expect(try await Fixture.git(fixture.clone, ["config", "push.default"]) == "simple")
            // The default push must not force away commits added remotely.
            let tree = try await Fixture.git(pushTarget, ["rev-parse", "\(localHead)^{tree}"])
            let concurrent = try await Fixture.git(pushTarget, [
                "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                "commit-tree", tree, "-p", fixture.head, "-m", "concurrent review fix",
            ])
            _ = try await Fixture.git(pushTarget, ["update-ref", "refs/heads/\(branch)", concurrent])
            await #expect(throws: LocalActionError.self) { _ = try await Fixture.git(workspace.url, ["push"]) }
            #expect(try await Fixture.git(pushTarget, ["rev-parse", "refs/heads/\(branch)"]) == concurrent)
            #expect(try await Fixture.git(workspace.url, ["rev-parse", "HEAD"]) == localHead)
            // Once configured, dirty/offline launches retain the mapping and all local data.
            try Data("unfinished edit\n".utf8).write(to: workspace.url.appendingPathComponent("tracked.txt"))
            let reopened = try await fixture.reuseOffline()
            #expect(reopened.url == workspace.url)
            #expect(try String(contentsOf: reopened.url.appendingPathComponent("tracked.txt"), encoding: .utf8) == "unfinished edit\n")
        }

        private final class Fixture {
            let directory: URL
            let clone: URL
            let root: URL
            let remote: URL
            let request: URL
            var base: String
            var head: String

            init(authority: String = "fixture.invalid", repository: String = "repo") async throws {
                request = URL(string: "https://\(authority)/owner/\(repository)/pull/1")!
                let scratch = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
                directory = try LocalWorkspaceSafety.physicalURL(scratch)
                clone = directory.appendingPathComponent("clone")
                root = directory.appendingPathComponent("worktrees ' $(touch NEVER_EXECUTE)")
                remote = directory.appendingPathComponent("remote.git")
                _ = try await Self.git(directory, ["init", "--bare", remote.path])
                _ = try await Self.git(directory, ["init", "-b", "main", clone.path])
                _ = try await Self.git(clone, ["config", "user.name", "Fixture"])
                _ = try await Self.git(clone, ["config", "user.email", "fixture@example.invalid"])
                _ = try await Self.git(clone, ["config", "core.hooksPath", clone.appendingPathComponent(".git/hooks").path])
                try Data("base\n".utf8).write(to: clone.appendingPathComponent("tracked.txt"))
                _ = try await Self.git(clone, ["add", "tracked.txt"])
                _ = try await Self.git(clone, ["commit", "-m", "base"])
                base = try await Self.git(clone, ["rev-parse", "HEAD"])
                _ = try await Self.git(clone, ["push", remote.path, "HEAD:refs/heads/main"])
                try Data("PR change\n".utf8).write(to: clone.appendingPathComponent("tracked.txt"))
                _ = try await Self.git(clone, ["commit", "-am", "PR"])
                head = try await Self.git(clone, ["rev-parse", "HEAD"])
                _ = try await Self.git(clone, ["push", remote.path, "HEAD:refs/pull/1/head"])
                _ = try await Self.git(clone, ["reset", "--hard", base])
                _ = try await Self.git(clone, ["remote", "add", "origin", "git@fixture.invalid:owner/\(repository).git"])
                let ssh = directory.appendingPathComponent("ssh-fixture")
                try Data("#!/bin/sh\nexec /usr/bin/git upload-pack '\(remote.path)'\n".utf8).write(to: ssh)
                try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: ssh.path)
                _ = try await Self.git(clone, ["config", "core.sshCommand", ssh.path])
            }

            func remove() {
                try? FileManager.default.removeItem(at: directory)
            }

            static func git(_ directory: URL, _ args: [String]) async throws -> String {
                try await LocalCommand.checked("/usr/bin/git", args, directory: directory, environment: ["GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": "/dev/null"]).trimmingCharacters(in: .newlines)
            }

            func prepare(root: URL? = nil, title: String = "Untitled") async throws -> LocalWorkspaceService.PreparedWorkspace {
                let metadata = LocalWorkspaceService.Metadata(headSHA: head, baseSHA: base, title: title)
                return try await LocalWorkspaceService.shared.prepare(pullRequestURL: request, clone: clone, root: root ?? self.root) { metadata }
            }

            func installCheckoutHook(_ body: String) throws {
                let hook = clone.appendingPathComponent(".git/hooks/post-checkout")
                try Data(("#!/bin/sh\n" + body + "\n").utf8).write(to: hook)
                try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: hook.path)
            }

            func advanceRemote(replacingHead: Bool = false, advanceBase: Bool = false) async throws {
                if advanceBase {
                    _ = try await Self.git(clone, ["switch", "--detach", base])
                    _ = try await Self.git(clone, ["commit", "--allow-empty", "-m", "new base"])
                    base = try await Self.git(clone, ["rev-parse", "HEAD"])
                    _ = try await Self.git(clone, ["push", remote.path, "HEAD:refs/heads/main"])
                }
                _ = try await Self.git(clone, ["switch", "--detach", replacingHead ? base : head])
                try Data("latest PR \(UUID().uuidString)\n".utf8).write(to: clone.appendingPathComponent("tracked.txt"))
                _ = try await Self.git(clone, ["commit", "-am", "latest PR"])
                head = try await Self.git(clone, ["rev-parse", "HEAD"])
                _ = try await Self.git(clone, ["push", "--force", remote.path, "HEAD:refs/pull/1/head"])
                _ = try await Self.git(clone, ["switch", "main"])
            }

            func reuseOffline(root: URL? = nil) async throws -> LocalWorkspaceService.PreparedWorkspace {
                try await LocalWorkspaceService.shared.prepare(
                    pullRequestURL: request, clone: clone, root: root ?? self.root
                ) {
                    throw LocalActionError(message: "A dirty checkout must not request metadata")
                }
            }
        }

        @Test func wrongRepositoryCanBeCorrectedWithoutLeavingWorkspaceState() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            _ = try await Fixture.git(fixture.clone, ["remote", "set-url", "origin", "git@other.invalid:owner/repo.git"])
            await #expect(throws: LocalWorkspaceService.InvalidRepository.self) { _ = try await fixture.prepare() }
            #expect(!FileManager.default.fileExists(atPath: fixture.root.path))
            _ = try await Fixture.git(fixture.clone, ["remote", "set-url", "origin", "git@fixture.invalid:owner/repo.git"])
            let workspace = try await fixture.prepare()
            #expect(workspace.headSHA == fixture.head)
            #expect(try await Fixture.git(workspace.url, ["rev-parse", "HEAD"]) == fixture.head)
        }

        @Test func preparesDedicatedWorktreeWithoutChangingCloneAndReusesDirtyLocalWorkOffline() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let workspace = try await fixture.prepare()
            #expect(try await Fixture.git(fixture.clone, ["rev-parse", "HEAD"]) == fixture.base)
            #expect(try await Fixture.git(fixture.clone, ["symbolic-ref", "--short", "HEAD"]) == "main")
            #expect(workspace.headSHA == fixture.head && workspace.baseSHA == fixture.base)
            #expect(try await Fixture.git(workspace.url, ["symbolic-ref", "--short", "HEAD"]) == "preek/fixture.invalid/owner/repo/pr-1")
            try Data("local work\n".utf8).write(to: workspace.url.appendingPathComponent("tracked.txt"))
            _ = try await Fixture.git(workspace.url, ["commit", "-am", "local only"])
            let local = try await Fixture.git(workspace.url, ["rev-parse", "HEAD"])
            try Data("dirty local work\n".utf8).write(to: workspace.url.appendingPathComponent("tracked.txt"))
            let reused = try await LocalWorkspaceService.shared.prepare(pullRequestURL: fixture.request, clone: fixture.clone, root: fixture.root) {
                throw LocalActionError(message: "No network metadata allowed when reusing a checkout")
            }
            #expect(reused.headSHA == local)
            #expect(reused.updateWarning != nil)
            #expect(try String(contentsOf: reused.url.appendingPathComponent("tracked.txt"), encoding: .utf8) == "dirty local work\n")
            #expect(!FileManager.default.fileExists(atPath: fixture.directory.appendingPathComponent("NEVER_EXECUTE").path))
        }

        @Test func changedRootReusesOriginalCheckoutAndDirtyLocalWorkOffline() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let original = try await fixture.prepare()
            try Data("local commit\n".utf8).write(to: original.url.appendingPathComponent("tracked.txt"))
            _ = try await Fixture.git(original.url, ["commit", "-am", "local only"])
            let local = try await Fixture.git(original.url, ["rev-parse", "HEAD"])
            try Data("uncommitted\n".utf8).write(to: original.url.appendingPathComponent("tracked.txt"))
            let changedRoot = fixture.directory.appendingPathComponent("new root")
            let reused = try await fixture.reuseOffline(root: changedRoot)
            #expect(reused.root == original.root)
            #expect(reused.url == original.url && reused.state == original.state)
            #expect(reused.headSHA == local)
            #expect(reused.updateWarning != nil)
            #expect(try String(contentsOf: reused.url.appendingPathComponent("tracked.txt"), encoding: .utf8) == "uncommitted\n")
            #expect(!LocalWorkspaceSafety.exists(changedRoot))
        }

        @Test func failedCheckoutHookCanRetryOfflineWithoutLosingHookDataOrLocalCommits() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            try fixture.installCheckoutHook("printf 'hook data\\n' > hook-data.txt\nexit 1")
            await #expect(throws: (any Error).self) { _ = try await fixture.prepare() }
            let identity = try LocalWorkspaceService.identity(for: fixture.request)
            let layout = LocalWorkspaceSafety.Layout(root: fixture.root, identity: identity)
            #expect(LocalWorkspaceSafety.ownedFile(layout.state.appendingPathComponent("pending-preparation")))
            #expect(!LocalWorkspaceSafety.exists(layout.state.appendingPathComponent("prepared-sha")))
            try Data("local commit\n".utf8).write(to: layout.workspace.appendingPathComponent("tracked.txt"))
            _ = try await Fixture.git(layout.workspace, ["commit", "-am", "local after failed hook"])
            let local = try await Fixture.git(layout.workspace, ["rev-parse", "HEAD"])
            try Data("local edits\n".utf8).write(to: layout.workspace.appendingPathComponent("tracked.txt"))
            try fixture.installCheckoutHook("exit 0")
            let recovered = try await fixture.reuseOffline()
            #expect(recovered.headSHA == local)
            #expect(recovered.updateWarning != nil)
            #expect(try String(contentsOf: recovered.url.appendingPathComponent("hook-data.txt"), encoding: .utf8) == "hook data\n")
            #expect(try String(contentsOf: recovered.url.appendingPathComponent("tracked.txt"), encoding: .utf8) == "local edits\n")
            #expect(try LocalWorkspaceSafety.preparedSHA(recovered.state) == fixture.head)
            #expect(!LocalWorkspaceSafety.exists(recovered.state.appendingPathComponent("pending-preparation")))
        }

        @Test func retainedBranchCreatesDirectlyAtTargetAndPreservesFailedHookEditsOnRetry() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let identity = try LocalWorkspaceService.identity(for: fixture.request)
            _ = try await Fixture.git(fixture.clone, ["branch", identity.branch, fixture.base])
            try fixture.installCheckoutHook("printf 'hook edit\\n' > tracked.txt\nexit 1")
            await #expect(throws: (any Error).self) { _ = try await fixture.prepare() }
            let layout = LocalWorkspaceSafety.Layout(root: fixture.root, identity: identity)
            #expect(try await Fixture.git(layout.workspace, ["rev-parse", "HEAD"]) == fixture.head)
            let journal = try String(contentsOf: layout.state.appendingPathComponent("pending-preparation"), encoding: .utf8)
            #expect(!journal.contains("initialSHA"))
            try fixture.installCheckoutHook("exit 0")
            let recovered = try await fixture.reuseOffline()
            #expect(recovered.headSHA == fixture.head)
            #expect(recovered.updateWarning != nil)
            #expect(try String(contentsOf: recovered.url.appendingPathComponent("tracked.txt"), encoding: .utf8) == "hook edit\n")
            let backups = try await Fixture.git(fixture.clone, ["for-each-ref", "--format=%(objectname)", "refs/preek/\(identity.referenceSuffix)/backups/"])
            #expect(backups.split(separator: "\n").contains(Substring(fixture.base)))
            #expect(!LocalWorkspaceSafety.exists(recovered.state.appendingPathComponent("pending-preparation")))
        }

        @Test(arguments: ["invalid-marker", "symlink-marker", "foreign-registration", "foreign-branch"])
        func pendingPreparationDoesNotExcuseUnsafeExistingState(_ scenario: String) async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            try fixture.installCheckoutHook("printf 'hook data\\n' > hook-data.txt\nexit 1")
            await #expect(throws: (any Error).self) { _ = try await fixture.prepare() }
            try fixture.installCheckoutHook("exit 0")
            let identity = try LocalWorkspaceService.identity(for: fixture.request)
            let layout = LocalWorkspaceSafety.Layout(root: fixture.root, identity: identity)
            let marker = layout.state.appendingPathComponent("prepared-sha")
            switch scenario {
            case "invalid-marker":
                try Data("invalid\n".utf8).write(to: marker)
            case "symlink-marker":
                let outside = fixture.directory.appendingPathComponent("outside-marker")
                try Data((fixture.head + "\n").utf8).write(to: outside)
                try FileManager.default.createSymbolicLink(at: marker, withDestinationURL: outside)
            case "foreign-registration":
                let registration = try await Fixture.git(layout.workspace, ["rev-parse", "--absolute-git-dir"])
                try Data("/foreign/.git\n".utf8).write(to: URL(fileURLWithPath: registration).appendingPathComponent("gitdir"))
            default:
                _ = try await Fixture.git(layout.workspace, ["switch", "-c", "foreign-branch"])
            }
            await #expect(throws: (any Error).self) { _ = try await fixture.reuseOffline() }
            #expect(LocalWorkspaceSafety.ownedFile(layout.state.appendingPathComponent("pending-preparation")))
            #expect(try String(contentsOf: layout.workspace.appendingPathComponent("hook-data.txt"), encoding: .utf8) == "hook data\n")
        }

        @MainActor
        @Test func recoveredPreparationRegistersActualRootAndCleansOnlyAfterLocalDataIsRemoved() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            try fixture.installCheckoutHook("printf 'hook data\\n' > hook-data.txt\nexit 1")
            await #expect(throws: (any Error).self) { _ = try await fixture.prepare() }
            try fixture.installCheckoutHook("exit 0")
            let recovered = try await fixture.reuseOffline(root: fixture.directory.appendingPathComponent("new root"))
            let suite = "LocalWorkspaceTests.\(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let cleanup = LocalActionsCleanup(registry: LocalWorkspaceRegistry(directory: fixture.directory.appendingPathComponent("registry")), defaults: defaults)
            let request = try PullRequest(
                id: "pr-1", repository: Repository(name: "owner/repo", url: #require(URL(string: "https://fixture.invalid/owner/repo"))),
                author: User.preview(login: "author"), title: "PR", number: 1, status: .closed,
                lastUpdated: Date(), events: [], url: fixture.request, additions: 0, deletions: 0,
                approvalFrom: [], changesRequestedFrom: []
            )
            try cleanup.register(pullRequest: request, workspace: recovered)
            cleanup.setEnabled(true)
            let configuration = try cleanup.registry.read()
            #expect(configuration.workspaces.map(\.workspace) == [recovered.url.path])
            let eligible = Date().addingTimeInterval(86401)
            await cleanup.clean(now: eligible)
            #expect(LocalWorkspaceSafety.exists(recovered.url.appendingPathComponent("hook-data.txt")))
            try FileManager.default.removeItem(at: recovered.url.appendingPathComponent("hook-data.txt"))
            await cleanup.clean(now: eligible)
            #expect(!LocalWorkspaceSafety.exists(recovered.url))
            let identity = try LocalWorkspaceService.identity(for: fixture.request)
            #expect(try await Fixture.git(fixture.clone, ["rev-parse", identity.branchReference]) == fixture.head)
        }

        @Test func refusesForeignRemoteBeforeCreatingState() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            _ = try await Fixture.git(fixture.clone, ["remote", "set-url", "origin", "git@other.invalid:owner/repo.git"])
            await #expect(throws: LocalWorkspaceService.InvalidRepository.self) { _ = try await fixture.prepare() }
            #expect(!LocalWorkspaceSafety.exists(fixture.root))
        }

        @Test func refusesUnmanagedWorkspaceAndPreservesItsBytes() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let layout = try LocalWorkspaceSafety.Layout(root: fixture.root, identity: LocalWorkspaceService.identity(for: fixture.request))
            try FileManager.default.createDirectory(at: layout.workspace, withIntermediateDirectories: true)
            let file = layout.workspace.appendingPathComponent("keep.txt")
            try Data("user data".utf8).write(to: file)
            await #expect(throws: (any Error).self) { _ = try await fixture.prepare() }
            #expect(try String(contentsOf: file, encoding: .utf8) == "user data")
        }

        @Test func refusesUnmanagedRegisteredWorktreeAndPreservesItsBytes() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let identity = try LocalWorkspaceService.identity(for: fixture.request)
            let layout = LocalWorkspaceSafety.Layout(root: fixture.root, identity: identity)
            _ = try await Fixture.git(fixture.clone, ["worktree", "add", "-b", identity.branch, layout.workspace.path, fixture.head])
            let file = layout.workspace.appendingPathComponent("keep.txt")
            try Data("user data".utf8).write(to: file)
            await #expect(throws: (any Error).self) { _ = try await fixture.prepare() }
            #expect(try String(contentsOf: file, encoding: .utf8) == "user data")
        }

        @Test func refusesMissingWorkspaceNameAndPreservesLocalData() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let workspace = try await fixture.prepare()
            let marker = workspace.state.appendingPathComponent("workspace-name")
            try FileManager.default.removeItem(at: marker)
            let file = workspace.url.appendingPathComponent("tracked.txt")
            let bytes = Data("local work must survive a missing workspace name\n".utf8)
            try bytes.write(to: file)
            await #expect(throws: (any Error).self) { _ = try await fixture.prepare() }
            #expect(try Data(contentsOf: file) == bytes)
            #expect(try await Fixture.git(workspace.url, ["rev-parse", "HEAD"]) == fixture.head)
            #expect(try LocalWorkspaceSafety.preparedSHA(workspace.state) == fixture.head)
            #expect(!LocalWorkspaceSafety.exists(marker))
        }

        @Test func refusesMissingPreparationMarker() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let workspace = try await fixture.prepare()
            try FileManager.default.removeItem(at: workspace.state.appendingPathComponent("prepared-sha"))
            await #expect(throws: (any Error).self) { _ = try await fixture.prepare() }
            #expect(try await Fixture.git(workspace.url, ["rev-parse", "HEAD"]) == fixture.head)
        }

        @Test func refusesMalformedPreparationMarker() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let workspace = try await fixture.prepare()
            try Data("invalid\n".utf8).write(to: workspace.state.appendingPathComponent("prepared-sha"))
            await #expect(throws: (any Error).self) { _ = try await fixture.prepare() }
            #expect(try await Fixture.git(workspace.url, ["rev-parse", "HEAD"]) == fixture.head)
        }

        @Test func refusesUnknownPreparationCommitAndPreservesLocalBytes() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let workspace = try await fixture.prepare()
            try Data((String(repeating: "0", count: 40) + "\n").utf8).write(to: workspace.state.appendingPathComponent("prepared-sha"))
            let file = workspace.url.appendingPathComponent("keep.txt")
            try Data("local data\n".utf8).write(to: file)
            await #expect(throws: (any Error).self) { _ = try await fixture.prepare() }
            #expect(try String(contentsOf: file, encoding: .utf8) == "local data\n")
        }

        @Test func refusesSymlinkPreparationMarker() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let workspace = try await fixture.prepare()
            let outside = fixture.directory.appendingPathComponent("outside-marker")
            let bytes = Data((fixture.head + "\n").utf8)
            try bytes.write(to: outside)
            let marker = workspace.state.appendingPathComponent("prepared-sha")
            try FileManager.default.removeItem(at: marker)
            try FileManager.default.createSymbolicLink(at: marker, withDestinationURL: outside)
            await #expect(throws: (any Error).self) { _ = try await fixture.prepare() }
            #expect(try Data(contentsOf: outside) == bytes)
        }

        @Test func refusesMalformedPreparationJournal() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let workspace = try await fixture.prepare()
            try FileManager.default.removeItem(at: workspace.state.appendingPathComponent("prepared-sha"))
            let journal = workspace.state.appendingPathComponent("pending-preparation")
            let bytes = Data("not a preparation journal".utf8)
            try bytes.write(to: journal)
            await #expect(throws: (any Error).self) { _ = try await fixture.prepare() }
            #expect(try Data(contentsOf: journal) == bytes)
        }

        @Test func refusesForeignPreparationJournal() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let workspace = try await fixture.prepare()
            let identity = try LocalWorkspaceService.identity(for: fixture.request)
            try FileManager.default.removeItem(at: workspace.state.appendingPathComponent("prepared-sha"))
            let bytes = try JSONEncoder().encode([
                "workspace": fixture.clone.path, "clone": fixture.clone.path,
                "common": fixture.clone.appendingPathComponent(".git").path, "branch": identity.branchReference,
                "headSHA": fixture.head, "baseSHA": fixture.base,
            ])
            let journal = workspace.state.appendingPathComponent("pending-preparation")
            try bytes.write(to: journal)
            await #expect(throws: (any Error).self) { _ = try await fixture.prepare() }
            #expect(try Data(contentsOf: journal) == bytes)
        }

        @Test func refusesForeignRegistration() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let workspace = try await fixture.prepare()
            let registration = try await LocalWorkspaceSafety.gitPath(workspace.url, "--absolute-git-dir")
            let pointer = registration.appendingPathComponent("gitdir")
            try Data("/foreign/.git\n".utf8).write(to: pointer)
            await #expect(throws: (any Error).self) { _ = try await fixture.prepare() }
            #expect(try String(contentsOf: pointer, encoding: .utf8) == "/foreign/.git\n")
        }

        @Test func refusesHeldWorkspaceOperationLock() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let layout = try LocalWorkspaceSafety.Layout(root: fixture.root, identity: LocalWorkspaceService.identity(for: fixture.request))
            let lock = try LocalWorkspaceLock(state: layout.state)
            defer { withExtendedLifetime(lock) {} }
            await #expect(throws: (any Error).self) { _ = try await fixture.prepare() }
            #expect(!LocalWorkspaceSafety.exists(layout.workspace))
        }

        @Test(arguments: [false, true])
        func preparesExactBaseSnapshotWhenBaseBranchHasAdvanced(_ reuse: Bool) async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            if reuse {
                _ = try await fixture.prepare()
            }
            // These objects exist only on the remote. The API snapshot is neither
            // the mapped clone's HEAD nor the now-advanced base branch's tip.
            let tree = try await Fixture.git(fixture.remote, ["rev-parse", "refs/heads/main^{tree}"])
            let author = ["-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid"]
            let snapshot = try await Fixture.git(fixture.remote, author + [
                "commit-tree", tree, "-p", fixture.base, "-m", "API base snapshot",
            ])
            let latestBase = try await Fixture.git(fixture.remote, author + [
                "commit-tree", tree, "-p", snapshot, "-m", "later base-branch commit",
            ])
            _ = try await Fixture.git(fixture.remote, ["update-ref", "refs/heads/main", latestBase])
            let metadata = LocalWorkspaceService.Metadata(headSHA: fixture.head, baseSHA: snapshot, title: "Untitled")
            let workspace = try await LocalWorkspaceService.shared.prepare(
                pullRequestURL: fixture.request, clone: fixture.clone, root: fixture.root
            ) { metadata }
            let identity = try LocalWorkspaceService.identity(for: fixture.request)
            #expect(workspace.headSHA == fixture.head)
            #expect(workspace.baseSHA == snapshot)
            #expect(try await Fixture.git(workspace.url, ["rev-parse", "HEAD"]) == fixture.head)
            #expect(try await Fixture.git(fixture.clone, ["rev-parse", identity.baseReference]) == snapshot)
            #expect(try await Fixture.git(fixture.clone, ["rev-parse", "HEAD"]) == fixture.base)
            #expect(try await Fixture.git(fixture.remote, ["rev-parse", "refs/heads/main"]) == latestBase)
        }

        @Test func automaticallyReconcilesStaleAPIHeadWithoutChangingCloneCheckout() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let previous = try await fixture.prepare()
            let cloneHead = try await Fixture.git(fixture.clone, ["rev-parse", "HEAD"])
            try await fixture.advanceRemote(replacingHead: true, advanceBase: true)
            let snapshots = MetadataSnapshots(
                initial: .init(headSHA: previous.headSHA, baseSHA: previous.baseSHA, title: "Untitled"),
                refreshed: .init(headSHA: fixture.head, baseSHA: fixture.base, title: "Untitled")
            )
            let workspace = try await LocalWorkspaceService.shared.prepare(
                pullRequestURL: fixture.request, clone: fixture.clone, root: fixture.root
            ) { await snapshots.next() }
            #expect(await snapshots.requests == 2)
            #expect(workspace.url == previous.url)
            #expect(workspace.headSHA == fixture.head && workspace.baseSHA == fixture.base)
            #expect(try await Fixture.git(workspace.url, ["rev-parse", "HEAD"]) == fixture.head)
            #expect(try LocalWorkspaceSafety.preparedSHA(workspace.state) == fixture.head)
            #expect(try await Fixture.git(fixture.clone, ["rev-parse", "HEAD"]) == cloneHead)
            #expect(try await Fixture.git(fixture.clone, ["for-each-ref", "--format=%(refname)", "refs/preek-fetch/"]).isEmpty)
        }

        @Test func refusesRemoteSnapshotMismatch() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let metadata = LocalWorkspaceService.Metadata(headSHA: String(repeating: "0", count: 40), baseSHA: fixture.base, title: "Untitled")
            let snapshots = MetadataSnapshots(initial: metadata, refreshed: metadata)
            await #expect(throws: LocalActionError.self) {
                _ = try await LocalWorkspaceService.shared.prepare(
                    pullRequestURL: fixture.request, clone: fixture.clone, root: fixture.root
                ) { await snapshots.next() }
            }
            #expect(await snapshots.requests == 3)
            let layout = try LocalWorkspaceSafety.Layout(root: fixture.root, identity: LocalWorkspaceService.identity(for: fixture.request))
            #expect(!LocalWorkspaceSafety.exists(layout.workspace))
            #expect(try await Fixture.git(fixture.clone, ["for-each-ref", "--format=%(refname)", "refs/preek-fetch/"]).isEmpty)
            #expect(try await Fixture.git(fixture.clone, ["rev-parse", "HEAD"]) == fixture.base)
        }

        @Test func recreatesRetainedBranchAndBacksUpDivergentLocalCommits() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let first = try await fixture.prepare()
            _ = try await Fixture.git(fixture.clone, ["worktree", "remove", first.url.path])
            try FileManager.default.removeItem(at: first.state.appendingPathComponent("prepared-sha"))
            let second = try await fixture.prepare()
            #expect(second.headSHA == fixture.head)
            try Data("local commit\n".utf8).write(to: second.url.appendingPathComponent("tracked.txt"))
            _ = try await Fixture.git(second.url, ["commit", "-am", "local only"])
            let local = try await Fixture.git(second.url, ["rev-parse", "HEAD"])
            _ = try await Fixture.git(fixture.clone, ["worktree", "remove", second.url.path])
            try FileManager.default.removeItem(at: second.state.appendingPathComponent("prepared-sha"))
            let recreated = try await fixture.prepare()
            let identity = try LocalWorkspaceService.identity(for: fixture.request)
            #expect(recreated.headSHA == fixture.head)
            #expect(try await Fixture.git(recreated.url, ["rev-parse", "HEAD"]) == fixture.head)
            let backups = try await Fixture.git(fixture.clone, ["for-each-ref", "--format=%(objectname)", "refs/preek/\(identity.referenceSuffix)/backups/"])
            #expect(backups.split(separator: "\n").contains(Substring(local)))
        }

        @Test func cleanedWorkspaceReopensAtForcePushedHeadWithRetainedTipBackup() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let first = try await fixture.prepare()
            let oldHead = first.headSHA
            _ = try await Fixture.git(fixture.clone, ["worktree", "remove", "--", first.url.path])
            try FileManager.default.removeItem(at: first.state.appendingPathComponent("prepared-sha"))
            try await fixture.advanceRemote(replacingHead: true)
            let reopened = try await fixture.prepare()
            let identity = try LocalWorkspaceService.identity(for: fixture.request)
            #expect(reopened.url == first.url)
            #expect(reopened.headSHA == fixture.head && reopened.headSHA != oldHead)
            #expect(try await Fixture.git(reopened.url, ["rev-parse", "HEAD"]) == fixture.head)
            let backups = try await Fixture.git(fixture.clone, ["for-each-ref", "--format=%(objectname)", "refs/preek/\(identity.referenceSuffix)/backups/"])
            #expect(backups.split(separator: "\n").contains(Substring(oldHead)))
        }

        @Test(arguments: [".github", "foo..bar", "example.lock", "ordinary-repo"])
        func preparesRepositoriesRequiringGitRefEncoding(_ repository: String) async throws {
            let fixture = try await Fixture(repository: repository)
            defer { fixture.remove() }
            let workspace = try await fixture.prepare()
            let identity = try LocalWorkspaceService.identity(for: fixture.request)
            for reference in [identity.branchReference, identity.headReference, identity.baseReference] {
                _ = try await Fixture.git(fixture.clone, ["check-ref-format", reference])
            }
            #expect(workspace.url.path.hasSuffix("/owner/\(repository)/untitled--pr-1"))
            #expect(try await Fixture.git(workspace.url, ["symbolic-ref", "HEAD"]) == identity.branchReference)
            #expect(try await Fixture.git(fixture.clone, ["rev-parse", identity.headReference]) == fixture.head)
        }

        @Test func concurrentPreparationsUsePrivateRefsWithoutTouchingFetchHead() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let firstHead = fixture.head
            try await fixture.advanceRemote()
            _ = try await Fixture.git(fixture.clone, ["config", "--unset-all", "remote.origin.fetch"])
            let secondHead = fixture.head
            _ = try await Fixture.git(fixture.clone, ["push", "--force", fixture.remote.path, "\(firstHead):refs/pull/1/head", "\(secondHead):refs/pull/2/head"])
            let fetchHead = fixture.clone.appendingPathComponent(".git/FETCH_HEAD")
            let bytes = Data("ordinary developer fetch owns this data\n".utf8)
            try bytes.write(to: fetchHead)
            let firstMetadata = LocalWorkspaceService.Metadata(headSHA: firstHead, baseSHA: fixture.base, title: "Same title")
            let secondMetadata = LocalWorkspaceService.Metadata(headSHA: secondHead, baseSHA: fixture.base, title: "Same title")
            let secondURL = try #require(URL(string: "https://fixture.invalid/owner/repo/pull/2"))
            async let first = LocalWorkspaceService.shared.prepare(
                pullRequestURL: fixture.request, clone: fixture.clone, root: fixture.root
            ) { firstMetadata }
            async let second = LocalWorkspaceService.shared.prepare(
                pullRequestURL: secondURL, clone: fixture.clone, root: fixture.root
            ) { secondMetadata }
            let results = try await(first, second)
            #expect(results.0.headSHA == firstHead)
            #expect(results.1.headSHA == secondHead)
            #expect(results.0.url.lastPathComponent == "same-title--pr-1")
            #expect(results.1.url.lastPathComponent == "same-title--pr-2")
            #expect(try await Fixture.git(results.0.url, ["rev-parse", "HEAD"]) == firstHead)
            #expect(try await Fixture.git(results.1.url, ["rev-parse", "HEAD"]) == secondHead)
            #expect(try Data(contentsOf: fetchHead) == bytes)
            #expect(try await Fixture.git(fixture.clone, ["for-each-ref", "--format=%(refname)", "refs/preek-fetch/"]).isEmpty)
        }

        @Test func refreshRefusesIgnoredIncomingFileCreatedAfterInspection() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let workspace = try await fixture.prepare()
            try Data("local commit\n".utf8).write(to: workspace.url.appendingPathComponent("local.txt"))
            _ = try await Fixture.git(workspace.url, ["add", "local.txt"])
            _ = try await Fixture.git(workspace.url, ["commit", "-m", "local work"])
            let local = try await Fixture.git(workspace.url, ["rev-parse", "HEAD"])
            _ = try await Fixture.git(fixture.clone, ["switch", "--detach", fixture.head])
            try Data("incoming committed bytes\n".utf8).write(to: fixture.clone.appendingPathComponent("ignored.txt"))
            _ = try await Fixture.git(fixture.clone, ["add", "ignored.txt"])
            _ = try await Fixture.git(fixture.clone, ["commit", "-m", "track formerly ignored path"])
            fixture.head = try await Fixture.git(fixture.clone, ["rev-parse", "HEAD"])
            _ = try await Fixture.git(fixture.clone, ["push", fixture.remote.path, "HEAD:refs/pull/1/head"])
            _ = try await Fixture.git(fixture.clone, ["switch", "main"])
            try Data("ignored.txt\n".utf8).write(to: fixture.clone.appendingPathComponent(".git/info/exclude"))
            #expect(try await LocalWorkspaceSafety.refreshWarning(workspace.url, common: fixture.clone.appendingPathComponent(".git")) == nil)
            let hook = fixture.clone.appendingPathComponent(".git/hooks/reference-transaction")
            // The local backup is written after final inspection. Checkout itself must refuse.
            let endangered = workspace.url.appendingPathComponent("ignored.txt")
            let quoted = "'" + endangered.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
            let script = """
            #!/bin/sh
            if [ "$1" = committed ]; then
              while read old new ref; do
                case "$ref" in
                  refs/preek/*/backups/*) printf 'precious ignored bytes\\n' > \(quoted);;
                esac
              done
            fi
            """
            try Data((script + "\n").utf8).write(to: hook)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: hook.path)
            await #expect(throws: (any Error).self) { _ = try await fixture.prepare() }
            #expect(try String(contentsOf: endangered, encoding: .utf8) == "precious ignored bytes\n")
            let identity = try LocalWorkspaceService.identity(for: fixture.request)
            #expect(try await Fixture.git(workspace.url, ["rev-parse", "HEAD"]) == local)
            #expect(try await Fixture.git(fixture.clone, ["rev-parse", identity.branchReference]) == local)
            #expect(try LocalWorkspaceSafety.preparedSHA(workspace.state) == workspace.headSHA)
        }

        @Test func failedForceCheckoutRetriesWithoutLosingHookEditsOrCommits() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let workspace = try await fixture.prepare()
            try Data("old local commit\n".utf8).write(to: workspace.url.appendingPathComponent("tracked.txt"))
            _ = try await Fixture.git(workspace.url, ["commit", "-am", "old local work"])
            let displaced = try await Fixture.git(workspace.url, ["rev-parse", "HEAD"])
            try await fixture.advanceRemote(replacingHead: true)
            try fixture.installCheckoutHook("printf 'force hook bytes\\n' > hook-data.txt\nexit 1")
            let metadata = LocalWorkspaceService.Metadata(headSHA: fixture.head, baseSHA: fixture.base, title: "Untitled")
            await #expect(throws: (any Error).self) {
                _ = try await LocalWorkspaceService.shared.forceUpdate(pullRequestURL: fixture.request, workspace: workspace) { metadata }
            }
            #expect(LocalWorkspaceSafety.ownedFile(workspace.state.appendingPathComponent("pending-preparation")))
            #expect(try await Fixture.git(workspace.url, ["rev-parse", "HEAD"]) == fixture.head)
            try Data("post-hook local commit\n".utf8).write(to: workspace.url.appendingPathComponent("tracked.txt"))
            _ = try await Fixture.git(workspace.url, ["commit", "-am", "after failed force hook"])
            let local = try await Fixture.git(workspace.url, ["rev-parse", "HEAD"])
            try Data("post-hook local edits\n".utf8).write(to: workspace.url.appendingPathComponent("tracked.txt"))
            try fixture.installCheckoutHook("exit 0")
            let recovered = try await fixture.reuseOffline()
            #expect(recovered.headSHA == local && recovered.updateWarning != nil)
            #expect(try String(contentsOf: recovered.url.appendingPathComponent("hook-data.txt"), encoding: .utf8) == "force hook bytes\n")
            #expect(try String(contentsOf: recovered.url.appendingPathComponent("tracked.txt"), encoding: .utf8) == "post-hook local edits\n")
            let identity = try LocalWorkspaceService.identity(for: fixture.request)
            let backups = try await Fixture.git(fixture.clone, ["for-each-ref", "--format=%(objectname)", "refs/preek/\(identity.referenceSuffix)/backups/"])
            #expect(backups.split(separator: "\n").contains(Substring(displaced)))
            #expect(!LocalWorkspaceSafety.exists(workspace.state.appendingPathComponent("pending-preparation")))
        }

        @Test(arguments: ["index.lock", "HEAD.lock", "packed-refs.lock", "refs/heads/preek/fixture.invalid/owner/repo/pr-1.lock"])
        func forceNeverRemovesSharedGitLocks(_ name: String) async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let workspace = try await fixture.prepare()
            let endangered = workspace.url.appendingPathComponent("tracked.txt")
            let localBytes = Data("local work survives shared lock refusal\n".utf8)
            try localBytes.write(to: endangered)
            let lock = fixture.clone.appendingPathComponent(".git").appendingPathComponent(name)
            try FileManager.default.createDirectory(at: lock.deletingLastPathComponent(), withIntermediateDirectories: true)
            let lockBytes = Data("shared lock owner\n".utf8)
            try lockBytes.write(to: lock)
            let metadata = LocalWorkspaceService.Metadata(headSHA: fixture.head, baseSHA: fixture.base, title: "Untitled")
            await #expect(throws: (any Error).self) {
                _ = try await LocalWorkspaceService.shared.forceUpdate(pullRequestURL: fixture.request, workspace: workspace) { metadata }
            }
            #expect(try Data(contentsOf: lock) == lockBytes)
            #expect(try Data(contentsOf: endangered) == localBytes)
        }

        @Test func forceRefusesDedicatedBranchCheckedOutElsewhere() async throws {
            let fixture = try await Fixture()
            defer { fixture.remove() }
            let workspace = try await fixture.prepare()
            _ = try await Fixture.git(workspace.url, ["checkout", "--detach"])
            let identity = try LocalWorkspaceService.identity(for: fixture.request)
            let other = fixture.directory.appendingPathComponent("unrelated-worktree")
            _ = try await Fixture.git(fixture.clone, ["worktree", "add", "--", other.path, identity.branch])
            let file = other.appendingPathComponent("keep.txt")
            let bytes = Data("unrelated checkout data\n".utf8)
            try bytes.write(to: file)
            let metadata = LocalWorkspaceService.Metadata(headSHA: fixture.head, baseSHA: fixture.base, title: "Untitled")
            await #expect(throws: (any Error).self) {
                _ = try await LocalWorkspaceService.shared.forceUpdate(pullRequestURL: fixture.request, workspace: workspace) { metadata }
            }
            #expect(try Data(contentsOf: file) == bytes)
            #expect(try await Fixture.git(other, ["symbolic-ref", "HEAD"]) == identity.branchReference)
            #expect(try await Fixture.git(workspace.url, ["rev-parse", "HEAD"]) == fixture.head)
        }

        @Test func preparesAndReusesWorkspaceWithExplicitHTTPSPort() async throws {
            let fixture = try await Fixture(authority: "fixture.invalid:8443")
            defer { fixture.remove() }
            let workspace = try await fixture.prepare()
            #expect(workspace.url.path.hasSuffix("/fixture.invalid:8443/owner/repo/untitled--pr-1"))
            #expect(try await Fixture.git(workspace.url, ["symbolic-ref", "--short", "HEAD"]) == "preek/fixture.invalid%3A8443/owner/repo/pr-1")
            let reused = try await fixture.prepare()
            #expect(reused.url == workspace.url)
            #expect(reused.headSHA == fixture.head)
        }

        @Test(arguments: ["http://github.com/o/r/pull/1", "https://github.com/o/r/pull/0", "https://github.com/o/r/pull/2147483648", "https://github.com/o/../pull/1", "https://github.com/o/r/pull/1/extra"])
        func rejectsUnsafeIdentities(_ value: String) throws {
            #expect(throws: (any Error).self) { try LocalWorkspaceService.identity(for: #require(URL(string: value))) }
        }

        @Test func drainsBothLargePipesAndReportsNonzeroStatus() async throws {
            let result = try await LocalCommand.run("/bin/sh", ["-c", "dd if=/dev/zero bs=65536 count=4 2>/dev/null; dd if=/dev/zero bs=65536 count=4 >&2 2>/dev/null; exit 7"])
            #expect(result.output.utf8.count == 262_144)
            #expect(result.error.utf8.count == 262_144)
            #expect(result.status == 7)
        }
    }
#endif
