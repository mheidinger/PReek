#if os(macOS)
    import Foundation

    /// Worktree preparation is identical for editor and agent consumers.
    actor LocalWorkspaceService {
        static let shared = LocalWorkspaceService()

        struct Identity: Sendable {
            let host: String
            let authority: String
            let owner: String
            let repository: String
            let number: Int
            var repositoryKey: String {
                "\(authority)/\(owner)/\(repository)"
            }

            var pullRequestKey: String {
                "\(repositoryKey)/pull/\(number)"
            }

            var suffix: String {
                "\(repositoryKey)/pr-\(number)"
            }

            /// The number identifies the PR; the bounded title is only a display name.
            func workspaceName(title: String) -> String {
                let suffix = "--pr-\(number)"
                let limit = LocalWorkspaceSafety.Layout.maximumNameLength - suffix.utf8.count
                let folded = title.folding(options: [.diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
                var slug: [UInt8] = []
                slug.reserveCapacity(limit)
                var separator = false
                for byte in folded.utf8 {
                    let lower = (UInt8(ascii: "A") ... UInt8(ascii: "Z")).contains(byte)
                        ? byte + (UInt8(ascii: "a") - UInt8(ascii: "A")) : byte
                    if (UInt8(ascii: "a") ... UInt8(ascii: "z")).contains(lower)
                        || (UInt8(ascii: "0") ... UInt8(ascii: "9")).contains(lower)
                    {
                        guard slug.count + (separator ? 1 : 0) < limit else { break }
                        if separator {
                            slug.append(UInt8(ascii: "-"))
                        }
                        slug.append(lower)
                        separator = false
                    } else if !slug.isEmpty {
                        separator = true
                    }
                }
                return (slug.isEmpty ? "untitled" : String(decoding: slug, as: UTF8.self)) + suffix
            }

            /// Percent escaping is injective, including components forbidden by Git.
            var referenceSuffix: String {
                [authority, owner, repository].map { component in
                    let escapeDots = component.hasPrefix(".") || component.contains("..") || component.hasSuffix(".lock")
                    return component.utf8.map { byte in
                        if byte == 37 || byte == 58 || (byte == 46 && escapeDots) {
                            return String(format: "%%%02X", byte)
                        }
                        return String(UnicodeScalar(byte))
                    }.joined()
                }.joined(separator: "/") + "/pr-\(number)"
            }

            var branch: String {
                "preek/\(referenceSuffix)"
            }

            var branchReference: String {
                "refs/heads/\(branch)"
            }

            var headReference: String {
                "refs/preek/\(referenceSuffix)/head"
            }

            var baseReference: String {
                "refs/preek/\(referenceSuffix)/base"
            }

            var url: URL {
                URL(string: "https://\(authority)/\(owner)/\(repository)/pull/\(number)")!
            }
        }

        struct PushDestination: Sendable {
            let repository: String
            let branch: String
        }

        struct Metadata: Sendable {
            let headSHA: String
            let baseSHA: String
            let title: String
            var pushDestination: PushDestination? = nil
        }

        struct PreparedWorkspace: Sendable {
            /// Only managed worktrees carry a layout eligible for replacement or cleanup.
            let layout: LocalWorkspaceSafety.Layout?
            var isManaged: Bool {
                layout != nil
            }

            var root: URL? {
                layout?.root
            }

            let url: URL
            let state: URL
            let clone: URL
            let headSHA: String
            let baseSHA: String
            var updateWarning: String?

            init(
                layout: LocalWorkspaceSafety.Layout, clone: URL, headSHA: String, baseSHA: String,
                updateWarning: String? = nil
            ) {
                self.layout = layout
                url = layout.workspace
                state = layout.state
                self.clone = clone
                self.headSHA = headSHA
                self.baseSHA = baseSHA
                self.updateWarning = updateWarning
            }

            init(checkout: URL, state: URL, headSHA: String, baseSHA: String, updateWarning: String? = nil) {
                layout = nil
                url = checkout
                self.state = state
                clone = checkout
                self.headSHA = headSHA
                self.baseSHA = baseSHA
                self.updateWarning = updateWarning
            }
        }

        nonisolated static func identity(for url: URL) throws -> Identity {
            let parts = url.path.split(separator: "/", omittingEmptySubsequences: false)
            guard url.scheme == "https",
                  url.user == nil,
                  url.password == nil,
                  let host = url.host?.lowercased(),
                  LocalWorkspaceSafety.matches(host, "[a-z0-9][a-z0-9.-]*"),
                  parts.count == 5 || (parts.count == 6 && parts.last == ""),
                  parts[0].isEmpty,
                  parts[3] == "pull",
                  LocalWorkspaceSafety.matches(String(parts[4]), "[1-9][0-9]{0,9}"),
                  let number = Int(parts[4]),
                  number <= Int32.max,
                  [parts[1], parts[2]].allSatisfy({
                      LocalWorkspaceSafety.matches(String($0), "[A-Za-z0-9_.-]+")
                          && $0 != "." && $0 != ".."
                  })
            else {
                throw LocalActionError(message: String(localized: "Expected an HTTPS GitHub pull request URL with an owner, repository, and PR number."))
            }
            return Identity(
                host: host,
                authority: host + (url.port.map { ":\($0)" } ?? ""),
                owner: parts[1].lowercased(),
                repository: parts[2].lowercased(),
                number: number
            )
        }

        struct InvalidRepository: LocalizedError {
            let message: String
            var errorDescription: String? {
                message
            }
        }

        /// Owned clean checkouts refresh before handoff; local data always takes priority.
        func prepare(
            pullRequestURL: URL,
            clone selectedClone: URL,
            root: URL,
            metadata: @Sendable () async throws -> Metadata
        ) async throws -> PreparedWorkspace {
            let identity = try Self.identity(for: pullRequestURL)
            let repository = try await inspectRepository(selectedClone, identity: identity)
            let managedWorkspace = try await LocalWorkspaceSafety.registeredWorktree(
                clone: repository.clone, branch: identity.branchReference
            )
            let hasManagedWorkspace = managedWorkspace != nil || LocalWorkspaceSafety.exists(
                LocalWorkspaceSafety.Layout(root: root.resolvingSymlinksInPath(), identity: identity)
                    .state.appendingPathComponent("workspace-name")
            )
            var initialMetadata: Metadata?
            if let branch = try await checkoutBranch(repository.clone), branch != identity.branchReference {
                let upstream = try await checkoutUpstream(repository.clone, branch: branch)
                // Saved push configuration identifies the source name without requiring a
                // network probe every time an unrelated clone opens a dirty managed worktree.
                let savedSource = !hasManagedWorkspace ? nil
                    : try await checkoutUpstream(repository.clone, branch: identity.branchReference)
                if upstream != nil || !hasManagedWorkspace || savedSource?.reference == branch {
                    let details = try await metadata()
                    initialMetadata = details
                    if try await matchesPullRequest(upstream, branch: branch, details: details, clone: repository.clone, identity: identity) {
                        return try await prepareExistingCheckout(
                            repository: repository, identity: identity, branch: branch, upstream: upstream,
                            root: root, initialMetadata: details, metadata: metadata
                        )
                    }
                }
            }
            let layout: LocalWorkspaceSafety.Layout
            if let workspace = managedWorkspace {
                // The branch, not the latest preference, locates an already active checkout.
                layout = try LocalWorkspaceSafety.Layout.derived(workspace: workspace, identity: identity)
                let actualRoot = layout.root
                guard actualRoot.path != "/",
                      layout.workspace.path == workspace.path,
                      layout.workspace.path != repository.clone.path,
                      !repository.clone.path.hasPrefix(layout.workspace.path + "/"),
                      LocalWorkspaceSafety.ownedDirectory(actualRoot),
                      LocalWorkspaceSafety.ownedDirectory(layout.workspace),
                      LocalWorkspaceSafety.ownedDirectory(layout.state)
                else {
                    throw LocalActionError(message: String(localized: "The PR branch is checked out outside an owned PReek workspace. Nothing was changed."))
                }
            } else {
                layout = try prepareLayout(root: root, identity: identity, clone: repository.clone)
            }
            // Preparation and reuse both hold the same stable-inode operation lock throughout.
            let lock = try LocalWorkspaceLock(state: layout.state)
            defer { withExtendedLifetime(lock) {} }
            try FileManager.default.createDirectory(
                at: layout.state,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            guard LocalWorkspaceSafety.ownedDirectory(layout.state) else {
                throw LocalActionError(message: String(localized: "The workspace state is redirected or not owned by this account."))
            }
            if LocalWorkspaceSafety.exists(layout.state.appendingPathComponent("workspace-name")) {
                guard try LocalWorkspaceSafety.Layout.saved(root: layout.root, identity: identity).workspace == layout.workspace else {
                    throw LocalActionError(message: String(localized: "The saved workspace name changed during preparation. Nothing was changed."))
                }
            } else if LocalWorkspaceSafety.exists(layout.workspace)
                || LocalWorkspaceSafety.exists(layout.state.appendingPathComponent("prepared-sha"))
                || LocalWorkspaceSafety.exists(layout.state.appendingPathComponent("pending-preparation"))
            {
                throw LocalActionError(message: String(localized: "The existing PR workspace has no saved name. Nothing was changed."))
            }
            if LocalWorkspaceSafety.exists(layout.state.appendingPathComponent("pending-preparation")) {
                let pending = try readPending(layout, repository: repository, identity: identity)
                _ = try await finishPreparation(pending, layout: layout, repository: repository, identity: identity)
                return try await reuseWorkspace(layout, repository: repository, identity: identity, initialMetadata: initialMetadata, metadata: metadata)
            }
            if LocalWorkspaceSafety.exists(layout.workspace) {
                return try await reuseWorkspace(layout, repository: repository, identity: identity, initialMetadata: initialMetadata, metadata: metadata)
            }
            guard !LocalWorkspaceSafety.exists(layout.state.appendingPathComponent("prepared-sha")) else {
                throw LocalActionError(message: String(localized: "The saved PR workspace is missing. Restore it or deliberately remove its PReek state before recreating it."))
            }
            return try await createWorkspace(layout, repository: repository, identity: identity, initialMetadata: initialMetadata, metadata: metadata)
        }

        /// Explicitly confirmed replacement using Git-owned worktree removal.
        /// The journal precedes destruction; retries never reset a recreated checkout.
        func forceUpdate(
            pullRequestURL: URL,
            workspace: PreparedWorkspace,
            metadata: @Sendable () async throws -> Metadata
        ) async throws -> PreparedWorkspace {
            guard workspace.isManaged else {
                throw LocalActionError(message: String(localized: "Force update is only available for PReek-managed worktrees. Your existing checkout was not changed."))
            }
            let identity = try Self.identity(for: pullRequestURL)
            let (layout, _) = try LocalWorkspaceSafety.Layout.validated(
                workspace: workspace.url.path, state: workspace.state.path,
                clone: workspace.clone.path,
                pullRequest: identity.pullRequestKey
            )
            let lock = try LocalWorkspaceLock(state: layout.state)
            defer { withExtendedLifetime(lock) {} }
            let repository = try await inspectRepository(workspace.clone, identity: identity)
            _ = try LocalWorkspaceSafety.preparedSHA(layout.state)
            try await LocalWorkspaceSafety.validateWorktree(layout.workspace, common: repository.common)
            let details = try await fetchMetadata(repository: repository, identity: identity, metadata: metadata)
            // A fetch must succeed before any local data is discarded.
            _ = try LocalWorkspaceSafety.Layout.validated(
                workspace: workspace.url.path, state: workspace.state.path,
                clone: workspace.clone.path,
                pullRequest: identity.pullRequestKey
            )
            try await LocalWorkspaceSafety.validateWorktree(layout.workspace, common: repository.common)
            if let other = try await LocalWorkspaceSafety.registeredWorktree(clone: repository.clone, branch: identity.branchReference),
               other.path != layout.workspace.path
            {
                throw LocalActionError(message: String(localized: "The PR branch is checked out in another worktree. That unrelated checkout was not changed."))
            }
            try await saveRepositoryState(details, repository: repository, identity: identity)
            let pending = try PendingPreparation(
                workspace: layout.workspace.path, clone: repository.clone.path, common: repository.common.path,
                branch: identity.branchReference, headSHA: details.headSHA, baseSHA: details.baseSHA,
                previousPreparedSHA: LocalWorkspaceSafety.preparedSHA(layout.state), removalRequired: true
            )
            try writePending(pending, layout: layout)
            return try await finishPreparation(pending, layout: layout, repository: repository, identity: identity)
        }

        private struct Repository {
            let clone: URL
            let common: URL
            let remote: String
        }

        private struct Upstream: Equatable {
            let remote: String
            let reference: String
        }

        private func checkoutBranch(_ checkout: URL) async throws -> String? {
            let result = try await LocalCommand.run("/usr/bin/git", ["symbolic-ref", "-q", "HEAD"], directory: checkout)
            if result.status == 1 {
                return nil
            }
            guard result.status == 0 else {
                throw LocalActionError(message: String(localized: "Could not inspect the checkout branch: \(result.error)"))
            }
            return result.output.trimmingCharacters(in: .newlines)
        }

        private func checkoutUpstream(_ checkout: URL, branch: String) async throws -> Upstream? {
            let fields = try await LocalWorkspaceSafety.git(checkout, [
                "for-each-ref", "--format=%(upstream:remotename)%00%(upstream:remoteref)", "--", branch,
            ]).split(separator: "\0", omittingEmptySubsequences: false)
            guard fields.count == 2, !fields[0].isEmpty, !fields[1].isEmpty, fields[0] != "." else { return nil }
            return Upstream(remote: String(fields[0]), reference: String(fields[1]))
        }

        private func matchesPullRequest(
            _ upstream: Upstream?, branch: String, details: Metadata, clone: URL, identity: Identity
        ) async throws -> Bool {
            guard let destination = details.pushDestination,
                  (upstream?.reference ?? branch) == "refs/heads/\(destination.branch)",
                  let url = URL(string: "https://\(identity.authority)/\(destination.repository)/pull/\(identity.number)")
            else { return false }
            let headIdentity = try Self.identity(for: url)
            guard destination.repository.lowercased() == "\(headIdentity.owner)/\(headIdentity.repository)" else {
                throw LocalActionError(message: String(localized: "GitHub returned an invalid PR head repository."))
            }
            _ = try await LocalWorkspaceSafety.git(clone, ["check-ref-format", "refs/heads/\(destination.branch)"])
            if let upstream {
                let urls = try await LocalWorkspaceSafety.git(clone, ["remote", "get-url", "--all", upstream.remote])
                    .split(separator: "\n")
                return !urls.isEmpty && urls.allSatisfy { Self.remoteMatches(String($0), identity: headIdentity) }
            }
            // Without tracking, only an exact source-branch name and matching source
            // repository remote establish identity. A coincidentally equal SHA does not.
            return try await findMatchingRemote(clone: clone, identity: headIdentity) != nil
        }

        /// User-owned checkouts are never reset, reconfigured, or registered for cleanup.
        private func prepareExistingCheckout(
            repository: Repository, identity: Identity, branch: String, upstream: Upstream?,
            root: URL, initialMetadata: Metadata, metadata: @Sendable () async throws -> Metadata
        ) async throws -> PreparedWorkspace {
            guard LocalWorkspaceSafety.validSHA(initialMetadata.headSHA), LocalWorkspaceSafety.validSHA(initialMetadata.baseSHA),
                  root.path.hasPrefix("/"), !root.path.contains("\0")
            else {
                throw LocalActionError(message: String(localized: "The PR metadata or workspace root is invalid."))
            }
            let clone = repository.clone
            var ancestor = root.standardizedFileURL
            var missing: [String] = []
            while !LocalWorkspaceSafety.exists(ancestor) {
                missing.append(ancestor.lastPathComponent)
                ancestor.deleteLastPathComponent()
            }
            let physicalRoot = try missing.reversed().reduce(LocalWorkspaceSafety.physicalURL(ancestor)) {
                $0.appendingPathComponent($1, isDirectory: true)
            }
            guard physicalRoot.path != clone.path, !physicalRoot.path.hasPrefix(clone.path + "/"),
                  physicalRoot.path != repository.common.path, !physicalRoot.path.hasPrefix(repository.common.path + "/")
            else {
                throw LocalActionError(message: String(localized: "State for an existing checkout must be outside its repository and Git metadata."))
            }
            try FileManager.default.createDirectory(at: physicalRoot, withIntermediateDirectories: true)
            guard LocalWorkspaceSafety.ownedDirectory(physicalRoot) else {
                throw LocalActionError(message: String(localized: "The existing checkout state root is unsafe."))
            }
            var state = physicalRoot
            for component in [".preek-existing"] + identity.suffix.split(separator: "/").map(String.init) {
                state.appendPathComponent(component, isDirectory: true)
                try FileManager.default.createDirectory(at: state, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                guard LocalWorkspaceSafety.ownedDirectory(state) else {
                    throw LocalActionError(message: String(localized: "The existing checkout state is redirected or not owned by this account."))
                }
            }
            let lock = try LocalWorkspaceLock(state: state)
            defer { withExtendedLifetime(lock) {} }
            let head = try await LocalWorkspaceSafety.git(clone, ["rev-parse", "HEAD"])
            func prepared(_ current: String, _ details: Metadata, warning: String? = nil) -> PreparedWorkspace {
                PreparedWorkspace(
                    checkout: clone, state: state, headSHA: current, baseSHA: details.baseSHA,
                    updateWarning: warning.map { String(localized: "The existing checkout was not updated: \($0) Opening it unchanged.") }
                )
            }
            try await validateExistingCheckout(repository, branch: branch, upstream: upstream)
            if let reason = try await LocalWorkspaceSafety.refreshWarning(clone, common: repository.common) {
                return prepared(head, initialMetadata, warning: reason)
            }
            let details = try await fetchMetadata(
                repository: repository, identity: identity, initialMetadata: initialMetadata, metadata: metadata
            )
            try await validateExistingCheckout(repository, branch: branch, upstream: upstream)
            guard try await matchesPullRequest(upstream, branch: branch, details: details, clone: clone, identity: identity) else {
                throw LocalActionError(message: String(localized: "The PR source branch changed while fetching. The checkout was not updated."))
            }
            let currentHead = try await LocalWorkspaceSafety.git(clone, ["rev-parse", "HEAD"])
            let warning = try await LocalWorkspaceSafety.refreshWarning(clone, common: repository.common)
            if currentHead != head || warning != nil {
                return prepared(currentHead, details, warning: warning ?? String(localized: "HEAD changed while fetching."))
            }
            // An already-ahead branch contains all PR changes; preserve its local commits.
            let includesHead = try await LocalCommand.run(
                "/usr/bin/git", ["merge-base", "--is-ancestor", details.headSHA, head], directory: clone
            )
            if includesHead.status == 0 {
                return prepared(head, details)
            }
            guard includesHead.status == 1 else {
                throw LocalActionError(message: String(localized: "Could not inspect the existing checkout history: \(includesHead.error)"))
            }
            let fastForward = try await LocalCommand.run(
                "/usr/bin/git", ["merge-base", "--is-ancestor", head, details.headSHA], directory: clone
            )
            if fastForward.status == 1 {
                return prepared(head, details, warning: String(localized: "The branch has diverged from the PR. Resolve its history manually; PReek will not reset or rebase your branch."))
            }
            guard fastForward.status == 0 else {
                throw LocalActionError(message: String(localized: "Could not inspect the PR history: \(fastForward.error)"))
            }
            try await validateExistingCheckout(repository, branch: branch, upstream: upstream)
            let finalWarning = try await LocalWorkspaceSafety.refreshWarning(clone, common: repository.common)
            let finalHead = try await LocalWorkspaceSafety.git(clone, ["rev-parse", "HEAD"])
            if finalHead != head || finalWarning != nil {
                return prepared(finalHead, details, warning: finalWarning ?? String(localized: "HEAD changed before its update."))
            }
            try Task.checkCancellation()
            _ = try await LocalWorkspaceSafety.git(clone, [
                "merge", "--ff-only", "--no-edit", "--no-overwrite-ignore", details.headSHA,
            ])
            try await validateExistingCheckout(repository, branch: branch, upstream: upstream)
            let updatedHead = try await LocalWorkspaceSafety.git(clone, ["rev-parse", "HEAD"])
            guard updatedHead == details.headSHA else {
                throw LocalActionError(message: String(localized: "The checkout changed during its update. The local action was not launched."))
            }
            return prepared(updatedHead, details)
        }

        private func validateExistingCheckout(_ repository: Repository, branch: String, upstream: Upstream?) async throws {
            let clone = repository.clone
            guard try await LocalWorkspaceSafety.validateClone(clone) == repository.common,
                  try await checkoutBranch(clone) == branch,
                  try await checkoutUpstream(clone, branch: branch) == upstream
            else {
                throw LocalActionError(message: String(localized: "The checkout or upstream branch changed. The local action was not launched."))
            }
            if LocalWorkspaceSafety.ownedFile(clone.appendingPathComponent(".git")) {
                try await LocalWorkspaceSafety.validateWorktree(clone, common: repository.common)
            }
        }

        private func inspectRepository(_ selectedClone: URL, identity: Identity) async throws -> Repository {
            do {
                let clone = try LocalWorkspaceSafety.physicalURL(selectedClone)
                let common = try await LocalWorkspaceSafety.validateClone(clone)
                let remote = try await matchingRemote(clone: clone, identity: identity)
                return Repository(clone: clone, common: common, remote: remote)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw InvalidRepository(message: error.localizedDescription)
            }
        }

        private func prepareLayout(root: URL, identity: Identity, clone: URL) throws -> LocalWorkspaceSafety.Layout {
            guard root.path.hasPrefix("/"), !root.path.contains("\0") else {
                throw LocalActionError(message: String(localized: "The workspace root must be an absolute path."))
            }
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let physicalRoot = try LocalWorkspaceSafety.physicalURL(root)
            let initial = LocalWorkspaceSafety.Layout(root: physicalRoot, identity: identity)
            let layout = LocalWorkspaceSafety.exists(initial.state.appendingPathComponent("workspace-name"))
                ? try LocalWorkspaceSafety.Layout.saved(root: physicalRoot, identity: identity) : initial
            guard layout.workspace.path != clone.path, !clone.path.hasPrefix(layout.workspace.path + "/") else {
                throw LocalActionError(message: String(localized: "The mapped clone must not be inside its PR workspace."))
            }
            return layout
        }

        /// Refresh even rewritten PR history, retaining any locally created commits.
        private func reuseWorkspace(
            _ layout: LocalWorkspaceSafety.Layout,
            repository: Repository,
            identity: Identity,
            initialMetadata: Metadata? = nil,
            metadata: @Sendable () async throws -> Metadata
        ) async throws -> PreparedWorkspace {
            guard LocalWorkspaceSafety.ownedDirectory(layout.workspace) else {
                throw LocalActionError(message: String(localized: "An unmanaged folder occupies the PR workspace. Nothing was overwritten."))
            }
            let prepared = try LocalWorkspaceSafety.preparedSHA(layout.state)
            _ = try await LocalWorkspaceSafety.git(repository.clone, ["cat-file", "-e", "\(prepared)^{commit}"])
            try await LocalWorkspaceSafety.validateWorktree(layout.workspace, common: repository.common)
            let branch = try await LocalCommand.run("/usr/bin/git", ["symbolic-ref", "-q", "HEAD"], directory: layout.workspace)
            let head = try await LocalWorkspaceSafety.git(layout.workspace, ["rev-parse", "HEAD"])
            let base = try await LocalWorkspaceSafety.git(
                repository.clone, ["rev-parse", identity.baseReference]
            )
            guard LocalWorkspaceSafety.validSHA(head), LocalWorkspaceSafety.validSHA(base) else {
                throw LocalActionError(message: String(localized: "The workspace has invalid local commit references."))
            }
            func unchanged(head: String, reason: String) -> PreparedWorkspace {
                PreparedWorkspace(
                    layout: layout, clone: repository.clone, headSHA: head, baseSHA: base,
                    updateWarning: String(localized: "The PR workspace was not updated: \(reason) Opening the existing checkout unchanged.")
                )
            }
            if branch.status != 0 || branch.output.trimmingCharacters(in: .newlines) != identity.branchReference {
                return unchanged(head: head, reason: String(localized: "The PR workspace is detached or on another branch. Force update to replace it with the PR checkout."))
            }
            if let reason = try await LocalWorkspaceSafety.refreshWarning(layout.workspace, common: repository.common) {
                let unchangedHead = try await LocalWorkspaceSafety.git(layout.workspace, ["rev-parse", "HEAD"])
                return unchanged(head: unchangedHead, reason: reason)
            }
            let details = try await fetchMetadata(repository: repository, identity: identity, initialMetadata: initialMetadata, metadata: metadata)
            // Fetching can take a long time. Revalidate ownership, markers, branch,
            // HEAD, and all local-data guards before touching the checkout.
            try await LocalWorkspaceSafety.validateWorktree(layout.workspace, common: repository.common)
            guard try LocalWorkspaceSafety.preparedSHA(layout.state) == prepared,
                  try await LocalWorkspaceSafety.git(layout.workspace, ["symbolic-ref", "-q", "HEAD"]) == identity.branchReference
            else {
                throw LocalActionError(message: String(localized: "The workspace ownership or PR branch changed while fetching. Nothing was reset."))
            }
            let reason = try await LocalWorkspaceSafety.refreshWarning(layout.workspace, common: repository.common)
            let currentHead = try await LocalWorkspaceSafety.git(layout.workspace, ["rev-parse", "HEAD"])
            if currentHead != head || reason != nil {
                return unchanged(head: currentHead, reason: reason ?? String(localized: "HEAD changed while fetching."))
            }
            if head != details.headSHA {
                if head != prepared {
                    // Unique refs survive reflog expiry and subsequent refreshes.
                    try await backup(head, repository: repository, identity: identity)
                }
                let finalHead = try await LocalWorkspaceSafety.git(layout.workspace, ["rev-parse", "HEAD"])
                guard try await LocalWorkspaceSafety.git(layout.workspace, ["symbolic-ref", "-q", "HEAD"]) == identity.branchReference else {
                    throw LocalActionError(message: String(localized: "The PR branch changed before its update. Nothing was reset."))
                }
                if finalHead != head {
                    return unchanged(head: finalHead, reason: String(localized: "HEAD changed before its update."))
                }
                try Task.checkCancellation()
                // Checkout refuses ignored/untracked overwrites even when files appear
                // after inspection, and refuses overlapping tracked edits without force.
                _ = try await LocalWorkspaceSafety.git(layout.workspace, [
                    "checkout", "--no-overwrite-ignore", "-B", identity.branch, details.headSHA,
                ])
            }
            guard try await LocalWorkspaceSafety.git(layout.workspace, ["rev-parse", "HEAD"]) == details.headSHA,
                  try await LocalWorkspaceSafety.git(layout.workspace, ["symbolic-ref", "-q", "HEAD"]) == identity.branchReference
            else {
                throw LocalActionError(message: String(localized: "The workspace changed during its update. Preparation was not marked complete."))
            }
            try await saveRepositoryState(details, repository: repository, identity: identity)
            try Task.checkCancellation()
            try Data((details.headSHA + "\n").utf8).write(
                to: layout.state.appendingPathComponent("prepared-sha"), options: .atomic
            )
            return PreparedWorkspace(
                layout: layout, clone: repository.clone, headSHA: details.headSHA, baseSHA: details.baseSHA
            )
        }

        private func createWorkspace(
            _ layout: LocalWorkspaceSafety.Layout,
            repository: Repository,
            identity: Identity,
            initialMetadata: Metadata? = nil,
            metadata: @Sendable () async throws -> Metadata
        ) async throws -> PreparedWorkspace {
            let details = try await fetchMetadata(repository: repository, identity: identity, initialMetadata: initialMetadata, metadata: metadata)
            var layout = layout
            let nameFile = layout.state.appendingPathComponent("workspace-name")
            if !LocalWorkspaceSafety.exists(nameFile) {
                let name = identity.workspaceName(title: details.title)
                layout = LocalWorkspaceSafety.Layout(root: layout.root, identity: identity, workspaceName: name)
                guard layout.workspace.path != repository.clone.path,
                      !repository.clone.path.hasPrefix(layout.workspace.path + "/"),
                      !LocalWorkspaceSafety.exists(layout.workspace)
                else {
                    throw LocalActionError(message: String(localized: "An existing folder occupies the PR workspace. Nothing was overwritten."))
                }
                try Data(name.utf8).write(to: nameFile, options: .atomic)
            }
            try await saveRepositoryState(details, repository: repository, identity: identity)
            let clone = repository.clone
            let workspace = layout.workspace
            let parent = workspace.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            guard try LocalWorkspaceSafety.physicalURL(parent).path == parent.path else {
                throw LocalActionError(message: String(localized: "The workspace parent is redirected by a symlink."))
            }
            let pending = PendingPreparation(
                workspace: workspace.path, clone: clone.path, common: repository.common.path,
                branch: identity.branchReference, headSHA: details.headSHA, baseSHA: details.baseSHA
            )
            // Persist ownership before Git can create a checkout or run user hooks.
            // Hook failures deliberately leave this recoverable, single-target journal.
            try writePending(pending, layout: layout)
            return try await finishPreparation(pending, layout: layout, repository: repository, identity: identity)
        }

        /// Fetch source refs without advancing the saved base/head until preparation succeeds.
        private func fetchMetadata(
            repository: Repository,
            identity: Identity,
            initialMetadata: Metadata? = nil,
            metadata: @Sendable () async throws -> Metadata
        ) async throws -> Metadata {
            let clone = repository.clone
            var attempts = 0
            while true {
                attempts += 1
                let details: Metadata
                if attempts == 1, let initialMetadata {
                    details = initialMetadata
                } else {
                    details = try await metadata()
                }
                try Task.checkCancellation()
                guard LocalWorkspaceSafety.validSHA(details.headSHA), LocalWorkspaceSafety.validSHA(details.baseSHA) else {
                    throw LocalActionError(message: String(localized: "GitHub returned invalid PR commit SHAs."))
                }
                for reference in [identity.branchReference, identity.headReference, identity.baseReference] {
                    _ = try await LocalWorkspaceSafety.git(clone, ["check-ref-format", reference])
                }
                let operation = "refs/preek-fetch/\(UUID().uuidString)"
                let headReference = operation + "/head"
                let baseReference = operation + "/base"
                let fetchedHead: String
                do {
                    // REST base.sha is a PR snapshot, not necessarily today's base-branch
                    // tip. Fetch that exact commit instead of comparing it with a live branch.
                    _ = try await LocalWorkspaceSafety.git(clone, [
                        "fetch", "--no-tags", "--no-write-fetch-head", "--", repository.remote,
                        "+refs/pull/\(identity.number)/head:\(headReference)",
                        "+\(details.baseSHA):\(baseReference)",
                    ])
                    fetchedHead = try await LocalWorkspaceSafety.git(clone, ["rev-parse", "\(headReference)^{commit}"])
                    guard try await LocalWorkspaceSafety.git(clone, ["rev-parse", "\(baseReference)^{commit}"]) == details.baseSHA else {
                        throw LocalActionError(message: String(localized: "Git did not return the requested PR base commit \(details.baseSHA). Nothing was updated."))
                    }
                } catch {
                    // Unique operation refs are safe to remove even after a partial fetch.
                    _ = try? await LocalWorkspaceSafety.git(clone, ["update-ref", "-d", headReference])
                    _ = try? await LocalWorkspaceSafety.git(clone, ["update-ref", "-d", baseReference])
                    throw error
                }
                _ = try await LocalWorkspaceSafety.git(clone, ["update-ref", "-d", headReference])
                _ = try await LocalWorkspaceSafety.git(clone, ["update-ref", "-d", baseReference])
                if fetchedHead == details.headSHA {
                    return details
                }
                // Either endpoint can lag, or the head can move between requests.
                // Refresh both snapshots automatically, without accepting an unverified tip.
                guard attempts < 3 else {
                    throw LocalActionError(message: String(localized: "GitHub's API and Git remote disagree on PR #\(identity.number) after \(attempts) attempts (API head: \(details.headSHA); Git head: \(fetchedHead)). Nothing was updated."))
                }
            }
        }

        /// Persist verified PR refs and branch-scoped push configuration together.
        private func saveRepositoryState(_ details: Metadata, repository: Repository, identity: Identity) async throws {
            _ = try await LocalWorkspaceSafety.git(repository.clone, ["update-ref", identity.headReference, details.headSHA])
            _ = try await LocalWorkspaceSafety.git(repository.clone, ["update-ref", identity.baseReference, details.baseSHA])
            if let destination = details.pushDestination {
                try await configurePush(destination, head: details.headSHA, repository: repository, identity: identity)
            }
        }

        private func configurePush(
            _ destination: PushDestination, head: String, repository: Repository, identity: Identity
        ) async throws {
            guard let url = URL(string: "https://\(identity.authority)/\(destination.repository)/pull/\(identity.number)") else {
                throw LocalActionError(message: String(localized: "GitHub returned an invalid PR head repository."))
            }
            let headIdentity = try Self.identity(for: url)
            guard destination.repository.lowercased() == "\(headIdentity.owner)/\(headIdentity.repository)" else {
                throw LocalActionError(message: String(localized: "GitHub returned an invalid PR head repository."))
            }
            let headBranch = "refs/heads/\(destination.branch)"
            _ = try await LocalWorkspaceSafety.git(repository.clone, ["check-ref-format", headBranch])
            // Preserve the mapped clone's SSH/HTTPS transport and SSH host/port settings.
            let source = try await LocalWorkspaceSafety.git(repository.clone, ["remote", "get-url", repository.remote])
            let path = "\(headIdentity.owner)/\(headIdentity.repository).git"
            let target: String
            if var components = URLComponents(string: source), ["https", "ssh"].contains(components.scheme ?? "") {
                components.path = "/" + path
                guard let url = components.url else {
                    throw LocalActionError(message: String(localized: "Could not construct the PR head repository URL."))
                }
                target = url.absoluteString
            } else if let colon = source.firstIndex(of: ":") {
                target = String(source[...colon]) + path
            } else {
                throw LocalActionError(message: String(localized: "The clone's remote transport is unsupported."))
            }
            let remote = "preek-push/\(identity.referenceSuffix)"
            let tracking = "refs/remotes/\(remote)/head"
            // Explicit mapping handles our different local name even with push.default=simple.
            // Never inherit origin's pushurl or remote.pushDefault.
            for (key, value) in [
                ("remote.\(remote).url", target),
                ("remote.\(remote).pushurl", target),
                ("remote.\(remote).fetch", "+\(headBranch):\(tracking)"),
                ("remote.\(remote).push", "\(identity.branchReference):\(headBranch)"),
                ("branch.\(identity.branch).remote", remote),
                ("branch.\(identity.branch).merge", headBranch),
                ("branch.\(identity.branch).pushRemote", remote),
            ] {
                _ = try await LocalWorkspaceSafety.git(repository.clone, ["config", "--local", "--replace-all", key, value])
            }
            _ = try await LocalWorkspaceSafety.git(repository.clone, ["update-ref", tracking, head])
        }

        private struct PendingPreparation: Codable {
            let workspace: String
            let clone: String
            let common: String
            let branch: String
            // Read legacy two-target journals without writing new intermediate states.
            var initialSHA: String? = nil
            let headSHA: String
            let baseSHA: String
            var previousPreparedSHA: String? = nil
            var removalRequired: Bool? = nil
        }

        private func writePending(_ pending: PendingPreparation, layout: LocalWorkspaceSafety.Layout) throws {
            try JSONEncoder().encode(pending).write(
                to: layout.state.appendingPathComponent("pending-preparation"), options: .atomic
            )
        }

        private func backup(_ head: String, repository: Repository, identity: Identity) async throws {
            guard LocalWorkspaceSafety.validSHA(head) else {
                throw LocalActionError(message: String(localized: "The worktree has no valid committed HEAD to preserve."))
            }
            let reference = "refs/preek/\(identity.referenceSuffix)/backups/\(UUID().uuidString)"
            _ = try await LocalWorkspaceSafety.git(repository.clone, ["check-ref-format", reference])
            _ = try await LocalWorkspaceSafety.git(repository.clone, ["update-ref", reference, head, String(repeating: "0", count: 40)])
        }

        private func readPending(
            _ layout: LocalWorkspaceSafety.Layout,
            repository: Repository,
            identity: Identity
        ) throws -> PendingPreparation {
            let journal = layout.state.appendingPathComponent("pending-preparation")
            guard LocalWorkspaceSafety.ownedFile(journal) else {
                throw LocalActionError(message: String(localized: "The pending preparation journal is unsafe."))
            }
            let pending = try JSONDecoder().decode(PendingPreparation.self, from: Data(contentsOf: journal))
            guard pending.workspace == layout.workspace.path,
                  pending.clone == repository.clone.path,
                  pending.common == repository.common.path,
                  pending.branch == identity.branchReference,
                  [pending.headSHA, pending.baseSHA].allSatisfy(LocalWorkspaceSafety.validSHA),
                  pending.initialSHA.map(LocalWorkspaceSafety.validSHA) ?? true,
                  pending.previousPreparedSHA.map(LocalWorkspaceSafety.validSHA) ?? true
            else {
                throw LocalActionError(message: String(localized: "The pending preparation journal does not match this PR workspace."))
            }
            // An unsafe/invalid existing marker is never excused by a journal.
            if LocalWorkspaceSafety.exists(layout.state.appendingPathComponent("prepared-sha")) {
                let expected = pending.removalRequired == true ? pending.previousPreparedSHA : pending.headSHA
                guard try LocalWorkspaceSafety.preparedSHA(layout.state) == expected else {
                    throw LocalActionError(message: String(localized: "The preparation marker conflicts with the pending journal."))
                }
            }
            return pending
        }

        private func finishPreparation(
            _ pending: PendingPreparation,
            layout: LocalWorkspaceSafety.Layout,
            repository: Repository,
            identity: Identity
        ) async throws -> PreparedWorkspace {
            var pending = pending
            let clone = repository.clone
            if pending.removalRequired == true {
                if LocalWorkspaceSafety.exists(layout.workspace) {
                    _ = try LocalWorkspaceSafety.Layout.validated(
                        workspace: layout.workspace.path, state: layout.state.path, clone: clone.path,
                        pullRequest: identity.pullRequestKey
                    )
                    try await LocalWorkspaceSafety.validateWorktree(layout.workspace, common: repository.common)
                    if let other = try await LocalWorkspaceSafety.registeredWorktree(clone: clone, branch: identity.branchReference),
                       other.path != layout.workspace.path
                    {
                        throw LocalActionError(message: String(localized: "The PR branch is checked out elsewhere. Nothing was removed."))
                    }
                    let current = try await LocalWorkspaceSafety.git(layout.workspace, ["rev-parse", "HEAD"])
                    try await backup(current, repository: repository, identity: identity)
                    _ = try LocalWorkspaceSafety.Layout.validated(
                        workspace: layout.workspace.path, state: layout.state.path, clone: clone.path,
                        pullRequest: identity.pullRequestKey
                    )
                    try await LocalWorkspaceSafety.validateWorktree(layout.workspace, common: repository.common)
                    if let other = try await LocalWorkspaceSafety.registeredWorktree(clone: clone, branch: identity.branchReference),
                       other.path != layout.workspace.path
                    {
                        throw LocalActionError(message: String(localized: "The PR branch moved to another checkout before removal."))
                    }
                    try Task.checkCancellation()
                    if let reason = LocalWorkspaceSafety.sharedLockWarning(common: repository.common, branch: identity.branchReference) {
                        throw LocalActionError(message: reason)
                    }
                    _ = try await LocalWorkspaceSafety.git(clone, ["worktree", "remove", "--force", "--force", "--", layout.workspace.path])
                }
                let marker = layout.state.appendingPathComponent("prepared-sha")
                if LocalWorkspaceSafety.exists(marker) {
                    _ = try LocalWorkspaceSafety.preparedSHA(layout.state)
                    try FileManager.default.removeItem(at: marker)
                }
                pending.removalRequired = false
                pending.previousPreparedSHA = nil
                try writePending(pending, layout: layout)
            }
            let workspace = layout.workspace
            if !LocalWorkspaceSafety.exists(workspace) {
                guard !LocalWorkspaceSafety.exists(layout.state.appendingPathComponent("prepared-sha")) else {
                    throw LocalActionError(message: String(localized: "The saved PR workspace is missing. Nothing was recreated."))
                }
                let parent = workspace.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
                guard LocalWorkspaceSafety.ownedDirectory(parent) else {
                    throw LocalActionError(message: String(localized: "The pending workspace parent is redirected or not owned by this account."))
                }
                if let other = try await LocalWorkspaceSafety.registeredWorktree(clone: clone, branch: identity.branchReference) {
                    throw LocalActionError(message: String(localized: "The PR branch is already registered at \(other.path). Nothing was overwritten."))
                }
                let retained = try await LocalCommand.run(
                    "/usr/bin/git", ["show-ref", "--verify", "--quiet", identity.branchReference], directory: clone
                )
                if retained.status == 0 {
                    let head = try await LocalWorkspaceSafety.git(clone, ["rev-parse", identity.branchReference])
                    if head != pending.headSHA {
                        try await backup(head, repository: repository, identity: identity)
                    }
                } else if retained.status != 1 {
                    throw LocalActionError(message: String(localized: "The retained PR branch could not be inspected."))
                }
                try Task.checkCancellation()
                _ = try await LocalWorkspaceSafety.git(clone, [
                    "worktree", "add", "-B", identity.branch, "--", workspace.path, pending.headSHA,
                ])
            }
            try await LocalWorkspaceSafety.validateWorktree(workspace, common: repository.common)
            guard try await LocalWorkspaceSafety.git(workspace, ["symbolic-ref", "-q", "HEAD"]) == pending.branch,
                  try await LocalWorkspaceSafety.git(clone, ["rev-parse", identity.baseReference]) == pending.baseSHA
            else {
                throw LocalActionError(message: String(localized: "The pending workspace branch or base reference changed. Nothing was overwritten."))
            }
            // A failed checkout hook may leave edits and descendant commits. Never
            // recreate/reset an existing journal-owned checkout on retry.
            _ = try await LocalWorkspaceSafety.git(workspace, [
                "merge-base", "--is-ancestor", pending.initialSHA ?? pending.headSHA, "HEAD",
            ])
            let includesHead = try await LocalCommand.run(
                "/usr/bin/git", ["merge-base", "--is-ancestor", pending.headSHA, "HEAD"], directory: workspace
            )
            if includesHead.status == 1 {
                if let reason = try await LocalWorkspaceSafety.refreshWarning(workspace, common: repository.common) {
                    throw LocalActionError(message: String(localized: "Pending preparation cannot finish safely: \(reason) Preserve or resolve the local data before retrying."))
                }
                _ = try await LocalWorkspaceSafety.git(workspace, [
                    "merge", "--ff-only", "--no-edit", "--no-overwrite-ignore", pending.headSHA,
                ])
            } else if includesHead.status != 0 {
                throw LocalActionError(message: String(localized: "Could not inspect the pending PR commits: \(includesHead.error)"))
            }
            guard try await LocalWorkspaceSafety.git(workspace, ["symbolic-ref", "-q", "HEAD"]) == pending.branch else {
                throw LocalActionError(message: String(localized: "The PR branch changed while finishing preparation. Nothing was overwritten."))
            }
            if LocalWorkspaceSafety.exists(layout.state.appendingPathComponent("prepared-sha")) {
                guard try LocalWorkspaceSafety.preparedSHA(layout.state) == pending.headSHA else {
                    throw LocalActionError(message: String(localized: "The preparation marker conflicts with the pending journal."))
                }
            }
            let head = try await LocalWorkspaceSafety.git(workspace, ["rev-parse", "HEAD"])
            try Task.checkCancellation()
            try Data((pending.headSHA + "\n").utf8).write(
                to: layout.state.appendingPathComponent("prepared-sha"), options: .atomic
            )
            // Cleanup refuses pending-preparation, including the brief marker+journal overlap.
            try FileManager.default.removeItem(at: layout.state.appendingPathComponent("pending-preparation"))
            return PreparedWorkspace(
                layout: layout, clone: clone, headSHA: head, baseSHA: pending.baseSHA
            )
        }

        private func matchingRemote(clone: URL, identity: Identity) async throws -> String {
            guard let remote = try await findMatchingRemote(clone: clone, identity: identity) else {
                throw LocalActionError(message: String(localized: "No HTTPS/SSH fetch remote matches \(identity.repositoryKey). Check the mapped clone; no repository was cloned."))
            }
            return remote
        }

        private func findMatchingRemote(clone: URL, identity: Identity) async throws -> String? {
            let names = try await LocalWorkspaceSafety.git(clone, ["remote"]).split(separator: "\n")
            for name in names {
                let urls = try await LocalWorkspaceSafety.git(clone, ["remote", "get-url", "--all", String(name)]).split(separator: "\n")
                guard !urls.isEmpty else { continue }
                // Git may fetch multiple URLs. Refuse a remote with any foreign fetch destination.
                if urls.allSatisfy({ Self.remoteMatches(String($0), identity: identity) }) {
                    return String(name)
                }
            }
            return nil
        }

        nonisolated static func remoteMatches(_ value: String, identity: Identity) -> Bool {
            var host: String
            var path: String
            if let url = URL(string: value), ["https", "ssh"].contains(url.scheme ?? ""), let remoteHost = url.host {
                guard url.query == nil, url.fragment == nil, url.password == nil else { return false }
                if url.scheme == "https", url.port != identity.url.port {
                    return false
                }
                host = remoteHost
                path = url.path
            } else {
                guard !value.contains("://"), let colon = value.firstIndex(of: ":") else { return false }
                host = String(value[..<colon].split(separator: "@").last ?? "")
                path = String(value[value.index(after: colon)...])
            }
            path = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if path.lowercased().hasSuffix(".git") {
                path.removeLast(4)
            }
            return host.lowercased() == identity.host && path.lowercased() == "\(identity.owner)/\(identity.repository)"
        }
    }
#endif
