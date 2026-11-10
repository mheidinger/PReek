#if os(macOS)
    import Darwin
    import Foundation

    /// Owns the app's workspace records, not user preferences or cleanup policy.
    @MainActor
    final class LocalWorkspaceRegistry {
        struct Workspace: Codable, Equatable {
            let workspace: String
            let state: String
            let clone: String
            let pullRequest: String
            var eligibleSince: TimeInterval?
        }

        struct Snapshot: Codable {
            var workspaces: [Workspace] = []
        }

        let url: URL
        private(set) var workspaces: [Workspace] = []

        init(directory: URL? = nil) {
            let home = getpwuid(getuid()).map { String(cString: $0.pointee.pw_dir) } ?? NSHomeDirectory()
            let support = directory ?? URL(fileURLWithPath: home, isDirectory: true)
                .appendingPathComponent("Library/Application Support/PReek/LocalActions", isDirectory: true)
            url = support.appendingPathComponent("workspaces.json")
            workspaces = (try? read().workspaces) ?? []
        }

        /// Always reads disk so cleanup can reject externally changed or unsafe records.
        func read() throws -> Snapshot {
            guard LocalWorkspaceSafety.ownedFile(url) else {
                throw LocalActionError(message: "The workspace registry is not an owned regular file.")
            }
            return try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: url))
        }

        func save(_ workspaces: [Workspace]) throws {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try JSONEncoder().encode(Snapshot(workspaces: workspaces)).write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            self.workspaces = workspaces
        }
    }
#endif
