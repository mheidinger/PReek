#if os(macOS)
    import Darwin
    import Foundation

    /// Shared physical-path, ownership, and Git registration invariants for local actions.
    enum LocalWorkspaceSafety {
        struct Layout: Sendable {
            static let maximumNameLength = 64

            let root: URL
            let workspace: URL
            let state: URL

            init(root: URL, identity: LocalWorkspaceService.Identity, workspaceName: String? = nil) {
                self.root = root
                workspace = root.appendingPathComponent(identity.repositoryKey, isDirectory: true)
                    .appendingPathComponent(workspaceName ?? "untitled--pr-\(identity.number)", isDirectory: true)
                state = root.appendingPathComponent(".preek-state", isDirectory: true)
                    .appendingPathComponent(identity.suffix, isDirectory: true)
            }

            /// State and locks stay keyed by PR number, independently of the frozen name.
            static func saved(root: URL, identity: LocalWorkspaceService.Identity) throws -> Layout {
                let layout = Layout(root: root, identity: identity)
                let file = layout.state.appendingPathComponent("workspace-name")
                guard LocalWorkspaceSafety.ownedDirectory(layout.state),
                      LocalWorkspaceSafety.ownedFile(file)
                else {
                    throw LocalActionError(message: "The saved workspace name is unsafe.")
                }
                let name = try String(contentsOf: file, encoding: .utf8)
                guard name.utf8.count <= maximumNameLength,
                      LocalWorkspaceSafety.matches(name, "[a-z0-9]+(?:-[a-z0-9]+)*--pr-\(identity.number)")
                else {
                    throw LocalActionError(message: "The saved workspace name does not match this PR.")
                }
                return Layout(root: root, identity: identity, workspaceName: name)
            }

            static func derived(workspace: URL, identity: LocalWorkspaceService.Identity) throws -> Layout {
                let root = identity.suffix.split(separator: "/").reduce(workspace) { path, _ in
                    path.deletingLastPathComponent()
                }
                let layout = try saved(root: root, identity: identity)
                guard root.path != "/", layout.workspace.path == workspace.path else {
                    throw LocalActionError(message: "The PR identity does not match the workspace path.")
                }
                return layout
            }

            static func validated(
                workspace: String,
                state: String,
                clone: String,
                pullRequest: String
            ) throws -> (Layout, LocalWorkspaceService.Identity) {
                let workspaceURL = URL(fileURLWithPath: workspace)
                let stateURL = URL(fileURLWithPath: state)
                let cloneURL = URL(fileURLWithPath: clone)
                guard [workspace, state, clone].allSatisfy({ $0.hasPrefix("/") && !$0.contains("\0") }),
                      workspaceURL.path == workspace,
                      stateURL.path == state,
                      cloneURL.path == clone,
                      LocalWorkspaceSafety.ownedDirectory(workspaceURL),
                      LocalWorkspaceSafety.ownedDirectory(stateURL),
                      LocalWorkspaceSafety.ownedDirectory(cloneURL)
                else {
                    throw LocalActionError(message: "Workspace, state, and clone must be owned physical directories.")
                }
                guard let pullRequestURL = URL(string: "https://" + pullRequest) else {
                    throw LocalActionError(message: "The registered PR identity is invalid.")
                }
                let identity = try LocalWorkspaceService.identity(for: pullRequestURL)
                let layout = try derived(workspace: workspaceURL, identity: identity)
                let root = layout.root
                guard root.path != "/",
                      layout.workspace.path == workspace,
                      layout.state.path == state,
                      clone != workspace,
                      !clone.hasPrefix(workspace + "/")
                else {
                    throw LocalActionError(message: "The PR identity, state, or clone does not match the workspace.")
                }
                return (layout, identity)
            }
        }

        /// Git's NUL-delimited listing preserves spaces and newlines in checkout paths.
        static func registeredWorktree(clone: URL, branch: String) async throws -> URL? {
            let listing = try await git(clone, ["worktree", "list", "--porcelain", "-z"])
            var path: String?
            var matches: [URL] = []
            for field in listing.components(separatedBy: "\0") {
                if field.hasPrefix("worktree ") {
                    path = String(field.dropFirst("worktree ".count))
                } else if field == "branch \(branch)", let path {
                    matches.append(URL(fileURLWithPath: path, isDirectory: true))
                } else if field.isEmpty {
                    path = nil
                }
            }
            guard matches.count <= 1 else {
                throw LocalActionError(message: "The PR branch has multiple worktree registrations. Nothing was changed.")
            }
            return matches.first
        }

        /// Foundation can normalize /private/var back to /var; Git uses POSIX physical paths.
        static func physicalURL(_ url: URL) throws -> URL {
            guard let path = realpath(url.path, nil) else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
            defer { free(path) }
            return URL(fileURLWithPath: String(cString: path), isDirectory: true)
        }

        private static func attributes(_ url: URL) -> stat? {
            var value = stat()
            return url.withUnsafeFileSystemRepresentation { path in
                guard let path, lstat(path, &value) == 0 else { return nil }
                return value
            }
        }

        static func exists(_ url: URL) -> Bool {
            attributes(url) != nil
        }

        static func isSymlink(_ url: URL) -> Bool {
            guard let value = attributes(url) else { return false }
            return value.st_mode & S_IFMT == S_IFLNK
        }

        static func ownedFile(_ url: URL) -> Bool {
            guard let value = attributes(url) else { return false }
            return value.st_mode & S_IFMT == S_IFREG && value.st_uid == getuid()
        }

        static func ownedDirectory(_ url: URL) -> Bool {
            guard let value = attributes(url) else { return false }
            return value.st_mode & S_IFMT == S_IFDIR && value.st_uid == getuid()
                && (try? physicalURL(url).path) == url.path
        }

        static func matches(_ value: String, _ pattern: String) -> Bool {
            value.range(of: "\\A(?:" + pattern + ")\\z", options: .regularExpression) != nil
        }

        static func validSHA(_ value: String) -> Bool {
            matches(value, "[0-9a-fA-F]{40}")
        }

        static func fileText(_ url: URL) throws -> String {
            try String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .newlines)
        }

        static func preparedSHA(_ state: URL) throws -> String {
            let marker = state.appendingPathComponent("prepared-sha")
            guard ownedFile(marker) else { throw LocalActionError(message: "The preparation marker is missing or unsafe.") }
            let sha = try fileText(marker)
            guard validSHA(sha) else { throw LocalActionError(message: "The preparation marker is invalid.") }
            return sha
        }

        static func git(_ directory: URL, _ arguments: [String]) async throws -> String {
            try await LocalCommand.checked("/usr/bin/git", arguments, directory: directory)
                .trimmingCharacters(in: .newlines)
        }

        static func gitPath(_ directory: URL, _ argument: String) async throws -> URL {
            let path = try await git(directory, ["rev-parse", argument])
            return path.hasPrefix("/") ? URL(fileURLWithPath: path) : directory.appendingPathComponent(path)
        }

        static func validateClone(_ clone: URL) async throws -> URL {
            guard ownedDirectory(clone), !isSymlink(clone.appendingPathComponent(".git")),
                  try await git(clone, ["rev-parse", "--show-toplevel"]) == clone.path
            else {
                throw LocalActionError(message: "Choose the root of an existing local Git clone.")
            }
            let common = try await gitPath(clone, "--git-common-dir")
            guard ownedDirectory(common) else {
                throw LocalActionError(message: "The mapped clone has unsafe Git metadata.")
            }
            return common
        }

        static func validateWorktree(
            _ workspace: URL,
            common: URL,
            requireUnlocked: Bool = false
        ) async throws {
            guard ownedDirectory(workspace),
                  ownedFile(workspace.appendingPathComponent(".git")),
                  try await git(workspace, ["rev-parse", "--show-toplevel"]) == workspace.path,
                  try await gitPath(workspace, "--git-common-dir").path == common.path
            else {
                throw LocalActionError(message: "The saved workspace belongs to a different clone or is not a registered worktree.")
            }
            let registration = try await gitPath(workspace, "--absolute-git-dir")
            let pointer = registration.appendingPathComponent("gitdir")
            guard registration.deletingLastPathComponent().path == common.appendingPathComponent("worktrees").path,
                  ownedDirectory(registration),
                  ownedFile(pointer),
                  !requireUnlocked || !exists(registration.appendingPathComponent("locked")),
                  try fileText(pointer) == workspace.appendingPathComponent(".git").path
            else {
                throw LocalActionError(message: "The worktree registration is foreign, locked, or unsafe.")
            }
        }

        static let operationMarkers = [
            "locked", "index.lock", "HEAD.lock", "MERGE_HEAD", "MERGE_AUTOSTASH", "AUTO_MERGE",
            "CHERRY_PICK_HEAD", "REVERT_HEAD", "REBASE_HEAD", "sequencer", "rebase-merge", "rebase-apply",
            "BISECT_LOG", "BISECT_START", "SQUASH_MSG",
        ]

        static func sharedLockWarning(common: URL, branch: String) -> String? {
            ["index.lock", "HEAD.lock", "packed-refs.lock", "\(branch).lock"].contains {
                exists(common.appendingPathComponent($0))
            } ? "A Git operation owns shared repository metadata." : nil
        }

        /// Synchronous so callers can retain a final check immediately before removal.
        static func operationWarning(registration: URL, common: URL, branch: String) -> String? {
            if operationMarkers.contains(where: { exists(registration.appendingPathComponent($0)) }) {
                return "A Git operation is in progress or the worktree is locked."
            }
            return sharedLockWarning(common: common, branch: branch)
        }

        /// Return only recoverable update hazards; ownership failures remain errors.
        static func refreshWarning(_ workspace: URL, common: URL) async throws -> String? {
            let registration = try await gitPath(workspace, "--absolute-git-dir")
            let branch = try await git(workspace, ["symbolic-ref", "-q", "HEAD"])
            if let warning = operationWarning(registration: registration, common: common, branch: branch) {
                return warning
            }
            let staged = try await git(workspace, ["ls-files", "--stage", "-z"])
            if staged.split(separator: "\0").contains(where: { $0.hasPrefix("160000 ") }) {
                return "The checkout contains a submodule."
            }
            let flags = try await git(workspace, ["ls-files", "-v", "-z"])
            if flags.split(separator: "\0").contains(where: {
                guard let flag = $0.first else { return false }
                return flag == "S" || ("a" ... "z").contains(String(flag))
            }) {
                return "Index flags can hide local changes."
            }
            let status = try await git(workspace, [
                "-c", "core.fsmonitor=false", "-c", "core.untrackedCache=false",
                "status", "--porcelain=v1", "--untracked-files=all",
                "--ignored=matching", "--ignore-submodules=none",
            ])
            return status.isEmpty ? nil : "The checkout contains staged, modified, untracked, or ignored files."
        }
    }
#endif
